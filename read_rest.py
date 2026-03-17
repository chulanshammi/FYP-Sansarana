import json
import codecs

with codecs.open('d:/Sansarana/Interim_Demo.ipynb', 'r', 'utf-8') as f:
    d = json.load(f)

with codecs.open('d:/Sansarana/rest_of_nb.txt', 'w', 'utf-8') as out:
    for i, c in enumerate(d['cells']):
        if c['cell_type'] == 'code' and i >= 9:
            out.write(f"Cell {i}:\n")
            out.write("".join(c['source']))
            out.write("\n\n")
