import json

notebook_path = 'd:/Sansarana/train_object_detection.ipynb'
with open(notebook_path, 'r', encoding='utf-8') as f:
    nb = json.load(f)

# Find the comparison cell and prepend the pip install
for cell in nb['cells']:
    if cell.get('cell_type') == 'code' and 'import pandas as pd' in ''.join(cell.get('source', [])):
        src = ''.join(cell['source'])
        if '!pip install -q pandas' not in src:
            new_src = '!pip install -q pandas\n' + src
            cell['source'] = [line + '\n' for line in new_src.split('\n')]
            cell['source'][-1] = cell['source'][-1].rstrip('\n')
        break

with open(notebook_path, 'w', encoding='utf-8') as f:
    json.dump(nb, f, indent=1)
print("Done.")
