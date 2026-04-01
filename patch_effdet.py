import json

notebook_path = 'd:/Sansarana/train_object_detection.ipynb'
with open(notebook_path, 'r', encoding='utf-8') as f:
    nb = json.load(f)

for cell in nb['cells']:
    if cell.get('cell_type') == 'code' and 'create_model(' in ''.join(cell.get('source', [])):
        code = ''.join(cell['source'])
        if 'bench_labeler=True' not in code:
            new_code = code.replace(
                "effdet_model = create_model('tf_efficientdet_d0', bench_task='train', num_classes=3, pretrained=True)",
                "effdet_model = create_model('tf_efficientdet_d0', bench_task='train', num_classes=3, pretrained=True, bench_labeler=True)"
            )
            
            lines = [line + '\n' for line in new_code.split('\n')]
            if lines: lines[-1] = lines[-1].rstrip('\n')
            cell['source'] = lines
        break

with open(notebook_path, 'w', encoding='utf-8') as f:
    json.dump(nb, f, indent=1)
