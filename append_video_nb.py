import nbformat as nbf

# Read the notebook
with open('d:/Sansarana/Interim_Demo.ipynb', 'r', encoding='utf-8') as f:
    nb = nbf.read(f, as_version=4)

md_video = nbf.v4.new_markdown_cell("### Video Segmentation\nProcess a short video clip (reduced to a few frames for performance) and apply the blurred background effect frame-by-frame.")
code_video = nbf.v4.new_code_cell("""import cv2
import numpy as np
import os
import matplotlib.pyplot as plt

# Video paths
video_in_path = r"d:\Sansarana\gal_vihara_dataset\seated\BNQM5414.MP4"
video_out_path = r"d:\Sansarana\seated_blurred_output.mp4"

cap = cv2.VideoCapture(video_in_path)

if not cap.isOpened():
    print("Cannot open video")
else:
    fps = cap.get(cv2.CAP_PROP_FPS)
    if fps == 0 or np.isnan(fps):
        fps = 30.0
    width_in  = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height_in = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    
    # We will process 15 frames to demonstrate the pipeline quickly.
    max_frames_to_process = 15
    
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(video_out_path, fourcc, fps, (width_in, height_in))
    
    print(f"Processing up to {max_frames_to_process} frames from video...")
    frame_count = 0
    
    while cap.isOpened() and frame_count < max_frames_to_process:
        ret, frame = cap.read()
        if not ret:
            break
            
        # Convert BGR to RGB for MobileSAM processing
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        predictor.set_image(rgb_frame)
        
        # Center point prompt
        input_point = np.array([[width_in // 2, height_in // 2]])
        input_label = np.array([1])
        
        masks, scores, logits = predictor.predict(
            point_coords=input_point,
            point_labels=input_label,
            multimask_output=True,
        )
        
        # Best mask
        best_mask_idx = np.argmax(scores)
        best_mask = masks[best_mask_idx]
        
        # Composite Logic
        mask = best_mask.astype(np.uint8)[:, :, np.newaxis]
        blurred_bg = cv2.GaussianBlur(frame, (51, 51), 0)
        final_frame = np.where(mask == 1, frame, blurred_bg)
        
        out.write(final_frame)
        frame_count += 1

    cap.release()
    out.release()
    print(f"Finished processing {frame_count} frames. Output saved to: {video_out_path}")
""")

nb.cells.extend([md_video, code_video])

with open('d:/Sansarana/Interim_Demo.ipynb', 'w', encoding='utf-8') as f:
    nbf.write(nb, f)
