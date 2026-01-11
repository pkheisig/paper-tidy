import Foundation
import PDFKit
import Combine

// MARK: - Models

enum ProcessingStatus: Equatable {
    case pending
    case processing
    case success(String) // New filename
    case failure(String) // Error message
}

class PaperItem: ObservableObject, Identifiable {
    let id = UUID()
    let originalURL: URL
    @Published var isSelected: Bool = true
    @Published var status: ProcessingStatus = .pending
    @Published var detectedDOI: String? = nil
    @Published var proposedTitle: String? = nil
    
    var fileName: String {
        originalURL.lastPathComponent
    }
    
    init(url: URL) {
        self.originalURL = url
    }
}

// MARK: - Logic

class PaperManager: ObservableObject {
    @Published var papers: [PaperItem] = []
    @Published var isProcessing: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    func loadFiles(from folderURL: URL) {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: nil) else { return }
        
        var newPapers: [PaperItem] = []
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.lowercased() == "pdf" {
                newPapers.append(PaperItem(url: fileURL))
            }
        }
        
        DispatchQueue.main.async {
            self.papers = newPapers.sorted(by: { $0.fileName < $1.fileName })
        }
    }
    
    func clearPapers() {
        papers = []
    }
    
    func processSelectedPapers() {
        guard !isProcessing else { return }
        isProcessing = true
        
        let selectedPapers = papers.filter { $0.isSelected && $0.status != .processing }
        
        // Process sequentially or semi-parallel (limit concurrency)
        // For simplicity, we'll do a simple loop but with async dispatch
        let group = DispatchGroup()
        
        for paper in selectedPapers {
            group.enter()
            processPaper(paper) {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.isProcessing = false
        }
    }
    
    private func processPaper(_ paper: PaperItem, completion: @escaping () -> Void) {
        DispatchQueue.main.async { paper.status = .processing }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. Extract DOI
            guard let doi = self.extractDOI(from: paper.originalURL) else {
                DispatchQueue.main.async { paper.status = .failure("No DOI found") }
                completion()
                return
            }
            
            DispatchQueue.main.async { paper.detectedDOI = doi }
            
            // 2. Fetch Metadata
            self.fetchMetadata(doi: doi) { result in
                switch result {
                case .success(let metadata):
                    // 3. Rename
                    let journalClean = metadata.journal.replacingOccurrences(of: " ", with: "")
                    let newName = self.sanitizeFilename("\(metadata.year)_\(metadata.author)_\(journalClean).pdf")
                    let folder = paper.originalURL.deletingLastPathComponent()
                    let newURL = folder.appendingPathComponent(newName)
                    
                    do {
                        try FileManager.default.moveItem(at: paper.originalURL, to: newURL)
                        DispatchQueue.main.async {
                            paper.status = .success(newName)
                            paper.proposedTitle = newName
                        }
                    } catch {
                        DispatchQueue.main.async { paper.status = .failure("Rename failed: \(error.localizedDescription)") }
                    }
                    
                case .failure(let error):
                    DispatchQueue.main.async { paper.status = .failure("API Error: \(error.localizedDescription)") }
                }
                completion()
            }
        }
    }

    private func extractDOI(from url: URL) -> String? {
        guard let pdfDocument = PDFDocument(url: url) else { return nil }
        // Scan first 2 pages
        let pageCount = min(pdfDocument.pageCount, 2)
        let doiRegex = try? NSRegularExpression(pattern: "\\b(10\\.\\d{4,9}/[-._;()/:a-zA-Z0-9]+)\\b", options: .caseInsensitive)
        
        for i in 0..<pageCount {
            guard let page = pdfDocument.page(at: i),
                  let text = page.string else { continue }
            
            let range = NSRange(location: 0, length: text.utf16.count)
            if let match = doiRegex?.firstMatch(in: text, options: [], range: range) {
                if let swiftRange = Range(match.range(at: 1), in: text) {
                    return String(text[swiftRange])
                }
            }
        }
        return nil
    }
    
    private struct Metadata {
        let title: String
        let author: String
        let year: String
        let journal: String
    }
    
    private func fetchMetadata(doi: String, completion: @escaping (Result<Metadata, Error>) -> Void) {
        let urlString = "https://api.crossref.org/works/\(doi)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.addValue("PaperTidy/1.0 (mailto:user@example.com)", forHTTPHeaderField: "User-Agent") // Polite User-Agent
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? [String: Any] {
                    
                    let title = (message["title"] as? [String])?.first ?? "Unknown Title"
                    
                    var author = "Unknown"
                    if let authors = message["author"] as? [[String: Any]], let firstAuthor = authors.first {
                        author = firstAuthor["family"] as? String ?? "Unknown"
                    }
                    
                    var year = "0000"
                    if let created = message["created"] as? [String: Any],
                       let dateParts = created["date-parts"] as? [[Int]],
                       let firstPart = dateParts.first,
                       let yearInt = firstPart.first {
                        year = String(yearInt)
                    }
                    
                    let shortJournal = (message["short-container-title"] as? [String])?.first
                    let fullJournal = (message["container-title"] as? [String])?.first
                    let journal = shortJournal ?? fullJournal ?? "UnknownJournal"
                    
                    completion(.success(Metadata(title: title, author: author, year: year, journal: journal)))
                } else {
                    completion(.failure(NSError(domain: "ParseError", code: -1, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func sanitizeFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>\'")
        return name.components(separatedBy: invalidCharacters).joined(separator: "")
    }
}
