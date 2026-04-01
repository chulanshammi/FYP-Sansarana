import json

notebook_path = 'd:/Sansarana/train_object_detection.ipynb'
with open(notebook_path, 'r', encoding='utf-8') as f:
    nb = json.load(f)

markdown_cell = {
    "cell_type": "markdown",
    "metadata": {},
    "source": [
        "### Evaluate EfficientDet Metrics\n",
        "Just like Faster R-CNN, we evaluate our EfficientDet model using standard **COCO Mean Average Precision (mAP)**. We switch the model to a `bench_task='predict'` wrapper to automatically decode the complex BiFPN features into distinct bounding boxes."
    ]
}

code_cell = {
    "cell_type": "code",
    "execution_count": None,
    "metadata": {},
    "outputs": [],
    "source": [
        "import torchmetrics.utilities.imports\n",
        "import torchmetrics.detection.helpers\n",
        "import torchmetrics.detection.mean_ap\n",
        "torchmetrics.utilities.imports._PYCOCOTOOLS_AVAILABLE = True\n",
        "torchmetrics.utilities.imports._FASTER_COCO_EVAL_AVAILABLE = True\n",
        "torchmetrics.detection.helpers._PYCOCOTOOLS_AVAILABLE = True\n",
        "torchmetrics.detection.helpers._FASTER_COCO_EVAL_AVAILABLE = True\n",
        "torchmetrics.detection.mean_ap._PYCOCOTOOLS_AVAILABLE = True\n",
        "torchmetrics.detection.mean_ap._FASTER_COCO_EVAL_AVAILABLE = True\n",
        "from torchmetrics.detection.mean_ap import MeanAveragePrecision\n",
        "\n",
        "# 1. Rebuild EfficientDet explicitly for 'predict' task. This wraps the model in a decoder \n",
        "# so we get clean [xmin, ymin, xmax, ymax, score, label] boxes instead of raw computational loss graphs.\n",
        "print(\"Loading DetBenchPredict for EfficientDet Validation...\")\n",
        "eval_model = create_model('tf_efficientdet_d0', bench_task='predict', num_classes=3, pretrained=False)\n",
        "eval_model.load_state_dict(torch.load(r'd:\\Sansarana\\efficientdet_final.pth'))\n",
        "eval_model = eval_model.to(device)\n",
        "eval_model.eval()\n",
        "\n",
        "# 2. Load Validation Set\n",
        "val_set = EffDetVOCDataset(r'd:\\Sansarana\\EfficientDetVOC\\valid')\n",
        "val_loader = DataLoader(val_set, batch_size=2, shuffle=False, collate_fn=effdet_collate, num_workers=0)\n",
        "\n",
        "# 3. Setup COCO mAP metric tracking\n",
        "metric = MeanAveragePrecision(box_format='xyxy', class_metrics=True, backend='faster_coco_eval')\n",
        "\n",
        "# 4. Validate\n",
        "with torch.no_grad():\n",
        "    for images, batch_targets in tqdm(val_loader, desc=\"Evaluating EfficientDet\"):\n",
        "        images = images.to(device)\n",
        "        \n",
        "        # effdet predict bench natively requires img_scale and img_size metadata for coordinate un-scaling\n",
        "        # Since our padded size is always 512x512, we explicitly broadcast scale=1.0, size=512x512 \n",
        "        batch_size = images.shape[0]\n",
        "        img_info = {\n",
        "            'img_scale': torch.ones((batch_size,)).to(device),\n",
        "            'img_size': torch.tensor([[512, 512]] * batch_size, dtype=torch.float).to(device)\n",
        "        }\n",
        "        \n",
        "        with torch.amp.autocast('cuda'):\n",
        "            # Predict wrapper outputs a dense tensor [Batch, NumBoxes, 6]\n",
        "            # Structure: [xmin, ymin, xmax, ymax, score, class_id]\n",
        "            detections = eval_model(images, img_info=img_info)\n",
        "            \n",
        "        metric_targets = []\n",
        "        metric_preds = []\n",
        "        \n",
        "        for i in range(batch_size):\n",
        "            # --- Parse Targets ---\n",
        "            # Retrieve only non-padded targets\n",
        "            valid_targets_mask = batch_targets['cls'][i] != -1\n",
        "            valid_boxes = batch_targets['bbox'][i][valid_targets_mask]\n",
        "            valid_labels = batch_targets['cls'][i][valid_targets_mask]\n",
        "            \n",
        "            # EfficientDet internally tracks targets natively as ymin, xmin, ymax, xmax.\n",
        "            # But torchmetrics `xyxy` box_format expects xmin, ymin, xmax, ymax.\n",
        "            # So we must invert [ymin, xmin, ymax, xmax] -> [xmin, ymin, xmax, ymax]\n",
        "            if valid_boxes.shape[0] > 0:\n",
        "                valid_boxes = valid_boxes[:, [1, 0, 3, 2]] \n",
        "                \n",
        "            metric_targets.append({\n",
        "                \"boxes\": valid_boxes.to(device),\n",
        "                \"labels\": valid_labels.to(device)\n",
        "            })\n",
        "            \n",
        "            # --- Parse Predictions ---\n",
        "            det = detections[i] # [NumBoxes, 6]\n",
        "            # Filter out extreme noise threshold (e.g. score > 0.05)\n",
        "            det = det[det[:, 4] > 0.05]\n",
        "            \n",
        "            # The bench output is already mapped exactly back as xmin, ymin, xmax, ymax!\n",
        "            metric_preds.append({\n",
        "                \"boxes\": det[:, 0:4].to(device),\n",
        "                \"scores\": det[:, 4].to(device),\n",
        "                \"labels\": det[:, 5].to(torch.int64).to(device)\n",
        "            })\n",
        "            \n",
        "        metric.update(metric_preds, metric_targets)\n",
        "\n",
        "results = metric.compute()\n",
        "print(\"\\n--- EfficientDet Final Metrics ---\")\n",
        "print(f\"mAP (IoU 0.50:0.95): {results['map'].item():.4f}\")\n",
        "print(f\"mAP@50 (IoU 0.50):   {results['map_50'].item():.4f}\")\n",
        "print(f\"mAP@75 (IoU 0.75):   {results['map_75'].item():.4f}\")\n"
    ]
}

nb['cells'].extend([markdown_cell, code_cell])

with open(notebook_path, 'w', encoding='utf-8') as f:
    json.dump(nb, f, indent=1)
