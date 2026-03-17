import json;
with open('d:/Sansarana/Interim_Demo.ipynb', 'r', encoding='utf-8') as f:
    d = json.load(f)
with open('d:/Sansarana/read_nb2.py', 'w', encoding='utf-8') as out:
    for i, c in enumerate(d['cells']):
        if c['cell_type'] == 'code':
            out.write(f"# Cell {i}:\n")
            out.write("".join(c['source']))
            out.write("\n\n")
