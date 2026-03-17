import json
with open('d:/Sansarana/Interim_Demo.ipynb', 'r', encoding='utf-8') as f:
    nb = json.load(f)
for i, cell in enumerate(nb['cells']):
    print(f"--- Cell {i} ({cell['cell_type']}) ---")
    if cell['cell_type'] == 'code':
        for idx, line in enumerate(cell['source']):
            print(f"{idx}: {line.rstrip()}")
