import os
import shutil
from pathlib import Path

def main():
    base_dir = Path("D:/Sansarana/outputs")
    target_dir = base_dir / "all_4k" / "images"
    
    # Create target directory
    target_dir.mkdir(parents=True, exist_ok=True)
    
    # Sources mapped to their prefixes
    sources = {
        "seated": base_dir / "seated_4k" / "images",
        "standing": base_dir / "standing_4k" / "images",
        "reclining": base_dir / "reclining_4k" / "images"
    }
    
    total_copied = 0
    
    for prefix, source_dir in sources.items():
        if not source_dir.exists():
            print(f"Warning: Source directory does not exist: {source_dir}")
            continue
            
        print(f"Copying images from {source_dir} with prefix '{prefix}_'...")
        
        # Count for this source
        count = 0
        for img_path in source_dir.glob("*"):
            if img_path.is_file():
                # E.g. seated_frame_0001.jpg
                new_name = f"{prefix}_{img_path.name}"
                target_path = target_dir / new_name
                
                # Copy file
                shutil.copy2(img_path, target_path)
                count += 1
                
        print(f"  Copied {count} images from {prefix}.")
        total_copied += count
        
    print(f"\nDone! Copied a total of {total_copied} images to {target_dir}")

if __name__ == '__main__':
    main()
