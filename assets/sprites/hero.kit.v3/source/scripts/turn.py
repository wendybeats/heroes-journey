from PIL import Image
import numpy as np
hx=lambda p:'#%02x%02x%02x'%tuple(p[:3])
SK=['#8d6050','#b77f63','#d69b75','#eab58d','#f5c69d']   # dark->light
OUT='#101118'; EYEW='#f5efe3'
HR=['#0e2a12','#1d4a24','#2f6e37','#4a9652','#74c07a']
lum=lambda h:sum(int(h[i:i+2],16) for i in (1,3,5))
def load(p): return np.array(Image.open(p))
def setc(a,y,x,h): a[y,x]=[int(h[i:i+2],16) for i in (1,3,5)]+[255]

def clean_head(a,y0=12,y1=26):
    """Head rows only: stray clothing/suit greys inside the head become skin or outline."""
    a=a.copy(); H,W=a.shape[:2]
    for y in range(y0,y1+1):
        for x in range(W):
            if not a[y,x,3]: continue
            c=hx(a[y,x])
            if c in SK or c in (OUT,EYEW): continue
            edge=any(not a[y+dy,x+dx,3] for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)))
            if edge: setc(a,y,x,OUT)
            else:   # nearest skin by brightness
                L=lum(c); setc(a,y,x,min(SK,key=lambda s:abs(lum(s)-L)))
    return a

N4=((1,0),(-1,0),(0,1),(0,-1))
def hair_idx(h):   # -1 none, 0 outline, 1..5 ramp
    a=load(h); g=np.full(a.shape[:2],-1)
    for y,x in zip(*np.where(a[:,:,3]>0)):
        c=hx(a[y,x]); g[y,x]=0 if c==OUT else HR.index(c)+1
    return g
def build_hair(head, src, dx, dy, mirror_c=None, face=lambda y,x:False, hairline=lambda x:17):
    H,W=src.shape; g=np.full((H,W),-1)
    for y,x in zip(*np.where(src>=0)):
        xx = (2*mirror_c - x) if mirror_c is not None else x
        xx+=dx; yy=y+dy
        if 0<=xx<W and 0<=yy<H: g[yy,xx]=src[y,x]
    skin=np.zeros((H,W),bool); headop=head[:,:,3]>0
    for y in range(0,27):
        for x in range(W):
            if headop[y,x] and hx(head[y,x]) in SK+[EYEW]: skin[y,x]=True
    # 1) clear hair off the face window
    for y in range(H):
        for x in range(W):
            if g[y,x]>=0 and face(y,x): g[y,x]=-1
    # 2) cover exposed scalp above the hairline (and the head outline next to it)
    for y in range(0,27):
        for x in range(W):
            if y<hairline(x) and headop[y,x] and g[y,x]<0 and not face(y,x): g[y,x]=2
    # 3) outline: hair pixels touching empty background, or touching visible face skin
    src2=g.copy()
    for y,x in zip(*np.where(src2>0)):
        for dx_,dy_ in N4:
            yy,xx=y+dy_,x+dx_
            if not(0<=yy<H and 0<=xx<W): continue
            if src2[yy,xx]<0 and not headop[yy,xx]:
                g[y,x]=0; break          # silhouette against background: outline
            if src2[yy,xx]<0 and skin[yy,xx] and g[y,x]>1:
                g[y,x]=1                 # edge against skin: darkest hair, softer than outline
    return g
def save_hair(g,path):
    H,W=g.shape; im=np.zeros((H,W,4),np.uint8)
    for y,x in zip(*np.where(g>=0)):
        c=OUT if g[y,x]==0 else HR[g[y,x]-1]; im[y,x]=[int(c[i:i+2],16) for i in (1,3,5)]+[255]
    Image.fromarray(im).save(path); return im
BLACK=['#16171f','#1f212b','#2c2f3c','#3f4456','#5d6680']
def comp(body,hair_im,recolor=True):
    c=Image.fromarray(body).copy(); h=hair_im.copy()
    if recolor:
        for i,k in enumerate(HR):
            m=(h[:,:,0]==int(k[1:3],16))&(h[:,:,1]==int(k[3:5],16))&(h[:,:,2]==int(k[5:7],16))&(h[:,:,3]>0)
            h[m,:3]=[int(BLACK[i][j:j+2],16) for j in (1,3,5)]
    c.alpha_composite(Image.fromarray(h)); return c
