from PIL import Image
import numpy as np
from scipy import ndimage
OUT='#101118'
HAIR=['#0e2a12','#1d4a24','#2f6e37','#4a9652','#74c07a']
SKIN={'#f5c69d','#eab58d','#d69b75','#b77f63','#8d6050','#f5efe3'}
hx=lambda p:'#%02x%02x%02x'%tuple(p[:3])
def load(n):
    a=np.array(Image.open(f'{n}_1x.png'))
    g=np.full(a.shape[:2],-1)          # -1 empty, 0 outline, 1..5 hair ramp
    for y,x in zip(*np.where(a[:,:,3]>0)):
        c=hx(a[y,x]); g[y,x]=0 if c==OUT else HAIR.index(c)+1
    return g
def body_masks(n):
    b=np.array(Image.open(f'{n}_1x.png'))
    op=b[:,:,3]>0
    sk=np.zeros(op.shape,bool)
    for y,x in zip(*np.where(op)): sk[y,x]=hx(b[y,x]) in SKIN
    return op,sk
N4=((1,0),(-1,0),(0,1),(0,-1))
def nb(g,y,x,cond):
    H,W=g.shape; return sum(1 for dx,dy in N4 if 0<=y+dy<H and 0<=x+dx<W and cond(g[y+dy,x+dx]))
def clean(g,body_op,face_trim=None,sk=None,front=True):
    g=g.copy(); H,W=g.shape
    if face_trim:
        y0,y1,xmin=face_trim
        cut=np.zeros_like(g,bool)
        for y in range(y0,y1+1):
            for x in range(xmin,W):
                if g[y,x]>=0 and sk[y,x]: g[y,x]=-1; cut[y,x]=True
        for y in range(y0,y1+1):   # outline the new curtain edge
            for x in range(W):
                if g[y,x]>0 and any(0<=x+dx<W and cut[y+dy,x+dx] for dx,dy in N4 if 0<=y+dy<H): g[y,x]=0
    for _ in range(2):             # strip spurs, tails, stray bars
        kill=[(y,x) for y,x in zip(*np.where(g>=0)) if nb(g,y,x,lambda v:v>=0)<=1]
        for y,x in kill: g[y,x]=-1
    lab,k=ndimage.label(g>=0)
    for i in range(1,k+1):
        if (lab==i).sum()<5: g[lab==i]=-1
    src=g.copy()                   # lone interior outline pixels -> dark hair
    for y,x in zip(*np.where(src==0)):
        if nb(src,y,x,lambda v:v>=0)==4 and nb(src,y,x,lambda v:v==0)==0: g[y,x]=1
    src=g.copy()                   # mode filter on hair shades
    for y,x in zip(*np.where(src>0)):
        win=src[max(0,y-1):y+2,max(0,x-1):x+2].ravel(); win=win[win>0]
        vals,cnt=np.unique(np.concatenate([win,[src[y,x]]]),return_counts=True)
        g[y,x]=vals[cnt.argmax()]
    src=g.copy()                   # crisp silhouette where hair meets empty background
    for y,x in zip(*np.where(src>=3)):
        if nb(src,y,x,lambda v:v>=0)>=3: continue
        for dx,dy in N4:
            yy,xx=y+dy,x+dx
            if 0<=yy<H and 0<=xx<W and src[yy,xx]<0 and not body_op[yy,xx]: g[y,x]=0; break
    return g
def save(g,n):
    H,W=g.shape; im=np.zeros((H,W,4),np.uint8)
    for y,x in zip(*np.where(g>=0)):
        c=OUT if g[y,x]==0 else HAIR[g[y,x]-1]
        im[y,x]=[int(c[i:i+2],16) for i in (1,3,5)]+[255]
    Image.fromarray(im).save(f'clean_{n}_1x.png')
    Image.fromarray(im).resize((W*8,H*8),Image.NEAREST).save(f'/home/claude/handoff/out_{n}.png')
mop,msk=body_masks('male_body_bald'); fop,fsk=body_masks('female_body_bald')
jobs=[('male_hair_wolf_front',mop,None,msk),('male_hair_wolf_back',mop,None,msk),
      ('female_hair_long_front',fop,(16,25,29),fsk),('female_hair_long_back',fop,None,fsk)]
for n,op,ft,sk in jobs:
    g0=load(n); g=clean(g0,op,ft,sk); save(g,n)
    print(n,'pixels',int((g0>=0).sum()),'->',int((g>=0).sum()))
