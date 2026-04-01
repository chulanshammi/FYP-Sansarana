"""
Extract frames from all reclining statue videos at full 4K resolution.
Then run ns-process-data to create COLMAP data with correct intrinsics.
"""
import subprocess
import os
import sys

VIDEOS_DIR = r"D:\Sansarana\gal_vihara_dataset\reclining"
FRAMES_DIR = r"D:\Sansarana\outputs\reclining_4k\images"
FPS = 2  # Extract 2 frames per second

os.makedirs(FRAMES_DIR, exist_ok=True)

# Get all MP4 files
videos = sorted([f for f in os.listdir(VIDEOS_DIR) if f.lower().endswith('.mp4')])
print(f"Found {len(videos)} videos")

frame_count = 0
for i, video in enumerate(videos):
    video_path = os.path.join(VIDEOS_DIR, video)
    print(f"\n[{i+1}/{len(videos)}] Extracting from {video}...")
    
    # Extract frames at 2fps, full resolution, high quality JPEG
    cmd = [
        "ffmpeg", "-i", video_path,
        "-vf", f"fps={FPS}",
        "-q:v", "1",  # Highest JPEG quality
        "-start_number", str(frame_count + 1),
        os.path.join(FRAMES_DIR, f"frame_%05d.jpg"),
        "-y"
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    # Count how many new frames were extracted
    new_count = len([f for f in os.listdir(FRAMES_DIR) if f.endswith('.jpg')])
    extracted = new_count - frame_count
    frame_count = new_count
    print(f"   Extracted {extracted} frames (total: {frame_count})")

print(f"\n{'='*50}")
print(f"Total frames extracted: {frame_count}")
print(f"Output directory: {FRAMES_DIR}")

# Check resolution of first frame
try:
    from PIL import Image
    first_frame = sorted(os.listdir(FRAMES_DIR))[0]
    img = Image.open(os.path.join(FRAMES_DIR, first_frame))
    print(f"Frame resolution: {img.size}")
except ImportError:
    print("(PIL not installed, skipping resolution check)")
