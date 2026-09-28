import json, math
from PIL import Image
import numpy as np
d=json.load(open('hero2.json'))
W,H=d['w'],d['h']; pal=d['palette']
CH="123456789abcdefghijklmnopqrstuvwxyz"
B=np.array([[0 if c=='.' else CH.index(c)+1 for c in r] for r in d['base']])
T=B.copy()
for x,y in d['erase']: T[y,x]=0   # torso without the hanging arm

def spans_mask(sp):
    m=np.zeros((H,W),bool)
    for y,segs in sp.items():
        for a,b in segs: m[y,a:b+1]=True
    return m

def cap_mask(caps):
    m=np.zeros((H,W),bool)
    for (ax,ay),(bx,by),r in caps:
        for y in range(H):
            for x in range(W):
                px,py=x+.5,y+.5; vx,vy=bx-ax,by-ay; L=vx*vx+vy*vy
                t=max(0,min(1,((px-ax)*vx+(py-ay)*vy)/L))
                if math.hypot(px-ax-t*vx,py-ay-t*vy)<=r: m[y,x]=True
    return m

def shade(suit,fist,rim_y,cuff_rows):
    """Shading modeled on the original arm: 1 outline, 4/c lit top+right, 2/3 shadow bottom+left, 5 fill."""
    out={}
    any_=suit|fist
    def outside(x,y,dirn):
        if not(0<=x<W and 0<=y<H): return True
        if any_[y,x]: return False
        if dirn=='L' and T[y,x]: return False   # shoulder joins torso without a seam
        return True
    def dist(x,y,dx,dy,dirn,m):
        for k in range(1,4):
            xx,yy=x+dx*k,y+dy*k
            if not(0<=xx<W and 0<=yy<H) or not m[yy,xx]:
                return k if outside(xx,yy,dirn) or not any_[yy,xx] else 9
        return 9
    for y in range(H):
        for x in range(W):
            if suit[y,x]:
                if any(outside(x+dx,y+dy,dn) for dx,dy,dn in ((1,0,'R'),(-1,0,'L'),(0,1,'D'),(0,-1,'U'))):
                    out[(x,y)]=1; continue
                dt=dist(x,y,0,-1,'U',suit); dr=dist(x,y,1,0,'R',suit)
                db=dist(x,y,0,1,'D',suit); dl=dist(x,y,-1,0,'L',suit)
                if y in cuff_rows: v=12 if dr>2 else 4
                elif dt==2: v=12 if y<=rim_y else 4
                elif dr==2: v=12 if y<=rim_y-3 else 4
                elif dr==3 or dt==3: v=4
                elif db==2: v=2
                elif dl==2 or db==3: v=3
                else: v=5
                out[(x,y)]=v
            elif fist[y,x]:
                if any(not(0<=x+dx<W and 0<=y+dy<H) or not any_[y+dy,x+dx] for dx,dy in ((1,0),(-1,0),(0,1),(0,-1))):
                    out[(x,y)]=1; continue
                dr=dist(x,y,1,0,'R',fist); dl=dist(x,y,-1,0,'L',fist); db=dist(x,y,0,1,'D',fist); dt=dist(x,y,0,-1,'U',fist)
                out[(x,y)]= 8 if (dr==2 or dt==2) else 6 if (dl==2 or db==2) else 7
    return out

FIST=[".11111.",
      "1a78881",
      "1777781",
      "1a77881",
      "1bbb871",
      "1166671"]
def fist_mask(x0,y0):
    m=np.zeros((H,W),bool)
    for j,r in enumerate(FIST):
        for i,c in enumerate(r):
            if c!='.': m[y0+j,x0+i]=True
    return m
def stamp_fist(p,x0,y0):
    for j,r in enumerate(FIST):
        for i,c in enumerate(r):
            if c!='.': p[(x0+i,y0+j)]=CH.index(c)+1

def flex_pose(pump=False):
    f=1 if pump else 0          # squeeze: fist drops 1px on the pump
    fist=np.zeros((H,W),bool); suit=np.zeros((H,W),bool)
    def S(m,y,a,b): m[y,a:b+1]=True
    # fist, angled toward the head
    fist=fist_mask(37,12+f)
    # cuff + forearm: narrow wrist, swelling toward the elbow (outer side)
    for y in range(18+f,21): S(suit,y,38,43)
    for y in (21,22): S(suit,y,37,43)
    for y in range(23,27): S(suit,y,37,44)
    # bicep: 2px rise (3px on the pump), notch at x36 leaves the elbow crease
    if pump:
        S(suit,24,32,34); S(suit,25,30,35); S(suit,26,27,44)
    else:
        S(suit,25,32,35); S(suit,26,27,44)
    # upper arm (deltoid joins shoulder at x24)
    for y in range(27,32): S(suit,y,24,45)
    S(suit,32,25,45)
    S(suit,33,27,44)          # triceps underside
    S(suit,34,32,42)
    # rear delt / lat wedge filling the armpit down to the torso contour
    for y,xmax in {32:33,33:32,34:31,35:30,36:28,37:27,38:26,39:25}.items():
        S(suit,y,24,xmax)
    p=shade(suit,fist,rim_y=26,cuff_rows=(18+f,))
    # armpit wedge sits in shadow: 3 fill, 2 against its outline
    wedge={32:33,33:32,34:31,35:30,36:28,37:27,38:26,39:25}
    for y,xmax in wedge.items():
        if y<33: continue
        for x in range(24,xmax+1):
            if p.get((x,y)) in (None,1): continue
            near=p.get((x+1,y))==1 or p.get((x,y+1))==1
            p[(x,y)]=2 if near else 3
    # soften the old torso seam through the shoulder so it reads as one mass
    for y in range(29,36):
        if T[y,23]==1: p[(23,y)]=3
    # elbow crease where forearm folds onto the bicep
    for xy in [(36,26),(36,27)]: p[xy]=1
    p[(37,27)]=3
    stamp_fist(p,37,12+f)
    return p

def raise_pose():
    suit=cap_mask([((25.5,31),(36.5,40),3.6),((36.5,40),(42.5,32.5),3.1)])
    fist=fist_mask(40,26)
    suit&=~fist
    p=shade(suit,fist,rim_y=31,cuff_rows=())
    stamp_fist(p,40,26)
    for (x,y) in [(36,52),(37,50),(38,48),(39,46),(34,55),(35,53),(41,44),(42,42)]:
        p.setdefault((x,y),12)
    return p

arms={"raise":raise_pose(),"flex":flex_pose(),"pump":flex_pose(True)}
d['arms']={k:[[x,y,v] for (x,y),v in p.items()] for k,p in arms.items()}
json.dump(d,open('hero3.json','w'),separators=(',',':'))

def render(a):
    A=T.copy()
    for (x,y),v in arms[a].items(): A[y,x]=v
    im=np.zeros((H,W,4),np.uint8)
    for y in range(H):
        for x in range(W):
            v=A[y,x]
            if v: h=pal[v-1]; im[y,x]=[int(h[i:i+2],16) for i in (1,3,5)]+[255]
    return Image.fromarray(im)
sheet=Image.new("RGBA",(3*36,48),(255,255,255,255))
for i,a in enumerate(["raise","flex","pump"]):
    sheet.alpha_composite(render(a).crop((14,10,50,58)),(i*36,0))
sheet.resize((3*36*9,48*9),Image.NEAREST).save("arm2.png")
