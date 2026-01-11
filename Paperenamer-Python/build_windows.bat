@echo off
echo Installing requirements...
pip install -r requirements.txt

echo Building EXE...
pyinstaller --noconfirm --onefile --windowed --name "Paperenamer" --hidden-import=pdfminer.six main.py

echo Build complete! Check the 'dist' folder.
pause
