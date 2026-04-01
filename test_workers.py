import os
import json
import torch
from PIL import Image
from torch.utils.data import Dataset, DataLoader
import torchvision.transforms.functional as F

class TestDataSet(Dataset):
    def __init__(self, images_dir, annotation_file):
        self.images_dir = images_dir
        with open(annotation_file, 'r') as f:
            self.coco_data = json.load(f)
        self.images = {img['id']: img for img in self.coco_data['images']}
        self.image_ids = list(self.images.keys())

    def __len__(self):
        return min(4, len(self.image_ids))  # Just test 4

    def __getitem__(self, idx):
        img_id = self.image_ids[idx]
        img_info = self.images[img_id]
        img_path = os.path.join(self.images_dir, img_info['file_name'])
        img = Image.open(img_path).convert("RGB")
        image_tensor = F.to_tensor(img)
        return image_tensor

if __name__ == '__main__':
    ds = TestDataSet(r'd:\Sansarana\Faster R-CNN\train', r'd:\Sansarana\Faster R-CNN\train\_annotations.coco.json')
    dl = DataLoader(ds, batch_size=2, num_workers=4)
    print("Testing dataloader with num_workers=4...")
    try:
        for b in dl:
            print("Successfully loaded batch with shape:", b.shape)
            break
        print("Success.")
    except Exception as e:
        print("Error:", e)
