import json

notebook_path = 'd:/Sansarana/train_object_detection.ipynb'
with open(notebook_path, 'r', encoding='utf-8') as f:
    nb = json.load(f)

# Remove ALL existing cells that reference grounding-dino / DINO training
cells_to_keep = []
for cell in nb['cells']:
    src = ''.join(cell.get('source', []))
    if 'grounding-dino' in src.lower() or ('dino_model' in src and 'grounding' in src.lower()):
        continue
    # Also remove any Grounding DINO markdown header cells
    if cell.get('cell_type') == 'markdown' and 'Grounding DINO' in src:
        continue
    cells_to_keep.append(cell)

nb['cells'] = cells_to_keep

# Now add clean fresh cells
markdown_cell = {
    "cell_type": "markdown",
    "metadata": {},
    "source": [
        "# 4. Grounding DINO (Vision-Language Fine-Tuning)\n",
        "Grounding DINO detects objects using **text prompts** instead of class IDs. We freeze the heavy Swin & BERT backbones to stay within 12GB VRAM, and fine-tune only the decoder heads."
    ]
}

code_cell = {
    "cell_type": "code",
    "execution_count": None,
    "metadata": {},
    "outputs": [],
    "source": [
        "!pip install -q transformers peft\n",
        "import os, torch\n",
        "from PIL import Image\n",
        "from torch.utils.data import DataLoader, Dataset\n",
        "from tqdm import tqdm\n",
        "from transformers import AutoProcessor, AutoModelForZeroShotObjectDetection\n",
        "\n",
        "device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')\n",
        "\n",
        "# YOLO class id -> phrase position in prompt\n",
        "# data.yaml: 0:reclining, 1:seated, 2:standing\n",
        "TEXT_PROMPT = \"reclining statue. seated statue. standing statue.\"\n",
        "YOLO_TO_IDX = {0: 0, 1: 1, 2: 2}\n",
        "\n",
        "# ---- Dataset ----\n",
        "class YOLODinoDataset(Dataset):\n",
        "    def __init__(self, images_dir, labels_dir, processor):\n",
        "        self.images_dir = images_dir\n",
        "        self.labels_dir = labels_dir\n",
        "        self.processor = processor\n",
        "        self.images = [f for f in os.listdir(images_dir) if f.lower().endswith(('.jpg', '.png'))]\n",
        "\n",
        "    def __len__(self):\n",
        "        return len(self.images)\n",
        "\n",
        "    def __getitem__(self, idx):\n",
        "        img_name = self.images[idx]\n",
        "        base = os.path.splitext(img_name)[0]\n",
        "        image = Image.open(os.path.join(self.images_dir, img_name)).convert('RGB')\n",
        "        w, h = image.size\n",
        "\n",
        "        boxes, class_labels = [], []\n",
        "        label_path = os.path.join(self.labels_dir, base + '.txt')\n",
        "        if os.path.exists(label_path):\n",
        "            with open(label_path) as f:\n",
        "                for line in f:\n",
        "                    parts = line.strip().split()\n",
        "                    if len(parts) < 5:\n",
        "                        continue\n",
        "                    cls = int(parts[0])\n",
        "                    cx, cy, bw, bh = map(float, parts[1:5])\n",
        "                    xmin = (cx - bw/2) * w\n",
        "                    ymin = (cy - bh/2) * h\n",
        "                    xmax = (cx + bw/2) * w\n",
        "                    ymax = (cy + bh/2) * h\n",
        "                    if cls in YOLO_TO_IDX:\n",
        "                        boxes.append([xmin, ymin, xmax, ymax])\n",
        "                        class_labels.append(YOLO_TO_IDX[cls])\n",
        "\n",
        "        inputs = self.processor(images=image, text=TEXT_PROMPT, return_tensors='pt')\n",
        "        inputs = {k: v.squeeze(0) for k, v in inputs.items()}\n",
        "\n",
        "        target = {\n",
        "            'boxes': torch.tensor(boxes, dtype=torch.float32) if boxes else torch.zeros((0, 4)),\n",
        "            'class_labels': torch.tensor(class_labels, dtype=torch.long) if class_labels else torch.zeros((0,), dtype=torch.long)\n",
        "        }\n",
        "        return inputs, target\n",
        "\n",
        "def dino_collate(batch):\n",
        "    input_ids       = torch.stack([x[0]['input_ids'] for x in batch])\n",
        "    attention_mask  = torch.stack([x[0]['attention_mask'] for x in batch])\n",
        "    pixel_values    = torch.stack([x[0]['pixel_values'] for x in batch])\n",
        "    labels = [x[1] for x in batch]\n",
        "    return {'input_ids': input_ids, 'attention_mask': attention_mask,\n",
        "            'pixel_values': pixel_values, 'labels': labels}\n",
        "\n",
        "# ---- Load Processor & Model ----\n",
        "MODEL_ID = 'IDEA-Research/grounding-dino-base'\n",
        "print('Loading Grounding DINO processor...')\n",
        "processor = AutoProcessor.from_pretrained(MODEL_ID)\n",
        "\n",
        "train_set = YOLODinoDataset(\n",
        "    r'd:\\Sansarana\\RT-DETR\\train\\images',\n",
        "    r'd:\\Sansarana\\RT-DETR\\train\\labels',\n",
        "    processor\n",
        ")\n",
        "dino_loader = DataLoader(train_set, batch_size=2, shuffle=True,\n",
        "                         collate_fn=dino_collate, num_workers=0)\n",
        "\n",
        "print('Loading Grounding DINO model weights...')\n",
        "dino_model = AutoModelForZeroShotObjectDetection.from_pretrained(\n",
        "    MODEL_ID, ignore_mismatched_sizes=True\n",
        ")\n",
        "\n",
        "# Freeze vision + language backbones; only train decoder/prediction heads\n",
        "# HF structure: dino_model.model.backbone (Swin) + dino_model.model.text_backbone (BERT)\n",
        "for param in dino_model.model.backbone.parameters():\n",
        "    param.requires_grad = False\n",
        "for param in dino_model.model.text_backbone.parameters():\n",
        "    param.requires_grad = False\n",
        "\n",
        "trainable = sum(p.numel() for p in dino_model.parameters() if p.requires_grad)\n",
        "total     = sum(p.numel() for p in dino_model.parameters())\n",
        "print(f'Trainable params: {trainable/1e6:.1f}M / {total/1e6:.1f}M total')\n",
        "\n",
        "dino_model = dino_model.to(device)\n",
        "optimizer  = torch.optim.AdamW(\n",
        "    filter(lambda p: p.requires_grad, dino_model.parameters()), lr=1e-5\n",
        ")\n",
        "scaler = torch.amp.GradScaler('cuda')\n",
        "\n",
        "# ---- Training Loop ----\n",
        "num_epochs = 5\n",
        "dino_model.train()\n",
        "print(f'Starting Grounding DINO fine-tuning on {len(train_set)} images...')\n",
        "\n",
        "for epoch in range(num_epochs):\n",
        "    epoch_loss = 0.0\n",
        "    with tqdm(dino_loader, desc=f'Epoch {epoch+1}/{num_epochs}') as pbar:\n",
        "        for batch in pbar:\n",
        "            pixel_values   = batch['pixel_values'].to(device)\n",
        "            input_ids      = batch['input_ids'].to(device)\n",
        "            attention_mask = batch['attention_mask'].to(device)\n",
        "            labels = [{k: v.to(device) for k, v in t.items()} for t in batch['labels']]\n",
        "\n",
        "            optimizer.zero_grad(set_to_none=True)\n",
        "\n",
        "            with torch.amp.autocast('cuda'):\n",
        "                outputs = dino_model(\n",
        "                    pixel_values=pixel_values,\n",
        "                    input_ids=input_ids,\n",
        "                    attention_mask=attention_mask,\n",
        "                    labels=labels\n",
        "                )\n",
        "                loss = outputs.loss\n",
        "\n",
        "            scaler.scale(loss).backward()\n",
        "            scaler.unscale_(optimizer)\n",
        "            torch.nn.utils.clip_grad_norm_(dino_model.parameters(), max_norm=1.0)\n",
        "            scaler.step(optimizer)\n",
        "            scaler.update()\n",
        "\n",
        "            epoch_loss += loss.item()\n",
        "            pbar.set_postfix(loss=f'{loss.item():.4f}')\n",
        "\n",
        "    print(f'Epoch {epoch+1} Average Loss: {epoch_loss/len(dino_loader):.4f}')\n",
        "\n",
        "torch.save(dino_model.state_dict(), r'd:\\Sansarana\\dino_tuned_final.pth')\n",
        "print('Grounding DINO fine-tuning complete! Saved to dino_tuned_final.pth')\n"
    ]
}

nb['cells'].extend([markdown_cell, code_cell])

with open(notebook_path, 'w', encoding='utf-8') as f:
    json.dump(nb, f, indent=1)

print(f"Done. Total cells: {len(nb['cells'])}")
