data=open('all_data.json').read()
html=r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Hoodie outfit: all variants</title>
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
button:focus-visible{outline:2px solid #3b6fd8;outline-offset:2px}
.chip{width:12px;height:12px;border-radius:50%;border:1px solid rgba(0,0,0,.25)}
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin:14px 0}
.stat{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:8px 10px}
.stat b{display:block;font-size:17px;font-variant-numeric:tabular-nums}
.stat small{color:var(--mute);font-size:12px}
h2{font-size:15px;margin:18px 0 8px;font-weight:600}
#grid{width:100%;image-rendering:pixelated;background:var(--panel);border:1px solid var(--line);border-radius:14px}
@media (max-width:560px){.stats{grid-template-columns:repeat(2,1fr)}}
</style></head><body><main>
<h1>Hoodie outfit: all variants</h1>
<p class="sub">Every hairstyle, hair color and skin tone on the hoodie idle: glances every 3–5 s, hands out every 8–12 s for 3 s, blinks during holds and sometimes mid-glance. Each character in the grid runs its own scheduler.</p>
<div class="stage">
 <canvas id="hero" class="checker" width="64" height="128" aria-label="Animated character"></canvas>
 <div class="side">
  <div class="row" id="gender"><span>Character</span></div>
  <div class="row" id="style"><span>Hairstyle</span></div>
  <div class="row" id="hair"><span>Hair color</span></div>
  <div class="row" id="skin"><span>Skin tone</span></div>
  <div class="row" id="speed"><span>Speed</span></div>
 </div>
</div>
<div class="stats">
 <div class="stat"><b id="sData">0 KB</b><small>source images</small></div>
 <div class="stat"><b id="sPose">0</b><small>poses composited</small></div>
 <div class="stat"><b id="sTex">0</b><small>colored frames cached</small></div>
 <div class="stat"><b id="sClip">idle</b><small>preview playing</small></div>
</div>
<h2 id="gridTitle"></h2>
<canvas id="grid"></canvas>
</main>
<script>
const D=__DATA__, IMG=D.imgs, CFG=D.clips, SC=CFG.schedule, TR=CFG.tickRate, W=64, H=128, NECK=27, SEAM=75, TOPHAIR=15;
const LABEL={buzz:"Buzz",medium:"Medium",wolf:"Wolf cut",blunt:"Blunt bob",long:"Long flowy",ponytail:"Warrior ponytail"};
const HAIR_KEY=["#0e2a12","#1d4a24","#2f6e37","#4a9652","#74c07a"], SKIN_KEY=["#8d6050","#b77f63","#d69b75","#eab58d","#f5c69d"];
const HAIR={Black:["#16171f","#1f212b","#2c2f3c","#3f4456","#5d6680"],Brown:["#2a1810","#472a1a","#6b4127","#8f5d38","#b3804f"],
 Blonde:["#5a3f1e","#8a6a30","#b8954a","#dcc070","#f3e2a0"],Auburn:["#3a1410","#62211a","#8e3524","#b84e30","#d9744a"],
 Silver:["#3c4150","#626a7c","#8d95a6","#b8bfcb","#e2e6ec"]};
const SKIN={Fair:["#946451","#c08a6c","#deac8c","#f2cbae","#fbe0c8"],Light:["#8d6050","#b77f63","#d69b75","#eab58d","#f5c69d"],
 Tan:["#6a4029","#8c5a38","#ad744a","#c98e60","#e0a878"],Brown:["#472816","#633c22","#80502f","#9c6440","#b87a50"],
 Deep:["#28150c","#3b2013","#4e2d1b","#633b25","#7a4a30"]};
const hex=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16)), pk=c=>(c[0]<<16)|(c[1]<<8)|c[2];
const L={};
function load(){return Promise.all(Object.entries(IMG).map(([k,s])=>new Promise(r=>{const im=new Image();im.onload=()=>{
  const c=document.createElement("canvas");c.width=W;c.height=H;const x=c.getContext("2d");x.drawImage(im,0,0);L[k]=x.getImageData(0,0,W,H).data;r();};im.src=s;})));}
// Stage 1: uncolored composite per (gender, style, pose)
const poseCache=new Map();
function composite(g,st,p){
  const key=[g,st,p.f,p.head,p.o,p.s,p.b].join("|"); let r=poseCache.get(key); if(r) return r;
  const px=new Uint8ClampedArray(W*H*4);
  const blit=(src,rowOK,shift)=>{ if(!src) return; for(let y=0;y<H;y++){ if(!rowOK(y)) continue; const sh=shift&&y<TOPHAIR?p.s:0;
    for(let x=0;x<W;x++){const sx=x-sh; if(sx<0||sx>=W) continue; const j=(y*W+sx)*4; if(!src[j+3]) continue; const i=(y*W+x)*4;
      px[i]=src[j];px[i+1]=src[j+1];px[i+2]=src[j+2];px[i+3]=255;}}};
  const hairF=st==="bald"?null:L[`${g}_${st}_front_${p.head}`], hairB=st==="bald"?null:L[`${g}_${st}_back_${p.head}`];
  blit(hairB,()=>true,true);
  blit(p.head==="N"?L[`${g}_b${p.f}`]:L[`${g}_head${p.head}`],y=>y<NECK,false);
  blit(L[`${g}_b${p.f}`],y=>y>=NECK,false);
  if(p.b) for(const [x,y,h] of D.eyes[g][p.head][p.b]){const c=hex(h),i=(y*W+x)*4;px[i]=c[0];px[i+1]=c[1];px[i+2]=c[2];px[i+3]=255;}
  blit(hairF,()=>true,true);
  r=new Uint8ClampedArray(W*H*4);
  for(let d=0;d<H;d++){let s=d<SEAM?d+p.o:d; if(p.o>0&&d>=SEAM-p.o&&d<SEAM) s=SEAM; if(s<0||s>=H) continue; r.set(px.subarray(s*W*4,(s+1)*W*4),d*W*4);}
  poseCache.set(key,r); return r;
}
// Stage 2: palette swap to canvas (LRU-capped)
const tex=new Map(), CAP=900;
function frame(g,st,hc,sk,p){
  const key=[g,st,hc,sk,p.f,p.head,p.o,p.s,p.b].join("|"); let cv=tex.get(key); if(cv){tex.delete(key);tex.set(key,cv);return cv;}
  const map=new Map(); HAIR_KEY.forEach((h,i)=>map.set(pk(hex(h)),hex(HAIR[hc][i]))); SKIN_KEY.forEach((h,i)=>map.set(pk(hex(h)),hex(SKIN[sk][i])));
  const out=composite(g,st,p).slice();
  for(let i=0;i<out.length;i+=4){if(!out[i+3]) continue; const m=map.get(pk([out[i],out[i+1],out[i+2]])); if(m){out[i]=m[0];out[i+1]=m[1];out[i+2]=m[2];}}
  cv=document.createElement("canvas");cv.width=W;cv.height=H;cv.getContext("2d").putImageData(new ImageData(out,W,H),0,0);
  tex.set(key,cv); if(tex.size>CAP) tex.delete(tex.keys().next().value); return cv;
}
// Scheduler (mirrors IdleScheduler.swift)
const rnd=(a,b)=>a+Math.random()*(b-a), rint=(a,b)=>a+Math.floor(Math.random()*(b-a+1));
const expand=n=>CFG.clips[n].flatMap(([p,k])=>Array(typeof k==="number"?k:rint(k.min,k.max)).fill(p));
class Actor{
  constructor(){this.hands=SC.startState;this.clip=null;this.name="idle";this.ci=0;this.lastLeft=Math.random()<.5;
    this.glanceT=rnd(...SC.glanceEverySec);this.handsT=SC.firstEnterAfterSec+Math.random()*2;this.blinkT=rnd(...SC.blinkEverySec);}
  play(n){this.clip=expand(n);this.ci=0;this.name=n;}
  tick(){ const dt=1/TR; this.glanceT-=dt;this.handsT-=dt;this.blinkT-=dt;
    if(this.clip&&this.ci>=this.clip.length){
      if(this.name==="enter"){this.hands="in";this.handsT=rnd(...SC.handsInForSec);}
      if(this.name==="exit"){this.hands="out";this.handsT=rnd(...SC.handsOutForSec);}
      if(this.name==="enter"||this.name==="exit") this.glanceT=Math.max(this.glanceT,SC.settleAfterHandsSec);
      this.clip=null;this.name="idle";}
    if(!this.clip){
      if(this.handsT<=0) this.play(this.hands==="in"?"exit":"enter");
      else if(this.glanceT<=0){const left=Math.random()<SC.glanceAlternateChance?!this.lastLeft:this.lastLeft;this.lastLeft=left;
        this.play("glance"+(left?"Left":"Right")+(Math.random()<SC.glanceBlinkChance?"Blink":""));this.glanceT=rnd(...SC.glanceEverySec);}
      else if(this.blinkT<=0){this.play(Math.random()<SC.doubleBlinkChance?"doubleBlink":"blink");this.blinkT=rnd(...SC.blinkEverySec);}
    }
    const base={f:this.hands==="in"?2:0,head:"N",o:0,s:0,b:0};
    if(!this.clip) return base; const q=this.clip[this.ci++]; return {...base,...q};
  }
}
// UI
const S={g:"male",st:"medium",hc:"Black",sk:"Light",speed:1};
function radio(id,opts,get,set,chip){const row=document.getElementById(id);row.querySelectorAll("button").forEach(b=>b.remove());
  for(const [v,l] of opts){const b=document.createElement("button");if(chip){const c=document.createElement("i");c.className="chip";c.style.background=chip(v);b.append(c);}
    b.append(l);b.setAttribute("aria-pressed",v===get());b.onclick=()=>{set(v);ui();buildGrid();};row.append(b);}}
function ui(){
  radio("gender",[["male","Male"],["female","Female"]],()=>S.g,v=>{S.g=v;S.st=D.styles[v][1];});
  radio("style",[["bald","Bald"],...D.styles[S.g].map(s=>[s,LABEL[s]])],()=>S.st,v=>S.st=v);
  radio("hair",Object.keys(HAIR).map(k=>[k,k]),()=>S.hc,v=>S.hc=v,v=>HAIR[v][3]);
  radio("skin",Object.keys(SKIN).map(k=>[k,k]),()=>S.sk,v=>S.sk=v,v=>SKIN[v][3]);
  radio("speed",[["0.5","0.5x"],["1","1x"],["2","2x"]],()=>String(S.speed),v=>S.speed=+v);}
const hero=new Actor(), hx=document.getElementById("hero").getContext("2d");
const grid=document.getElementById("grid"), gx=grid.getContext("2d"), CX=12,CY=4,CW=40,CHh=58,COLS=5; let cells=[];
hx.imageSmoothingEnabled=gx.imageSmoothingEnabled=false;
function buildGrid(){cells=[];for(const st of D.styles[S.g]) for(const hc of Object.keys(HAIR)) cells.push({st,hc,a:new Actor(),p:{f:0,head:"N",o:0,s:0,b:0}});
  grid.width=COLS*CW;grid.height=Math.ceil(cells.length/COLS)*CHh;
  document.getElementById("gridTitle").textContent=`All ${cells.length} ${S.g} hairstyle and color variants at ${S.sk} skin`;}
let hp={f:0,head:"N",o:0,s:0,b:0};
function draw(){hx.clearRect(0,0,W,H);hx.drawImage(frame(S.g,S.st,S.hc,S.sk,hp),0,0);
  gx.clearRect(0,0,grid.width,grid.height);
  cells.forEach((c,i)=>gx.drawImage(frame(S.g,c.st,c.hc,S.sk,c.p),CX,CY,CW,CHh,(i%COLS)*CW,Math.floor(i/COLS)*CHh,CW,CHh));
  sPose.textContent=poseCache.size;sTex.textContent=tex.size;sClip.textContent=hero.name;}
function tick(){hp=hero.tick();cells.forEach(c=>c.p=c.a.tick());draw();}
sData.textContent=(JSON.stringify(IMG).length/1024).toFixed(0)+" KB";
const reduce=matchMedia("(prefers-reduced-motion: reduce)").matches; let last=0,raf=0;
function loop(t){if(t-last>=1000/(TR*S.speed)){last=t;tick();}raf=requestAnimationFrame(loop);}
document.addEventListener("visibilitychange",()=>{if(document.hidden)cancelAnimationFrame(raf);else if(!reduce)raf=requestAnimationFrame(loop);});
load().then(()=>{ui();buildGrid();draw();if(!reduce)raf=requestAnimationFrame(loop);window.__frame=frame;window.__Actor=Actor;});
</script></body></html>"""
open('/mnt/user-data/outputs/hoodie_all_variants.html','w').write(html.replace('__DATA__',data))
