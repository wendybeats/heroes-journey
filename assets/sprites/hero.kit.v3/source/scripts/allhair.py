exec(open('/home/claude/hoodie/turn.py').read())
import os, json; os.chdir('/home/claude/hoodie')
REF='/home/claude/handoff/'
def px(a,x,y,h):
    if h is None: a[y,x]=[0,0,0,0]
    else: setc(a,y,x,h)
# ---------- final turned-head bodies ----------
mL=load('male_03_look_left_clean_1x.png'); mR=load('male_04_look_right_clean_1x.png')
for x,y in [(26,19),(27,19),(28,18),(29,18)]: px(mL,x,y,OUT)      # brows now live on the face itself
for x,y in [(33,18),(34,18),(35,19),(36,19)]: px(mR,x,y,OUT)
fL=load('female_03_look_left_clean_1x.png'); fR=load('female_04_look_right_clean_1x.png')
px(fR,35,20,OUT)                                                  # upper lid so the eye reads
BODY={}
for g,a,b in [('male',mL,mR),('female',fL,fR)]:
    Image.fromarray(a).save(f'{g}_head_L_1x.png'); Image.fromarray(b).save(f'{g}_head_R_1x.png'); BODY[g]={'L':a,'R':b}
# ---------- per-head geometry ----------
# mode: shift keeps the neutral hair's asymmetry (head turns the way it already faces); mirror flips it
TEMPLE={'female':4}
GEO={('male','L'):dict(gender='male',mirror_c=None,dx=-2,split=32,front=True),
     ('male','R'):dict(gender='male',mirror_c=32,dx=1,split=31,front=False),
     ('female','R'):dict(gender='female',mirror_c=None,dx=1,split=31,front=False),
     ('female','L'):dict(gender='female',mirror_c=31,dx=0,split=32,front=True)}
BROW={('male','L'):[(26,19),(27,19),(28,18),(29,18)],('male','R'):[(33,18),(34,18),(35,19),(36,19)],
      ('female','L'):[(27,19),(28,19)],('female','R'):[(35,18),(36,18)]}
# hairlines per style: (front, mid, back) rows; brow=True clears hair off the brow
STY={'male':{'buzz':(16,17,19,True),'medium':(18,20,23,True),'wolf':(18,21,27,True)},
     'female':{'blunt':(20,24,27,False),'long':(19,22,27,True),'ponytail':(17,18,20,True)}}
BACKS={'wolf','long','ponytail'}
def transform(src,geo):
    H,W=src.shape; g=np.full((H,W),-1)
    for y,x in zip(*np.where(src>=0)):
        xx=(2*geo['mirror_c']-x) if geo['mirror_c'] is not None else x
        xx+=geo['dx']; yy=y+1
        if 0<=xx<W and 0<=yy<H: g[yy,xx]=src[y,x]
    return g
def fit_front(g,head,geo,hl,brow_pts,brow):
    H,W=g.shape; f,m,b=hl[:3]; sp=geo['split']; facingL=geo['front']
    front=lambda x: x<=sp if facingL else x>=sp
    midz =lambda x: x<=sp+2 if facingL else x>=sp-2
    hline=lambda x: f if front(x) else (m if midz(x) else b)
    face=lambda y,x: hline(x)<=y<=26 and front(x)
    headop=head[:,:,3]>0
    skin=np.zeros((H,W),bool)
    for y in range(27):
        for x in range(W):
            if headop[y,x] and hx(head[y,x]) in SK+[EYEW]: skin[y,x]=True
    for y in range(27):
        for x in range(W):
            if g[y,x]>=0 and face(y,x): g[y,x]=-1
    trans=g.copy()
    # round the temple corner: a diagonal of hair where the hairline meets the back edge of the face
    K=TEMPLE.get(geo.get('gender'),0)
    if K:
        for y in range(f,27):
            for x in range(W):
                u=(sp-x) if facingL else (x-sp)
                if 0<=u and u+(y-f)<K and headop[y,x] and skin[y,x] and (x,y) not in brow_pts: g[y,x]=-2
    for y in range(27):                      # cover scalp above the hairline, texture copied from nearest hair in the row
        row=[x for x in range(W) if trans[y,x]>0]
        for x in range(W):
            if (g[y,x]==-2) or (y<hline(x) and headop[y,x] and g[y,x]<0 and not face(y,x)):
                g[y,x]=trans[y,min(row,key=lambda r:abs(r-x))] if row else 2
    src2=g.copy()
    for y,x in zip(*np.where(src2>0)):
        for dx_,dy_ in N4:
            yy,xx=y+dy_,x+dx_
            if not(0<=yy<H and 0<=xx<W): continue
            if src2[yy,xx]<0 and not headop[yy,xx] and yy<27: g[y,x]=0; break
            if src2[yy,xx]<0 and skin[yy,xx] and g[y,x]>1: g[y,x]=1
    if brow:
        for x,y in brow_pts:
            for yy in (y,y-1):
                if g[yy,x]>=0 and yy>=hline(x)-1: g[yy,x]=-1
    return g
from scipy import ndimage
def despeck(g):
    lab,k=ndimage.label(g>=0,structure=np.ones((3,3)))
    for i in range(1,k+1):
        if (lab==i).sum()<4: g[lab==i]=-1
    return g
OUTS={}
for gname,styles in STY.items():
    for st,hl in styles.items():
        pre='clean_' if st=='wolf' else ''                     # approved wolf = cleaned layers
        fsrc=hair_idx(f'{REF}{pre}{gname}_hair_{st}_front_1x.png')
        bsrc=hair_idx(f'{REF}{pre}{gname}_hair_{st}_back_1x.png') if st in BACKS else None
        for d in 'LR':
            if gname=='male' and st=='medium':      # approved in review; keep as is
                g=hair_idx(f'male_hair_medium_look_{"left" if d=="L" else "right"}_1x.png')
            else:
                g=fit_front(transform(fsrc,GEO[(gname,d)]),BODY[gname][d],GEO[(gname,d)],hl,BROW[(gname,d)],hl[3])
            save_hair(despeck(g),f'dir_{gname}_{st}_front_{d}_1x.png')
            if bsrc is not None: save_hair(despeck(transform(bsrc,GEO[(gname,d)])),f'dir_{gname}_{st}_back_{d}_1x.png')
print('ok')
