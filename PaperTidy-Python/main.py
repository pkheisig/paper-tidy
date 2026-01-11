import os
import sys
import re
import threading
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import requests
from pdfminer.high_level import extract_text

# --- Logic ---

class PaperLogic:
    def __init__(self):
        self.headers = {'User-Agent': 'PaperTidy/1.0 (mailto:user@example.com)'}

    def extract_doi(self, file_path):
        try:
            # Extract text from the first 2 pages only to save time
            text = extract_text(file_path, maxpages=2)
            # Regex for DOI
            match = re.search(r'\b(10\.\d{4,9}/[-._;()/:a-zA-Z0-9]+)', text)
            if match:
                return match.group(1)
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
        return None

    def fetch_metadata(self, doi):
        url = f"https://api.crossref.org/works/{doi}"
        try:
            r = requests.get(url, headers=self.headers, timeout=10)
            if r.status_code == 200:
                data = r.json()['message']
                
                title = data.get('title', ['Unknown Title'])[0]
                
                author = "Unknown"
                if 'author' in data and len(data['author']) > 0:
                    author = data['author'][0].get('family', 'Unknown')
                
                year = "0000"
                if 'created' in data and 'date-parts' in data['created']:
                    year = str(data['created']['date-parts'][0][0])

                # Journal Logic
                short = data.get('short-container-title', [])
                full = data.get('container-title', [])
                journal = (short[0] if short else (full[0] if full else "UnknownJournal"))
                
                return {
                    'title': title,
                    'author': author,
                    'year': year,
                    'journal': journal
                }
        except Exception as e:
            print(f"API Error: {e}")
        return None

    def sanitize_filename(self, name):
        # Remove invalid chars for Windows/Mac/Linux
        return re.sub(r'[<>:"/\\|?*]', '', name)

# --- GUI ---

class PaperTidyApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Paper Tidy")
        self.geometry("600x450")
        self.logic = PaperLogic()
        self.files = [] # List of dicts: {'path': str, 'id': iid, 'status': str}

        self.create_widgets()

    def create_widgets(self):
        # Header
        header_frame = ttk.Frame(self, padding=10)
        header_frame.pack(fill='x')
        
        ttk.Label(header_frame, text="Paper Tidy", font=('Segoe UI', 12, 'bold')).pack(side='left')
        
        ttk.Button(header_frame, text="Select Folder", command=self.select_folder).pack(side='right')
        ttk.Button(header_frame, text="Clear List", command=self.clear_list).pack(side='right', padx=5)

        # List Area
        list_frame = ttk.Frame(self, padding=10)
        list_frame.pack(fill='both', expand=True)

        columns = ('file', 'doi', 'status')
        self.tree = ttk.Treeview(list_frame, columns=columns, show='headings', selectmode='browse')
        
        self.tree.heading('file', text='File Name')
        self.tree.heading('doi', text='DOI')
        self.tree.heading('status', text='Status')
        
        self.tree.column('file', width=250)
        self.tree.column('doi', width=150)
        self.tree.column('status', width=100)

        # Scrollbar
        scrollbar = ttk.Scrollbar(list_frame, orient=tk.VERTICAL, command=self.tree.yview)
        self.tree.configure(yscroll=scrollbar.set)
        
        self.tree.pack(side='left', fill='both', expand=True)
        scrollbar.pack(side='right', fill='y')

        # Footer
        footer_frame = ttk.Frame(self, padding=10)
        footer_frame.pack(fill='x')

        self.status_label = ttk.Label(footer_frame, text="Ready", foreground="gray")
        self.status_label.pack(side='left')

        self.process_btn = ttk.Button(footer_frame, text="Process All", command=self.start_processing)
        self.process_btn.pack(side='right')

    def clear_list(self):
        self.files = []
        for item in self.tree.get_children():
            self.tree.delete(item)
        self.status_label.config(text="List cleared")

    def select_folder(self):
        folder_selected = filedialog.askdirectory()
        if folder_selected:
            self.load_files(folder_selected)

    def load_files(self, folder):
        self.clear_list()
        count = 0
        for root, dirs, filenames in os.walk(folder):
            for filename in filenames:
                if filename.lower().endswith(".pdf"):
                    path = os.path.join(root, filename)
                    iid = self.tree.insert('', 'end', values=(filename, "", "Pending"))
                    self.files.append({'path': path, 'id': iid, 'status': 'Pending', 'filename': filename})
                    count += 1
        self.status_label.config(text=f"Loaded {count} PDF files.")

    def start_processing(self):
        if not self.files:
            return
        
        self.process_btn.config(state='disabled')
        self.status_label.config(text="Processing...")
        
        # Run in separate thread to keep GUI responsive
        thread = threading.Thread(target=self.run_process_logic)
        thread.daemon = True
        thread.start()

    def run_process_logic(self):
        for item in self.files:
            if item['status'] == 'Done':
                continue

            # Update Status to Processing
            self.update_tree(item['id'], status="Scanning...")
            
            # 1. DOI
            doi = self.logic.extract_doi(item['path'])
            if not doi:
                self.update_tree(item['id'], status="No DOI")
                continue
            
            self.update_tree(item['id'], doi=doi, status="Fetching...")

            # 2. Metadata
            meta = self.logic.fetch_metadata(doi)
            if not meta:
                self.update_tree(item['id'], status="API Error")
                continue

            # 3. Rename
            # Clean journal name: remove spaces
            journal_clean = meta['journal'].replace(" ", "")
            new_name = f"{meta['year']}_{meta['author']}_{journal_clean}.pdf"
            new_name = self.logic.sanitize_filename(new_name)
            
            dir_path = os.path.dirname(item['path'])
            new_path = os.path.join(dir_path, new_name)
            
            try:
                os.rename(item['path'], new_path)
                item['path'] = new_path # Update path in case we process again (unlikely)
                self.update_tree(item['id'], file=new_name, status="Renamed")
            except Exception as e:
                self.update_tree(item['id'], status="Rename Failed")
                print(e)
        
        self.after(0, lambda: self.process_btn.config(state='normal'))
        self.after(0, lambda: self.status_label.config(text="Processing Complete"))

    def update_tree(self, iid, file=None, doi=None, status=None):
        # Helper to update treeview from thread safely
        def _update():
            current_values = self.tree.item(iid)['values']
            new_values = list(current_values)
            if file: new_values[0] = file
            if doi: new_values[1] = doi
            if status: new_values[2] = status
            self.tree.item(iid, values=new_values)
            
            # Auto scroll to show progress
            self.tree.see(iid)
            
        self.after(0, _update)

if __name__ == "__main__":
    app = PaperTidyApp()
    app.mainloop()
