"""
Generate missing downscaled images for all_4k dataset.
The ns-process-data was interrupted, so images_2, images_4, images_8 
only contain the original 'frame_*' images, not the reclining_* and standing_* ones.
"""
import os
from pathlib import Path
from PIL import Image
from concurrent.futures import ThreadPoolExecutor, as_completed

SOURCE_DIR = Path(r"D:\Sansarana\outputs\all_4k\images")
BASE_DIR = Path(r"D:\Sansarana\outputs\all_4k")

DOWNSCALE_FACTORS = [2, 4, 8]

def downscale_image(src_path, factor):
    """Downscale a single image by the given factor."""
    dest_dir = BASE_DIR / f"images_{factor}"
    dest_path = dest_dir / src_path.name
    
    if dest_path.exists():
        return f"SKIP: {src_path.name} (factor {factor})"
    
    img = Image.open(src_path)
    new_w = img.width // factor
    new_h = img.height // factor
    img_resized = img.resize((new_w, new_h), Image.LANCZOS)
    img_resized.save(dest_path, "JPEG", quality=95)
    return f"OK: {src_path.name} -> {new_w}x{new_h} (factor {factor})"

def main():
    # Ensure output dirs exist
    for f in DOWNSCALE_FACTORS:
        (BASE_DIR / f"images_{f}").mkdir(exist_ok=True)
    
    # Get all source images
    src_images = sorted(SOURCE_DIR.glob("*.jpg"))
    print(f"Found {len(src_images)} source images")
    
    # Check which ones are missing
    tasks = []
    for src in src_images:
        for factor in DOWNSCALE_FACTORS:
            dest = BASE_DIR / f"images_{factor}" / src.name
            if not dest.exists():
                tasks.append((src, factor))
    
    print(f"Need to generate {len(tasks)} downscaled images")
    
    if not tasks:
        print("All downscaled images already exist!")
        return
    
    # Process with thread pool
    done = 0
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = {executor.submit(downscale_image, src, factor): (src, factor) 
                   for src, factor in tasks}
        for future in as_completed(futures):
            done += 1
            result = future.result()
            if done % 100 == 0 or done == len(tasks):
                print(f"[{done}/{len(tasks)}] {result}")
    
    # Verify counts
    print("\n=== Final Counts ===")
    print(f"  images/: {len(list(SOURCE_DIR.glob('*.jpg')))}")
    for f in DOWNSCALE_FACTORS:
        d = BASE_DIR / f"images_{f}"
        print(f"  images_{f}/: {len(list(d.glob('*.jpg')))}")

if __name__ == "__main__":
    main()
