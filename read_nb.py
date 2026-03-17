import json; f=open('d:/Sansarana/Interim_Demo.ipynb'); d=json.load(f); f.close();
for i, c in enumerate(d['cells']):
    print(f"Cell {i}:")
    print("".join(c['source']))
