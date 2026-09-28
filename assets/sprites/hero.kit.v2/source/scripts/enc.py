from PIL import Image
import numpy as np, json
im=np.array(Image.open('/mnt/user-data/uploads/1c72e8dde7c4ca98ec5e50c11ccebcbde72983cc.png').convert('RGBA'))
X0,X1,Y0,Y1=13,53,5,124   # crop with margin + headroom for the rise
frames=[im[Y0:Y1, i*64+X0:i*64+X1] for i in range(3)]
cols=[]
for f in frames:
    for px in f.reshape(-1,4):
        if px[3]>0 and tuple(px[:3]) not in cols: cols.append(tuple(px[:3]))
assert len(cols)<=35
CH="123456789abcdefghijklmnopqrstuvwxyz"
def enc(f):
    rows=[]
    for r in f:
        rows.append("".join("." if p[3]==0 else CH[cols.index(tuple(p[:3]))] for p in r))
    return rows
base=enc(frames[0])
deltas=[]
for f in frames[1:]:
    g=enc(f); d=[]
    for y in range(len(g)):
        for x in range(len(g[0])):
            if g[y][x]!=base[y][x]: d.append([x,y,g[y][x]])
    deltas.append(d)
data={"w":X1-X0,"h":Y1-Y0,"palette":["#%02x%02x%02x"%c for c in cols],"base":base,"deltas":deltas}
s=json.dumps(data,separators=(",",":"));open("hero.json","w").write(s)
print(data["w"],data["h"],len(cols),len(s),"bytes",[len(d) for d in deltas])
# figure top row / find candidate seam rows
a=frames[0][:,:,3]>0
print("top",np.where(a.any(1))[0].min())
Image.fromarray(frames[0]).resize(((X1-X0)*5,(Y1-Y0)*5),Image.NEAREST).save("f0.png")
