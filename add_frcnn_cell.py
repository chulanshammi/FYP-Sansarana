import nbformat
from nbformat.v4 import new_code_cell

nb_path = "d:/Sansarana/train_object_detection.ipynb"
nb = nbformat.read(nb_path, as_version=4)

new_code = """import os
import json
import torch
from PIL import Image
from torch.utils.data import Dataset, DataLoader
import torchvision.transforms.functional as F

class COCODatasetForFRCNN(Dataset):
    def __init__(self, images_dir, annotation_file):
        self.images_dir = images_dir
        
        # Load the monolithic COCO JSON file
        print(f"Loading annotations from {annotation_file}...")
        with open(annotation_file, 'r') as f:
            self.coco_data = json.load(f)
            
        # Map Image ID to its metadata name
        self.images = {img['id']: img for img in self.coco_data['images']}
        self.image_ids = list(self.images.keys())
        
        # Group each bounding box annotation to its parent image ID
        self.annotations = {img_id: [] for img_id in self.image_ids}
        for ann in self.coco_data['annotations']:
            self.annotations[ann['image_id']].append(ann)

    def __len__(self):
        return len(self.image_ids)

    def __getitem__(self, idx):
        img_id = self.image_ids[idx]
        img_info = self.images[img_id]
        
        # Load the image using its 'file_name' mapped from the JSON
        img_path = os.path.join(self.images_dir, img_info['file_name'])
        img = Image.open(img_path).convert("RGB")
        image_tensor = F.to_tensor(img) # Automatically converts 0-255 pixels to 0.0-1.0 tensor

        boxes = []
        labels = []
        area = []
        iscrowd = []
        
        # Process Bounding Boxes
        for ann in self.annotations[img_id]:
            # COCO JSON natively stores bbox as [x_min, y_min, width, height]
            x_min, y_min, width, height = ann['bbox']
            
            # FRCNN expects absolute pixels in [x_min, y_min, x_max, y_max] format
            boxes.append([x_min, y_min, x_min + width, y_min + height])
            
            # COCO classes organically start at 1, leaving 0 for Background seamlessly!
            labels.append(ann['category_id']) 
            area.append(ann['area'])
            iscrowd.append(ann.get('iscrowd', 0))

        # Wrap results in PyTorch Tensors efficiently
        if len(boxes) > 0:
            boxes = torch.as_tensor(boxes, dtype=torch.float32)
            labels = torch.as_tensor(labels, dtype=torch.int64)
            area = torch.as_tensor(area, dtype=torch.float32)
            iscrowd = torch.as_tensor(iscrowd, dtype=torch.int64)
        else:
            # Safely handle negative samples (images with 0 objects)
            boxes = torch.empty((0, 4), dtype=torch.float32)
            labels = torch.empty((0,), dtype=torch.int64)
            area = torch.empty((0,), dtype=torch.float32)
            iscrowd = torch.empty((0,), dtype=torch.int64)
            
        target = {
            "boxes": boxes,
            "labels": labels,
            "image_id": torch.tensor([img_id]),
            "area": area,
            "iscrowd": iscrowd
        }

        return image_tensor, target

# Collate function is ALWAYS required to handle varying amounts of objects per image list
def collate_fn(batch):
    return tuple(zip(*batch))

# ==========================================
# 1. Instantiate the Dataloader
# ==========================================
train_dataset = COCODatasetForFRCNN(
    images_dir=r'd:\\Sansarana\\Faster R-CNN\\train',
    annotation_file=r'd:\\Sansarana\\Faster R-CNN\\train\\_annotations.coco.json'
)

train_loader = DataLoader(
    train_dataset, 
    batch_size=4,   # Reduce this to 2 if you run out of GPU memory
    shuffle=True, 
    collate_fn=collate_fn, 
    num_workers=4
)

# ==========================================
# 2. Start the Training Loop
# ==========================================
device = 'cuda' if torch.cuda.is_available() else 'cpu'

frcnn_model.train()

print(f"Beginning Faster R-CNN Training on {len(train_dataset)} COCO images...")

# Training Loop Boilerplate
for epoch in range(15): # Define your number of epochs
    epoch_loss = 0
    for images, targets in train_loader:
        # Move images and targets arrays to your GPU dynamically
        images = list(img.to(device) for img in images)
        targets = [{k: v.to(device) for k, v in t.items()} for t in targets]
        
        # Forward Pass
        loss_dict = frcnn_model(images, targets)
        losses = sum(loss for loss in loss_dict.values())
        
        # Backward Pass
        optimizer_frcnn.zero_grad()
        losses.backward()
        optimizer_frcnn.step()
        
        epoch_loss += losses.item()
        
    print(f"Epoch {epoch+1} | Loss: {epoch_loss/len(train_loader):.4f}")
"""

# Find the FRCNN initialization cell
target_idx = -1
for i, cell in enumerate(nb.cells):
    if cell.cell_type == 'code' and 'NUM_CLASSES_FRCNN' in cell.source:
        target_idx = i
        break

if target_idx != -1:
    # Check if we already inserted it
    already_inserted = False
    if target_idx + 1 < len(nb.cells):
        next_cell = nb.cells[target_idx + 1]
        if next_cell.cell_type == 'code' and 'COCODatasetForFRCNN' in next_cell.source:
            already_inserted = True
            
    if not already_inserted:
        nb.cells.insert(target_idx + 1, new_code_cell(new_code))
        nbformat.write(nb, nb_path)
        print("Successfully injected training loop cell!")
    else:
        print("Cell already exists!")
else:
    print("Could not find the initialization cell.")
