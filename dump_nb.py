import json
import codecs

with codecs.open('d:/Sansarana/Interim_Demo.ipynb', 'r', 'utf-8') as f:
    nb = json.load(f)

with codecs.open('d:/Sansarana/view_all.txt', 'w', 'utf-8') as out:
    for i, cell in enumerate(nb['cells']):
        out.write(f"--- Cell {i} ({cell['cell_type']}) ---\n")
        if cell['cell_type'] == 'code':
            for line in cell['source']:
                out.write(line)
            out.write("\n")
