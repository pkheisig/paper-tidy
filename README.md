# 📄 Paperenamer

**Tired of not knowing which file belongs to which study?** 🤯

**Paperenamer** is a simple, powerful tool that scans your folder of PDF research papers, automatically finds their metadata (DOI, Author, Year, Journal), and renames them into a clean, standardized format.

From `102938.pdf` → `2025_Jackson_NatImmunol.pdf` ✨

---

## 🚀 Features

*   **Auto-Detection:** Scans PDF text to find the DOI (Digital Object Identifier).
*   **Smart Metadata:** Fetches official data from CrossRef.
*   **Clean Renaming:** Renames files to `Year_Author_Journal.pdf`.
*   **Multi-Platform:** Native macOS app + Python version for Windows/Linux.
*   **Bulk Processing:** Handle entire folders at once.

---

## 🍏 macOS User?

We have a native, fast SwiftUI app for you.

### How to Run
1.  Open Terminal in the `Paperenamer` folder.
2.  Run the build script:
    ```bash
    cd Paperenamer
    ./build.sh
    ```
3.  Open the app:
    ```bash
    open "build/Paperenamer.app"
    ```

---

## 🪟 Windows (or Linux) User?

We have a Python version that works everywhere. You can even build it into a standalone `.exe`.

### How to Run (Python)
1.  Install Python 3.
2.  Install dependencies:
    ```bash
    cd Paperenamer-Python
    pip install -r requirements.txt
    ```
3.  Run the app:
    ```bash
    python main.py
    ```

### How to Create an .EXE (Windows)
1.  Double-click `build_windows.bat` in the `Paperenamer-Python` folder.
2.  Wait for the build to finish.
3.  Your app will be in the `dist` folder!

---

## 🛠️ Tech Stack

*   **macOS:** Swift, SwiftUI, PDFKit.
*   **Python:** Tkinter (GUI), pdfminer.six (PDF parsing), requests (API).

---

Happy Reading! 📚
