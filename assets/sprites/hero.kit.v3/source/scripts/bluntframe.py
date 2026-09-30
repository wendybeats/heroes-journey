exec(open('/home/claude/hoodie/turn.py').read())
import os; os.chdir('/home/claude/hoodie')
# Blunt bob: side curtains come forward over the face edge, tapering at the jaw
SPLIT={'L':32,'R':31}; F=20
DEPTH={20:3,21:3,22:3,23:3,24:2,25:1}
for d in 'LR':
    p=f'dir_female_blunt_front_{d}_1x.png'; g=hair_idx(p); head=load(f'female_head_{d}_1x.png')
    sp=SPLIT[d]
    for y,k in DEPTH.items():
        row=[x for x in range(64) if g[y,x]>0]
        for u in range(k):
            x=sp-u if d=='L' else sp+u
            if head[y,x,3] and g[y,x]<0:
                g[y,x]=g[y,min(row,key=lambda r:abs(r-x))] if row else 2
        # inner edge of the curtain sits in shadow against the cheek
        xe=sp-(k-1) if d=='L' else sp+(k-1)
        if g[y,xe]>1: g[y,xe]=1
    save_hair(g,p)
print('ok')
