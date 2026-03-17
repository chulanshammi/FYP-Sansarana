import os
try:
    from pypdf import PdfReader
except ImportError:
    os.system('pip install pypdf')
    from pypdf import PdfReader
import sys

def extract_text(pdf_path, txt_path):
    try:
        reader = PdfReader(pdf_path)
        text = ""
        for page in reader.pages:
            extracted = page.extract_text()
            if extracted:
                text += extracted + "\n"
        with open(txt_path, 'w', encoding='utf-8') as f:
            f.write(text)
        print(f"Successfully extracted to {txt_path}")
    except Exception as e:
        print(f"Error extracting {pdf_path}: {e}")

if __name__ == "__main__":
    for arg in sys.argv[1:]:
        extract_text(arg, arg + ".txt")
