data=open('anim.json').read()
html=r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Animated variants</title>
<style>
:root{--bg:#dde2e8;--panel:#f6f7f9;--ink:#1a2130;--mute:#5b6576;--line:#c5ccd6}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.45 ui-sans-serif,system-ui,-apple-system,"SF Pro Text",sans-serif}
main{max-width:860px;margin:0 auto;padding:20px 16px 40px}
h1{font-size:22px;margin:0 0 4px;font-weight:650;letter-spacing:-.01em}
p.sub{margin:0 0 18px;color:var(--mute);max-width:68ch}
.stage{display:flex;gap:18px;align-items:flex-start;flex-wrap:wrap;background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:16px}
.checker{background:repeating-conic-gradient(#e7eaee 0 25%,#f6f7f9 0 50%) 0 0/18px 18px;border-radius:8px;image-rendering:pixelated}
#hero{width:192px;height:384px}
.side{display:flex;flex-direction:column;gap:11px;flex:1;min-width:270px}
.row{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.row>span{width:74px;color:var(--mute);font-size:13px}
button{font:inherit;font-size:13px;padding:5px 11px;border-radius:999px;border:1px solid var(--line);background:#fff;color:var(--ink);cursor:pointer;display:inline-flex;align-items:center;gap:6px}
button[aria-pressed=true]{background:var(--ink);color:#fff;border-color:var(--ink)}
button:disabled{opacity:.45;cursor:not-allowed}
button:focus-visible{outline:2px solid #3b6fd8;outline-offset:2px}
.chip{width:12px;height:12px;border-radius:50%;border:1px solid rgba(0,0,0,.25)}
.note{font-size:13px;color:var(--mute);margin:0}
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin:14px 0}
.stat{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:8px 10px}
.stat b{display:block;font-size:17px;font-variant-numeric:tabular-nums}
.stat small{color:var(--mute);font-size:12px}
h2{font-size:15px;margin:18px 0 8px;font-weight:600}
#grid{width:100%;image-rendering:pixelated;background:var(--panel);border:1px solid var(--line);border-radius:14px}
@media (max-width:560px){.stats{grid-template-columns:repeat(2,1fr)}}
</style></head><body><main>
<h1>Animated variants</h1>
<p class="sub">Locked idle and flex running on the layered variants. Body patches (breath shading, blink, grin, flex arm) apply under the hair, then the rig moves every layer together.</p>
<div class="stage">
 <canvas id="hero" class="checker" width="64" height="128" aria-label="Animated character"></canvas>
 <div class="side">
  <div class="row" id="gender"><span>Character</span></div>
  <div class="row" id="style"><span>Hairstyle</span></div>
  <div class="row" id="hair"><span>Hair color</span></div>
  <div class="row" id="skin"><span>Skin tone</span></div>
  <div class="row" id="anim"><span>Animation</span></div>
  <div class="row" id="speed"><span>Speed</span></div>
  <div class="row" id="chan"><span>Layers</span></div>
  <p class="note" id="note"></p>
 </div>
</div>
<div class="stats">
 <div class="stat"><b id="sData">0 KB</b><small>source data</small></div>
 <div class="stat"><b id="sPose">0</b><small>poses composited</small></div>
 <div class="stat"><b id="sTex">0</b><small>colored frames cached</small></div>
 <div class="stat"><b id="sFps">12</b><small>ticks per second</small></div>
</div>
<h2 id="gridTitle"></h2>
<canvas id="grid"></canvas>
</main>
<script>
const D=__DATA__, W=64, H=128;
const TIP=11, NECK=27, WAIST=53, SEAM=75; // rig rows in cell coordinates
const CH="123456789abcdefgh";
const STYLES={male:{buzz:"Buzz",medium:"Medium",wolf:"Wolf cut"},female:{blunt:"Blunt bob",long:"Long flowy",ponytail:"Warrior ponytail"}};
const HAIR_IDX=[13,14,15,16,17], SKIN_IDX=[10,11,6,7,8]; // dark to light
const HAIR={Black:["#16171f","#1f212b","#2c2f3c","#3f4456","#5d6680"],Brown:["#2a1810","#472a1a","#6b4127","#8f5d38","#b3804f"],
 Blonde:["#5a3f1e","#8a6a30","#b8954a","#dcc070","#f3e2a0"],Auburn:["#3a1410","#62211a","#8e3524","#b84e30","#d9744a"],
 Silver:["#3c4150","#626a7c","#8d95a6","#b8bfcb","#e2e6ec"]};
const SKIN={Fair:["#946451","#c08a6c","#deac8c","#f2cbae","#fbe0c8"],Light:["#8d6050","#b77f63","#d69b75","#eab58d","#f5c69d"],
 Tan:["#6a4029","#8c5a38","#ad744a","#c98e60","#e0a878"],Brown:["#472816","#633c22","#80502f","#9c6440","#b87a50"],
 Deep:["#28150c","#3b2013","#4e2d1b","#633b25","#7a4a30"]};
const hex=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));

// Decode layers to index grids once
const LAY={};
for(const [n,rows] of Object.entries(D.layers)){const g=new Uint8Array(W*H);
  for(const [y,s] of Object.entries(rows)) for(let x=0;x<W;x++){const c=s[x]; if(c!==".") g[y*W+x]=CH.indexOf(c)+1;}
  LAY[n]=g;}
const MALE=D.male, ERASED=new Set(MALE.erase.map(([x,y])=>y*W+x));

// Stage 1: pose -> index grid (shared by all colorways)
const poseCache=new Map();
function poseIdx(g,st,p){
  const key=[g,st,p.k,p.c,p.h,p.a,p.o,p.f,p.g,p.l,p.s,p.b].join("|");
  let r=poseCache.get(key); if(r) return r;
  const body=LAY[g+"_body_bald"].slice();
  if(g==="male"){
    if(p.k>0) for(const [x,y,v] of MALE.deltas[p.k-1]) if(!(p.a&&ERASED.has(y*W+x))) body[y*W+x]=v;
    if(p.a){for(const i of ERASED) body[i]=0; for(const [x,y,v] of MALE.arms[p.a]) body[y*W+x]=v;}
    if(p.f) for(const [x,y,v] of MALE.grin) body[y*W+x]=v;
  }
  if(p.b) for(const [x,y,v] of D[g].eye[p.b===1?"half":"closed"]) body[y*W+x]=v;
  const idx=new Uint8Array(W*H);
  const back=LAY[`${g}_hair_${st}_back`], front=LAY[`${g}_hair_${st}_front`];
  for(const L of [back,body,front]) if(L) for(let i=0;i<W*H;i++) if(L[i]) idx[i]=L[i];
  if(p.g) for(const [x,y,v] of MALE.glint) idx[y*W+x]=v;
  // Row remap: legs fixed, body bounce o, torso breath c, head dip h, hair tips lag l
  const src=new Int16Array(H).fill(-1);
  for(const [a,b,o] of [[SEAM,H,0],[WAIST,SEAM,p.o],[NECK,WAIST,p.o+p.c],[TIP,NECK,p.o+p.h],[0,TIP,p.o+p.h-p.l]])
    for(let s=a;s<b;s++){const d=s-o; if(d>=0&&d<H) src[d]=s;}
  let top=0; while(top<H&&src[top]<0) top++;
  for(let d=H-2;d>=top;d--) if(src[d]<0) src[d]=src[d+1];
  r=new Uint8Array(W*H);
  for(let d=0;d<H;d++){const s=src[d]; if(s<0) continue; const sh=s<TIP?p.s:0;
    for(let x=0;x<W;x++){const sx=x-sh; if(sx>=0&&sx<W) r[d*W+x]=idx[s*W+sx];}}
  poseCache.set(key,r); return r;
}
// Stage 2: index grid + ramps -> canvas (LRU-capped)
const texCache=new Map(), TEX_CAP=900;
function frame(g,st,hc,sk,p){
  const key=[g,st,hc,sk,p.k,p.c,p.h,p.a,p.o,p.f,p.g,p.l,p.s,p.b].join("|");
  let cv=texCache.get(key); if(cv){texCache.delete(key);texCache.set(key,cv);return cv;}
  const pal=D.pal.map(hex);
  HAIR_IDX.forEach((i,j)=>pal[i-1]=hex(HAIR[hc][j])); SKIN_IDX.forEach((i,j)=>pal[i-1]=hex(SKIN[sk][j]));
  const idx=poseIdx(g,st,p);
  cv=document.createElement("canvas"); cv.width=W; cv.height=H;
  const cx=cv.getContext("2d"), im=cx.createImageData(W,H), o=im.data;
  for(let i=0;i<W*H;i++){const v=idx[i]; if(!v) continue; const c=pal[v-1]; o[i*4]=c[0];o[i*4+1]=c[1];o[i*4+2]=c[2];o[i*4+3]=255;}
  cx.putImageData(im,0,0); texCache.set(key,cv);
  if(texCache.size>TEX_CAP) texCache.delete(texCache.keys().next().value);
  return cv;
}

// Animation clocks (locked rules)
const R=(a,b)=>a+Math.floor(Math.random()*(b-a+1));
const REST={k:0,c:0,h:0,a:"",o:0,f:"",g:0,l:0};
function breathSteps(){const deep=Math.random()<.2;
  return [[{k:0,c:0,h:0},R(8,16)],[{k:1,c:0,h:0},1],[{k:1,c:1,h:0},2],[{k:2,c:1,h:0},deep?R(12,16):R(6,9)],
          [{k:1,c:1,h:0},2],[{k:1,c:0,h:-1,l:-1},1],[{k:0,c:0,h:-1,l:0},R(3,5)],[{k:0,c:0,h:0,l:1},1]];}
const FLEX=[[{a:"",o:-1},3],[{a:"raise",o:0,l:1},1],[{a:"flex",o:2,f:"grin",l:1},2],[{a:"flex",o:1,f:"grin"},3],
 [{a:"pump",o:1,f:"grin"},3],[{a:"flex",o:1,f:"grin"},2],[{a:"pump",o:1,f:"grin",g:1},5],[{a:"flex",o:1,f:"grin"},3],
 [{a:"pump",o:1,f:"grin"},3],[{a:"flex",o:1,f:"grin"},10],[{a:"raise",o:0,l:-1},1],[{a:"",o:-1,l:-1},2]];
const G={anim:"flex",blink:true,hair:true,speed:1};
class Actor{
  constructor(){this.idle();this.idleLeft=R(10,40);this.blinkIn=R(10,60);this.blinkSeq=[];this.sway=0;this.swayHold=R(6,48);this.p={...REST,s:0,b:0};}
  idle(){this.seq=breathSteps();this.si=0;this.st=0;}
  step(canFlex){
    const [q,n]=this.seq[this.si]; const p={...REST,...q};
    if(++this.st>=n){this.st=0;this.si++;
      if(this.si>=this.seq.length){
        if(this.seq===FLEX){this.idle();this.idleLeft=R(30,48);}
        else if(G.anim==="flex"&&canFlex&&this.idleLeft<=0){this.seq=FLEX;this.si=0;}
        else this.idle();}}
    if(this.seq!==FLEX) this.idleLeft--;
    let b=0;
    if(G.blink&&!p.f){ if(this.blinkSeq.length) b=this.blinkSeq.shift();
      else if(--this.blinkIn<=0){this.blinkIn=R(30,72);this.blinkSeq=[2,2,1];if(Math.random()<.15)this.blinkSeq.push(0,0,1,2,1);b=1;} }
    let s=0;
    if(G.hair){ if(--this.swayHold<=0){ if(this.sway!==0){this.sway=0;this.swayHold=R(6,14);} else {this.sway=Math.random()<.5?-1:1;this.swayHold=R(8,20);} } s=this.sway; }
    this.p={...p,s,b};
  }
}

// UI
const S={g:"male",st:"wolf",hc:"Black",sk:"Light"};
function radio(id,opts,get,set,extra={}){
  const row=document.getElementById(id); row.querySelectorAll("button").forEach(b=>b.remove());
  for(const [v,label] of opts){const b=document.createElement("button");
    if(extra.chip){const c=document.createElement("i");c.className="chip";c.style.background=extra.chip(v);b.append(c);}
    b.append(label); b.setAttribute("aria-pressed",v===get()); if(extra.disabled&&extra.disabled(v)) b.disabled=true;
    b.onclick=()=>{set(v);ui();buildGrid();}; row.append(b);}
}
function ui(){
  radio("gender",[["male","Male"],["female","Female"]],()=>S.g,v=>{S.g=v;S.st=Object.keys(STYLES[v])[v==="male"?2:1];});
  radio("style",[["bald","Bald"],...Object.entries(STYLES[S.g])],()=>S.st,v=>S.st=v);
  radio("hair",Object.keys(HAIR).map(h=>[h,h]),()=>S.hc,v=>S.hc=v,{chip:v=>HAIR[v][3]});
  radio("skin",Object.keys(SKIN).map(h=>[h,h]),()=>S.sk,v=>S.sk=v,{chip:v=>SKIN[v][3]});
  radio("anim",[["idle","Idle"],["flex","Flex"]],()=>G.anim,v=>G.anim=v,{disabled:v=>v==="flex"&&S.g==="female"});
  radio("speed",[["0.5","0.5x"],["1","1x"],["2","2x"]],()=>String(G.speed),v=>G.speed=+v);
  const chan=document.getElementById("chan"); chan.querySelectorAll("button").forEach(b=>b.remove());
  for(const [k,l] of [["blink","Blink"],["hair","Hair"]]){const b=document.createElement("button");b.textContent=l;
    b.setAttribute("aria-pressed",G[k]);b.onclick=()=>{G[k]=!G[k];ui();};chan.append(b);}
  document.getElementById("note").textContent=S.g==="female"?"Female flex needs its own arm drawing, so she runs idle only for now.":"";
}
const hero=new Actor(), hx=document.getElementById("hero").getContext("2d");
const grid=document.getElementById("grid"), gx=grid.getContext("2d");
const CX=12,CY=4,CW=50,CHh=58,COLS=5; let cells=[];
function buildGrid(){
  const styles=Object.keys(STYLES[S.g]); cells=[];
  for(const st of styles) for(const hc of Object.keys(HAIR)) cells.push({st,hc,a:new Actor()});
  grid.width=COLS*CW; grid.height=Math.ceil(cells.length/COLS)*CHh;
  document.getElementById("gridTitle").textContent=`${cells.length} ${S.g} variants at ${S.sk} skin, animating independently`;
}
function draw(){
  const canFlex=S.g==="male";
  hx.clearRect(0,0,W,H); hx.drawImage(frame(S.g,S.st,S.hc,S.sk,hero.p),0,0);
  gx.clearRect(0,0,grid.width,grid.height);
  cells.forEach((c,i)=>gx.drawImage(frame(S.g,c.st,c.hc,S.sk,c.a.p),CX,CY,CW,CHh,(i%COLS)*CW,Math.floor(i/COLS)*CHh,CW,CHh));
  sPose.textContent=poseCache.size; sTex.textContent=texCache.size; sFps.textContent=reduce?0:12*G.speed;
}
function tick(){const canFlex=S.g==="male"; hero.step(canFlex); cells.forEach(c=>c.a.step(canFlex)); draw();}
sData.textContent=(JSON.stringify(D).length/1024).toFixed(1)+" KB";
const reduce=matchMedia("(prefers-reduced-motion: reduce)").matches;
let last=0,raf=0;
function loop(t){ if(t-last>=1000/(12*G.speed)){last=t;tick();} raf=requestAnimationFrame(loop); }
document.addEventListener("visibilitychange",()=>{ if(document.hidden) cancelAnimationFrame(raf); else if(!reduce) raf=requestAnimationFrame(loop); });
ui(); buildGrid(); draw(); if(!reduce) raf=requestAnimationFrame(loop);
window.__poseIdx=poseIdx; window.__frame=frame;
</script></body></html>"""
open('/mnt/user-data/outputs/animated_variants.html','w').write(html.replace('__DATA__',data))
