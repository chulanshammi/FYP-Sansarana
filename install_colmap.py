import urllib.request
import zipfile
import os
import sys

def install_colmap():
    url = "https://github.com/colmap/colmap/releases/download/3.9.1/COLMAP-3.9.1-windows-cuda.zip"
    zip_path = "COLMAP.zip"
    dest_dir = "colmap"
    
    if os.path.exists(dest_dir):
        print(f"COLMAP is already extracted at {dest_dir}.")
        return

    print("Downloading COLMAP 3.9.1 (this may take a few minutes)...")
    try:
        urllib.request.urlretrieve(url, zip_path)
    except Exception as e:
        print(f"Failed to download: {e}")
        return

    print("Extracting COLMAP...")
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(dest_dir)
        
    print("Done! COLMAP installed locally.")
    if os.path.exists(zip_path):
        os.remove(zip_path)

if __name__ == "__main__":
    install_colmap()
