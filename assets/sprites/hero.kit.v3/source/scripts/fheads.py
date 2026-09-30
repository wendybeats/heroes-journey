exec(open('/home/claude/hoodie/turn.py').read())
import os; os.chdir('/home/claude/hoodie')
TONE={'#eab58d':'#f5c69d','#d69b75':'#eab58d','#b77f63':'#d69b75'}   # turned heads were one step darker than neutral
def fix_female(n):
    a=clean_head(load(f'female_hoodie_{n}_1x.png'),12,26)
    for y in range(12,27):
        for x in range(64):
            if a[y,x,3] and hx(a[y,x]) in TONE: setc(a,y,x,TONE[hx(a[y,x])])
    # close the open silhouette: transparent pixels touching head skin get outline
    add=[]
    for y in range(12,27):
        for x in range(1,63):
            if a[y,x,3]: continue
            if any(a[y+dy,x+dx,3] and hx(a[y+dy,x+dx]) in SK for dx,dy in N4 if 12<=y+dy<=26): add.append((x,y))
    for x,y in add: setc(a,y,x,OUT)
    return a
for n in ['03_look_left','04_look_right']:
    Image.fromarray(fix_female(n)).save(f'female_{n}_clean_1x.png')
S=Image.new('RGBA',(5*26,24),(255,255,255,255))
for i,f in enumerate(['female_hoodie_02_pocketed_1x.png','female_hoodie_03_look_left_1x.png','female_03_look_left_clean_1x.png','female_hoodie_04_look_right_1x.png','female_04_look_right_clean_1x.png']):
    S.alpha_composite(Image.open(f).crop((19,10,45,34)),(i*26,0))
S.resize((S.width*10,S.height*10),Image.NEAREST).save('fheads.png')

def smooth_face(a, keep_near_features=True):
    """Remove stray darker skin strokes: a skin pixel darker than its 3x3 skin majority takes the majority,
    unless it touches outline/eye pixels (eyes, brows, jaw contour stay)."""
    src=a.copy(); order={h:i for i,h in enumerate(SK)}
    for y in range(13,27):
        for x in range(1,63):
            c=hx(src[y,x]) if src[y,x,3] else None
            if c not in order: continue
            if keep_near_features and any(src[y+dy,x+dx,3] and hx(src[y+dy,x+dx]) in (OUT,EYEW) for dx,dy in N4): continue
            win=[hx(src[yy,xx]) for yy in range(y-1,y+2) for xx in range(x-1,x+2) if src[yy,xx,3] and hx(src[yy,xx]) in order]
            maj=max(set(win),key=win.count)
            if order[c]<order[maj] and win.count(maj)>=5: setc(a,y,x,maj)
    return a
for n in ['03_look_left','04_look_right']:
    a=load(f'female_{n}_clean_1x.png'); smooth_face(a); Image.fromarray(a).save(f'female_{n}_clean_1x.png')
S=Image.new('RGBA',(3*26,24),(255,255,255,255))
for i,f in enumerate(['female_hoodie_02_pocketed_1x.png','female_03_look_left_clean_1x.png','female_04_look_right_clean_1x.png']):
    S.alpha_composite(Image.open(f).crop((19,10,45,34)),(i*26,0))
S.resize((S.width*12,S.height*12),Image.NEAREST).save('fheads2.png')
