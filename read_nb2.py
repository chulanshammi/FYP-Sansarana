# Cell 1:
import os
import cv2
import torch
import matplotlib.pyplot as plt
import numpy as np

# Add MobileSAM to path if downloaded locally
import sys
sys.path.append('MobileSAM')

from mobile_sam import sam_model_registry, SamPredictor

print("PyTorch version:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())

# Cell 3:
model_type = "vit_t"
sam_checkpoint = "MobileSAM/weights/mobile_sam.pt"

# Ensure the weights exist (we will download them if not)
if not os.path.exists(sam_checkpoint):
    print("Downloading MobileSAM weights...")
    import urllib.request
    os.makedirs('MobileSAM/weights', exist_ok=True)
    urllib.request.urlretrieve("https://github.com/ChaoningZhang/MobileSAM/raw/master/weights/mobile_sam.pt", sam_checkpoint)
    print("Downloaded.")

device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Loading model to {device}...")

mobile_sam = sam_model_registry[model_type](checkpoint=sam_checkpoint)
mobile_sam.to(device=device)
mobile_sam.eval()

predictor = SamPredictor(mobile_sam)
print("MobileSAM initialized!")

# Cell 5:
# Get the first available image
image_dir = r"d:\Sansarana\gal_vihara_dataset\seated\images"
images = [f for f in os.listdir(image_dir) if f.endswith('.jpg')]
image_path = os.path.join(image_dir, images[0])

image = cv2.imread(image_path)
image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

plt.figure(figsize=(10, 10))
plt.imshow(image)
plt.axis('off')
plt.title(f"Reference Frame: {images[0]}")
plt.show()

# Cell 7:
predictor.set_image(image)

# Center point (assuming the statue is roughly in the center of the frame, can be adjusted)
h, w, _ = image.shape
input_point = np.array([[w // 2, h // 2]])
input_label = np.array([1]) # 

masks, scores, logits = predictor.predict(
    point_coords=input_point,
    point_labels=input_label,
    multimask_output=True,
)

# Choose the mask with the highest score
best_mask = masks[np.argmax(scores)]

def show_mask(mask, ax, random_color=False):
    if random_color:
        color = np.concatenate([np.random.random(3), np.array([0.6])], axis=0)
    else:
        color = np.array([30/255, 144/255, 255/255, 0.6])
    h, w = mask.shape[-2:]
    mask_image = mask.reshape(h, w, 1) * color.reshape(1, 1, -1)
    ax.imshow(mask_image)

def show_points(coords, labels, ax, marker_size=375):
    pos_points = coords[labels==1]
    neg_points = coords[labels==0]
    ax.scatter(pos_points[:, 0], pos_points[:, 1], color='green', marker='*', s=marker_size, edgecolor='white', linewidth=1.25)
    ax.scatter(neg_points[:, 0], neg_points[:, 1], color='red', marker='*', s=marker_size, edgecolor='white', linewidth=1.25)

plt.figure(figsize=(10, 10))
plt.imshow(image)
show_mask(best_mask, plt.gca())
show_points(input_point, input_label, plt.gca())
plt.title("MobileSAM 2D Segmentation Output", fontsize=18)
plt.axis('off')
plt.show()

# Cell 8:
import torch
from mobile_sam import sam_model_registry, SamPredictor

checkpoint_path = "MobileSAM\weights\mobile_sam.pt"   # put correct path to your checkpoint
model_type = "vit_t"

device = "cuda" if torch.cuda.is_available() else "cpu"

sam = sam_model_registry[model_type](checkpoint=checkpoint_path)
sam.to(device=device)
predictor = SamPredictor(sam)

print("Predictor ready on:", device)

# Cell 9:
%matplotlib notebook


