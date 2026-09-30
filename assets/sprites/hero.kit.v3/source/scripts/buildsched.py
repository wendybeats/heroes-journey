data=open('sched_data.json').read()
html=r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Hoodie idle scheduler</title>
<style>
:root{--bg:#dde2e8;--panel:#f6f7f9;--ink:#1a2130;--mute:#5b6576;--line:#c5ccd6}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.45 ui-sans-serif,system-ui,-apple-system,"SF Pro Text",sans-serif}
main{max-width:820px;margin:0 auto;padding:20px 16px 40px}
h1{font-size:22px;margin:0 0 4px;font-weight:650;letter-spacing:-.01em}
p.sub{margin:0 0 18px;color:var(--mute);max-width:66ch}
.stage{display:flex;gap:18px;align-items:flex-start;flex-wrap:wrap;background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:16px}
.checker{background:repeating-conic-gradient(#e7eaee 0 25%,#f6f7f9 0 50%) 0 0/18px 18px;border-radius:8px;image-rendering:pixelated}
#hero{width:192px;height:384px}
.side{display:flex;flex-direction:column;gap:11px;flex:1;min-width:260px}
.row{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.row>span{width:74px;color:var(--mute);font-size:13px}
button{font:inherit;font-size:13px;padding:5px 11px;border-radius:999px;border:1px solid var(--line);background:#fff;color:var(--ink);cursor:pointer;display:inline-flex;align-items:center;gap:6px}
button[aria-pressed=true]{background:var(--ink);color:#fff;border-color:var(--ink)}
button:focus-visible{outline:2px solid #3b6fd8;outline-offset:2px}
.chip{width:12px;height:12px;border-radius:50%;border:1px solid rgba(0,0,0,.25)}
.timers{display:grid;grid-template-columns:repeat(2,1fr);gap:8px}
.stat{background:#fff;border:1px solid var(--line);border-radius:10px;padding:8px 10px}
.stat b{display:block;font-size:17px;font-variant-numeric:tabular-nums}
.stat small{color:var(--mute);font-size:12px}
h2{font-size:15px;margin:18px 0 8px;font-weight:600}
#log{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:10px 14px;font:13px/1.6 ui-monospace,SFMono-Regular,Menlo,monospace;color:var(--mute);height:170px;overflow:auto;margin:0}
</style></head><body><main>
<h1>Hoodie idle scheduler</h1>
<p class="sub">Glances every 3–5 s, hands out every 8–12 s for 3 s, blinks during holds. Clips never overlap. This is the same logic as the Swift scheduler, reading the same clip JSON.</p>
<div class="stage">
 <canvas id="hero" class="checker" width="64" height="128" aria-label="Animated character"></canvas>
 <div class="side">
  <div class="timers">
   <div class="stat"><b id="tState">out</b><small>hands</small></div>
   <div class="stat"><b id="tClip">idle</b><small>playing</small></div>
   <div class="stat"><b id="tGlance">0.0 s</b><small>next glance</small></div>
   <div class="stat"><b id="tHands">0.0 s</b><small>next hands change</small></div>
  </div>
  <div class="row" id="hair"><span>Hair color</span></div>
  <div class="row" id="skin"><span>Skin tone</span></div>
  <div class="row" id="speed"><span>Speed</span></div>
 </div>
</div>
<h2>Event log</h2>
<pre id="log"></pre>
</main>
<script>
const D=__DATA__, IMG=D.imgs, CFG=D.clips, W=64, H=128, NECK=27, SEAM=75, TOPHAIR=15, TR=CFG.tickRate;
const HAIR_KEY=["#0e2a12","#1d4a24","#2f6e37","#4a9652","#74c07a"], SKIN_KEY=["#8d6050","#b77f63","#d69b75","#eab58d","#f5c69d"];
const HAIR={Black:["#16171f","#1f212b","#2c2f3c","#3f4456","#5d6680"],Brown:["#2a1810","#472a1a","#6b4127","#8f5d38","#b3804f"],
 Blonde:["#5a3f1e","#8a6a30","#b8954a","#dcc070","#f3e2a0"],Auburn:["#3a1410","#62211a","#8e3524","#b84e30","#d9744a"],
 Silver:["#3c4150","#626a7c","#8d95a6","#b8bfcb","#e2e6ec"]};
const SKIN={Fair:["#946451","#c08a6c","#deac8c","#f2cbae","#fbe0c8"],Light:["#8d6050","#b77f63","#d69b75","#eab58d","#f5c69d"],
 Tan:["#6a4029","#8c5a38","#ad744a","#c98e60","#e0a878"],Brown:["#472816","#633c22","#80502f","#9c6440","#b87a50"],
 Deep:["#28150c","#3b2013","#4e2d1b","#633b25","#7a4a30"]};
const hex=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16)), pk=c=>(c[0]<<16)|(c[1]<<8)|c[2];
const EYE={1:[[31,21,"#f5c69d"]],2:[[32,20,"#f5c69d"],[31,21,"#101118"],[32,21,"#101118"]]};
const L={};
function load(){return Promise.all(Object.entries(IMG).map(([k,s])=>new Promise(r=>{const im=new Image();im.onload=()=>{
  const c=document.createElement("canvas");c.width=W;c.height=H;const x=c.getContext("2d");x.drawImage(im,0,0);L[k]=x.getImageData(0,0,W,H).data;r();};im.src=s;})));}
// ---- compositor: body rows >= NECK from frame f, head rows < NECK from N/L/R head ----
const cache=new Map();
function frame(p,hc,sk){
  const key=[p.f,p.head,p.o,p.s,p.b,hc,sk].join("|"); let cv=cache.get(key); if(cv) return cv;
  const map=new Map(); HAIR_KEY.forEach((h,i)=>map.set(pk(hex(h)),hex(HAIR[hc][i]))); SKIN_KEY.forEach((h,i)=>map.set(pk(hex(h)),hex(SKIN[sk][i])));
  const headSrc=p.head==="L"?L.b3:p.head==="R"?L.b4:L.b2, bodySrc=L["b"+p.f], hair=p.head==="L"?L.hL:p.head==="R"?L.hR:L.hN;
  const px=new Uint8ClampedArray(W*H*4);
  for(let y=0;y<H;y++){const src=y<NECK?headSrc:bodySrc; for(let x=0;x<W;x++){const i=(y*W+x)*4; if(src[i+3]){px[i]=src[i];px[i+1]=src[i+1];px[i+2]=src[i+2];px[i+3]=255;}}}
  if(p.b&&p.head==="N") for(const [x,y,h] of EYE[p.b]){const c=hex(h),i=(y*W+x)*4;px[i]=c[0];px[i+1]=c[1];px[i+2]=c[2];px[i+3]=255;}
  for(let y=0;y<H;y++) for(let x=0;x<W;x++){const sx=y<TOPHAIR?x-p.s:x; if(sx<0||sx>=W) continue; const j=(y*W+sx)*4,i=(y*W+x)*4;
    if(hair[j+3]){px[i]=hair[j];px[i+1]=hair[j+1];px[i+2]=hair[j+2];px[i+3]=255;}}
  const out=new Uint8ClampedArray(W*H*4);
  for(let d=0;d<H;d++){let s=d<SEAM?d+p.o:d; if(p.o>0&&d>=SEAM-p.o&&d<SEAM) s=SEAM; if(s<0||s>=H) continue; out.set(px.subarray(s*W*4,(s+1)*W*4),d*W*4);}
  for(let i=0;i<out.length;i+=4){if(!out[i+3]) continue; const m=map.get(pk([out[i],out[i+1],out[i+2]])); if(m){out[i]=m[0];out[i+1]=m[1];out[i+2]=m[2];}}
  cv=document.createElement("canvas");cv.width=W;cv.height=H;cv.getContext("2d").putImageData(new ImageData(out,W,H),0,0);
  cache.set(key,cv); return cv;
}
// ---- scheduler (mirrors IdleScheduler.swift) ----
const SC=CFG.schedule, rnd=(a,b)=>a+Math.random()*(b-a), rint=(a,b)=>a+Math.floor(Math.random()*(b-a+1));
const expand=name=>CFG.clips[name].flatMap(([p,n])=>{const k=typeof n==="number"?n:rint(n.min,n.max);return Array(k).fill(p);});
let hands=SC.startState, clip=null, clipName="idle", ci=0, lastDir=Math.random()<.5?"Left":"Right";
let glanceT=rnd(...SC.glanceEverySec), handsT=SC.firstEnterAfterSec, blinkT=rnd(...SC.blinkEverySec);
const logEl=document.getElementById("log"); let simT=0;
const log=m=>{logEl.textContent=`${simT.toFixed(1).padStart(6)} s  ${m}\n`+logEl.textContent;};
function play(name){clip=expand(name);ci=0;clipName=name;}
function tick(){
  const dt=1/TR; simT+=dt; glanceT-=dt; handsT-=dt; blinkT-=dt;
  if(clip&&ci>=clip.length){                       // clip finished
    if(clipName==="enter"){hands="in";handsT=rnd(...SC.handsInForSec);glanceT=Math.max(glanceT,SC.settleAfterHandsSec);}
    if(clipName==="exit"){hands="out";handsT=rnd(...SC.handsOutForSec);glanceT=Math.max(glanceT,SC.settleAfterHandsSec);}
    clip=null;clipName="idle";
  }
  if(!clip){
    if(handsT<=0){ play(hands==="in"?"exit":"enter"); log(hands==="in"?"hands out":"hands in"); }
    else if(glanceT<=0){ const dir=Math.random()<SC.glanceAlternateChance?(lastDir==="Left"?"Right":"Left"):lastDir;
      lastDir=dir; play("glance"+dir); glanceT=rnd(...SC.glanceEverySec); log("glance "+dir.toLowerCase()); }
    else if(blinkT<=0){ play(Math.random()<SC.doubleBlinkChance?"doubleBlink":"blink"); blinkT=rnd(...SC.blinkEverySec); }
  }
  // base pose from the hands state AFTER any finished clip has updated it
  const base={f:hands==="in"?2:0,head:"N",o:0,s:0,b:0};
  let p=base;
  if(clip){ p={...base,...clip[ci]}; if(clipName.startsWith("enter")||clipName.startsWith("exit")) p.f=clip[ci].f??base.f; ci++; }
  return p;
}
// ---- UI ----
const S={hc:"Black",sk:"Light",speed:1};
function radio(id,opts,get,set,chip){const row=document.getElementById(id);row.querySelectorAll("button").forEach(b=>b.remove());
  for(const [v,l] of opts){const b=document.createElement("button");if(chip){const c=document.createElement("i");c.className="chip";c.style.background=chip(v);b.append(c);}
    b.append(l);b.setAttribute("aria-pressed",v===get());b.onclick=()=>{set(v);ui();};row.append(b);}}
function ui(){radio("hair",Object.keys(HAIR).map(k=>[k,k]),()=>S.hc,v=>S.hc=v,v=>HAIR[v][3]);
  radio("skin",Object.keys(SKIN).map(k=>[k,k]),()=>S.sk,v=>S.sk=v,v=>SKIN[v][3]);
  radio("speed",[["0.5","0.5x"],["1","1x"],["2","2x"]],()=>String(S.speed),v=>S.speed=+v);}
const hx=document.getElementById("hero").getContext("2d"); hx.imageSmoothingEnabled=false;
function draw(p){hx.clearRect(0,0,W,H);hx.drawImage(frame(p,S.hc,S.sk),0,0);
  tState.textContent=hands; tClip.textContent=clipName; tGlance.textContent=Math.max(0,glanceT).toFixed(1)+" s"; tHands.textContent=Math.max(0,handsT).toFixed(1)+" s";}
const reduce=matchMedia("(prefers-reduced-motion: reduce)").matches; let last=0,raf=0;
function loop(t){if(t-last>=1000/(TR*S.speed)){last=t;draw(tick());}raf=requestAnimationFrame(loop);}
document.addEventListener("visibilitychange",()=>{if(document.hidden)cancelAnimationFrame(raf);else if(!reduce)raf=requestAnimationFrame(loop);});
load().then(()=>{ui();draw({f:0,head:"N",o:0,s:0,b:0});if(!reduce)raf=requestAnimationFrame(loop);window.__tick=tick;window.__state=()=>({hands,clipName});});
</script></body></html>"""
open('/mnt/user-data/outputs/hoodie-test/hoodie_idle_scheduler.html','w').write(html.replace('__DATA__',data))
