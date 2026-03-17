import cv2
import os
import sys

def extract_frames(video_path, output_dir, fps=2):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        
    vid = cv2.VideoCapture(video_path)
    if not vid.isOpened():
        print(f"Failed to open {video_path}")
        return
        
    original_fps = vid.get(cv2.CAP_PROP_FPS)
    if original_fps == 0:
        original_fps = 30 # default assumption
    frame_interval = int(original_fps / fps)
    
    count = 0
    saved_count = 0
    video_name = os.path.splitext(os.path.basename(video_path))[0]
    
    while True:
        ret, frame = vid.read()
        if not ret:
            break
            
        if count % frame_interval == 0:
            out_path = os.path.join(output_dir, f"{video_name}_{saved_count:04d}.jpg")
            cv2.imwrite(out_path, frame)
            saved_count += 1
            
        count += 1
        
    vid.release()
    print(f"Extracted {saved_count} frames from {video_name}")

if __name__ == "__main__":
    target_dir = sys.argv[1]
    output_images_dir = os.path.join(target_dir, "images")
    
    print(f"Processing videos in {target_dir}...")
    for file in os.listdir(target_dir):
        if file.lower().endswith(".mp4"):
            video_path = os.path.join(target_dir, file)
            # Extract at 2 FPS to avoid too many redundant frames
            extract_frames(video_path, output_images_dir, fps=2)
    print("Done extracting frames.")
