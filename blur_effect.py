import os
import cv2
import torch
import matplotlib.pyplot as plt
import numpy as np

import sys
sys.path.append('MobileSAM')

from mobile_sam import sam_model_registry, SamPredictor

# Load Model
model_type = "vit_t"
sam_checkpoint = "MobileSAM/weights/mobile_sam.pt"

device = "cuda" if torch.cuda.is_available() else "cpu"
mobile_sam = sam_model_registry[model_type](checkpoint=sam_checkpoint)
mobile_sam.to(device=device)
mobile_sam.eval()

predictor = SamPredictor(mobile_sam)

# Load Image
image_dir = r"d:\Sansarana\gal_vihara_dataset\seated\images"
images = [f for f in os.listdir(image_dir) if f.endswith('.jpg')]
image_path = os.path.join(image_dir, images[0])

image = cv2.imread(image_path)
image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

predictor.set_image(image)

h, w, _ = image.shape
input_point = np.array([[w // 2, h // 2]])
input_label = np.array([1])

masks, scores, logits = predictor.predict(
    point_coords=input_point,
    point_labels=input_label,
    multimask_output=True,
)

best_mask = masks[np.argmax(scores)] # Boolean array

# Blur background
# best_mask is (H, W). Add axis for broadcasting
mask = best_mask.astype(np.uint8)[:, :, np.newaxis]

# Strong blur for background
blurred_bg = cv2.GaussianBlur(image, (51, 51), 0)

# Composite
final_image = np.where(mask == 1, image, blurred_bg)

# Save result to view it
plt.figure(figsize=(10, 10))
plt.imshow(final_image)
plt.axis('off')
plt.title("Blurred Background Segmentation", fontsize=18)
plt.savefig("blurred_bg_segmentation.png", bbox_inches='tight')
print("Successfully saved blurred image.")
