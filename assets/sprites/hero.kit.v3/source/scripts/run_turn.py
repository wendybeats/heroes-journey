exec(open('/home/claude/hoodie/turn.py').read())
import os; os.chdir('/home/claude/hoodie')
src=hair_idx('/home/claude/handoff/male_hair_medium_front_1x.png')
neutral=load('male_hoodie_02_pocketed_1x.png')
L=load('male_03_look_left_clean_1x.png'); R=load('male_04_look_right_clean_1x.png')
# look left: face toward screen-left; neutral hair shifted left, face window = front-lower part
gl=build_hair(L,src,dx=-2,dy=1,face=lambda y,x: y>=18 and x<=32 and y<=26, hairline=lambda x: 18 if x<=32 else (20 if x<=34 else 23))
# look right: mirror neutral hair about head center, face window on the right
gr=build_hair(R,src,dx=1,dy=1,mirror_c=32,face=lambda y,x: y>=18 and x>=31 and y<=26, hairline=lambda x: 18 if x>=32 else (20 if x>=30 else 23))
# fringe strands falling over the forehead (front side), like the neutral fringe
for x,y,v in [(27,18,0),(29,18,1),(29,19,0),(31,18,0)]: gl[y,x]=v
for x,y,v in [(37,18,0),(35,18,1),(35,19,0),(33,18,0)]: gr[y,x]=v
V={'o':0,'a':1,'b':2,'c':3,'d':4,'.':-1}
def paint(g,x0,y,row):
    for i,ch in enumerate(row):
        if ch!=' ': g[y,x0+i]=V[ch]
# look left: back drape (screen right) as tapered strands behind the ear
paint(gl,33,18,"ababao"); paint(gl,33,19,"abbao "); paint(gl,33,20," abo  ")
paint(gl,33,21,"  ao  "); paint(gl,33,22,"  o.  ")
# look right: back drape (screen left)
paint(gr,24,18,"obcbaba"); paint(gr,24,19," obbabo"); paint(gr,24,20," oaboao")
paint(gr,24,21,"   oao "); paint(gr,24,22,"   .oo ")
hl=save_hair(gl,'male_hair_medium_look_left_1x.png'); hr=save_hair(gr,'male_hair_medium_look_right_1x.png')
hn=load('/home/claude/handoff/male_hair_medium_front_1x.png')
frames=[comp(neutral,hn),comp(L,hl),comp(R,hr),comp(L,hl,False),comp(R,hr,False)]
S=Image.new('RGBA',(5*30,26),(255,255,255,255))
for i,f in enumerate(frames): S.alpha_composite(f.crop((17,6,47,32)),(i*30,0))
S.resize((S.width*10,S.height*10),Image.NEAREST).save('hairtest.png')
