exec(open('/home/claude/hoodie/turn.py').read())
import os; os.chdir('/home/claude/hoodie')
# --- 1) eyebrows back on the turned heads (stern: inner end low, toward the nose) ---
V={'o':0,'-':-1}
def edit_hair(path,pts):
    g=hair_idx(path)
    for x,y,v in pts: g[y,x]=v
    save_hair(g,path)
edit_hair('male_hair_medium_look_left_1x.png',
  [(27,18,-1),(29,19,-1),            # clear fringe strands that hid the brow
   (26,19,0),(27,19,0),(28,18,0),(29,18,0)])   # brow: low at the nose (left), rising outward
edit_hair('male_hair_medium_look_right_1x.png',
  [(35,18,-1),(37,18,-1),
   (33,18,0),(34,18,0),(35,19,0),(36,19,0)])   # brow: rising outward, low at the nose (right)
# --- 2) look-left: remove the bulge behind the jaw; nape runs ear -> neck ---
b=load('male_03_look_left_clean_1x.png')
def px(x,y,h):
    if h is None: b[y,x]=[0,0,0,0]
    else: b[y,x]=[int(h[i:i+2],16) for i in (1,3,5)]+[255]
S6='#d69b75'
for x,y,h in [(36,22,None),(35,22,OUT),
              (36,23,None),(35,23,None),(34,23,OUT),(33,23,S6),
              (36,24,None),(35,24,None),(34,24,OUT),(33,24,S6),
              (35,25,None),(34,25,None),(33,25,OUT),(32,25,S6),
              (35,26,None),(34,26,None),(33,26,OUT),(32,26,S6)]:
    px(x,y,h)
Image.fromarray(b).save('male_03_look_left_clean_1x.png')
