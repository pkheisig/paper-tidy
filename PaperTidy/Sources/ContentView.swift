import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject var manager = PaperManager()
    @State private var showFolderPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Paper Tidy")
                    .font(.headline)
                Spacer()
                Button("Clear List") {
                    manager.clearPapers()
                }
                .disabled(manager.papers.isEmpty)
                
                Button("Select Folder") {
                    showFolderPicker = true
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // List
            if manager.papers.isEmpty {
                VStack {
                    Spacer()
                    Text("No PDF papers found or no folder selected.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(manager.papers) { paper in
                        PaperRow(paper: paper)
                    }
                }
                .listStyle(.inset)
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(manager.papers.count) files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if manager.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing...")
                        .font(.caption)
                }
                
                Button("Process Selected") {
                    manager.processSelectedPapers()
                }
                .disabled(manager.isProcessing || manager.papers.filter { $0.isSelected }.isEmpty)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 500, minHeight: 400)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // Security scoped resource access is required for App Store apps,
                    // but for a simple CLI/Script build it might just work if sandboxing is off.
                    // However, `fileImporter` usually gives a security scoped URL.
                    let gotAccess = url.startAccessingSecurityScopedResource()
                    if !gotAccess {
                        print("Failed to access security scoped resource")
                    }
                    manager.loadFiles(from: url)
                    // We don't stop accessing immediately because we need to read files later.
                    // In a real app we'd manage this handle better.
                }
            case .failure(let error):
                print("Error selecting folder: \(error.localizedDescription)")
            }
        }
    }
}

struct PaperRow: View {
    @ObservedObject var paper: PaperItem
    
    var body: some View {
        HStack {
            Toggle("", isOn: $paper.isSelected)
                .labelsHidden()
            
            Image(systemName: "doc.text.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(paper.fileName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                if let doi = paper.detectedDOI {
                    Text("DOI: \(doi)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            StatusView(status: paper.status)
        }
        .padding(.vertical, 4)
    }
}

struct StatusView: View {
    let status: ProcessingStatus
    
    var body: some View {
        switch status {
        case .pending:
            EmptyView()
        case .processing:
            ProgressView()
                .scaleEffect(0.5)
        case .success(let newName):
            VStack(alignment: .trailing) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(newName)
                    .font(.caption2)
                    .foregroundColor(.green)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: 150, alignment: .trailing)
        case .failure(let error):
            Text(error)
                .font(.caption2)
                .foregroundColor(.red)
                .frame(maxWidth: 150, alignment: .trailing)
        }
    }
}
