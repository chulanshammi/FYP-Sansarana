import json

notebook_path = 'd:/Sansarana/train_object_detection.ipynb'
with open(notebook_path, 'r', encoding='utf-8') as f:
    nb = json.load(f)

# Find the EfficientDet code cell
for i, cell in enumerate(nb['cells']):
    if cell.get('cell_type') == 'code' and 'effdet_collate' in ''.join(cell.get('source', [])):
        code = ''.join(cell['source'])
        if 'pad_w' not in code:
            new_code = code.replace(
                "    images = torch.stack([b[0] for b in batch])",
                "    # Pad images natively to multiples of 128 for BiFPN\n"
                "    padded_images = []\n"
                "    for b in batch:\n"
                "        img = b[0]\n"
                "        h, w = img.shape[-2:]\n"
                "        pad_h = (128 - (h % 128)) % 128\n"
                "        pad_w = (128 - (w % 128)) % 128\n"
                "        padded_images.append(torch.nn.functional.pad(img, (0, pad_w, 0, pad_h), value=0.0))\n"
                "    images = torch.stack(padded_images)"
            )
            
            lines = [line + '\n' for line in new_code.split('\n')]
            if lines: lines[-1] = lines[-1].rstrip('\n')
            cell['source'] = lines
            
        break

with open(notebook_path, 'w', encoding='utf-8') as f:
    json.dump(nb, f, indent=1)
