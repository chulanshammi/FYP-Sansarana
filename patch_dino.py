import json

notebook_path = 'd:/Sansarana/train_object_detection.ipynb'
with open(notebook_path, 'r', encoding='utf-8') as f:
    nb = json.load(f)

for cell in nb['cells']:
    if cell.get('cell_type') == 'code' and 'IDEA-Research/grounding-dino-base' in ''.join(cell.get('source', [])):
        code = ''.join(cell['source'])
        new_code = code.replace(
            "for param in dino_model.backbone.parameters():",
            "for param in dino_model.model.backbone.parameters():"
        ).replace(
            "for param in dino_model.text_backbone.parameters():",
            "for param in dino_model.model.text_backbone.parameters():"
        )
        
        lines = [line + '\n' for line in new_code.split('\n')]
        if lines: lines[-1] = lines[-1].rstrip('\n')
        cell['source'] = lines
        break

with open(notebook_path, 'w', encoding='utf-8') as f:
    json.dump(nb, f, indent=1)
