data=open('hero3.json').read()
html=r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Idle and flex test</title>
<style>
:root{--bg:#dde2e8;--panel:#f6f7f9;--ink:#1a2130;--mute:#5b6576;--line:#c5ccd6}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.45 ui-sans-serif,system-ui,-apple-system,"SF Pro Text",sans-serif}
main{max-width:780px;margin:0 auto;padding:20px 16px 40px}
h1{font-size:22px;margin:0 0 4px;font-weight:650;letter-spacing:-.01em}
p.sub{margin:0 0 18px;color:var(--mute);max-width:64ch}
.stage{display:flex;gap:16px;align-items:flex-start;flex-wrap:wrap;background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:16px}
.checker{background:repeating-conic-gradient(#e7eaee 0 25%,#f6f7f9 0 50%) 0 0/18px 18px;border-radius:8px;image-rendering:pixelated}
#hero{width:156px;height:357px}
#zoom{width:216px;height:216px}
.side{display:flex;flex-direction:column;gap:12px;flex:1;min-width:240px}
.row{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.row span{width:64px;color:var(--mute);font-size:13px}
button{font:inherit;font-size:13px;padding:5px 11px;border-radius:999px;border:1px solid var(--line);background:#fff;color:var(--ink);cursor:pointer}
button[aria-pressed=true]{background:var(--ink);color:#fff;border-color:var(--ink)}
button:focus-visible{outline:2px solid #3b6fd8;outline-offset:2px}
.state{font-size:13px;color:var(--mute);font-variant-numeric:tabular-nums;margin:0}
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin:14px 0}
.stat{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:8px 10px}
.stat b{display:block;font-size:17px;font-variant-numeric:tabular-nums}
.stat small{color:var(--mute);font-size:12px}
@media (max-width:560px){.stats{grid-template-columns:repeat(2,1fr)}}
</style></head><body><main>
<h1>Idle and flex</h1>
<p class="sub">Idle breathes by raising the torso and shoulders 1 px, then dipping the head 1 px on the exhale, with blinks and hair drift. Flex plays a snappy key-pose sequence: dip, smear, snap, pump, glint, release.</p>
<div class="stage">
 <canvas id="hero" class="checker" aria-label="Animated character"></canvas>
 <div class="side">
  <canvas id="zoom" class="checker" aria-label="Upper body close-up"></canvas>
  <div class="row" id="anim"><span>Animation</span>
   <button data-v="idle" aria-pressed="false">Idle</button>
   <button data-v="flex" aria-pressed="true">Flex</button></div>
  <div class="row" id="speed"><span>Speed</span>
   <button data-v="0.5" aria-pressed="false">0.5x</button>
   <button data-v="1" aria-pressed="true">1x</button>
   <button data-v="2" aria-pressed="false">2x</button></div>
  <div class="row" id="chan"><span>Layers</span>
   <button data-v="blink" aria-pressed="true">Blink</button>
   <button data-v="hair" aria-pressed="true">Hair</button></div>
  <p class="state" id="state"></p>
 </div>
</div>
<div class="stats">
 <div class="stat"><b id="sData">0 KB</b><small>source data</small></div>
 <div class="stat"><b id="sCache">0</b><small>cached poses</small></div>
 <div class="stat"><b id="sComp">0</b><small>composites run</small></div>
 <div class="stat"><b id="sFps">12</b><small>ticks per second</small></div>
</div>
</main>
<script>
const D=__DATA__, W=D.w, H=D.h;
const TIP=6, NECK=22, WAIST=48, SEAM=70; // hair tips; breath band NECK..WAIST; rows above SEAM move with the body
const EYE={half:[[18,16,8]], closed:[[19,15,8],[18,16,1],[19,16,1]]};
const CH="123456789abcdefghijklmnopqrstuvwxyz";
const PAL=D.palette.map(h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16)));
const dec=c=>c==="."?0:CH.indexOf(c)+1;
const base=new Uint8Array(W*H);
D.base.forEach((row,y)=>{for(let x=0;x<W;x++)base[y*W+x]=dec(row[x]);});
const erased=new Set(D.erase.map(([x,y])=>y*W+x));

const cache=new Map(); let composites=0;
// p: k keyframe, c torso breath rise, h head offset (negative = down), a arm, o body offset, f face, g glint, l hair lag, s sway, b blink
function pose(p){
  const key=[p.k,p.c,p.h,p.a,p.o,p.f,p.g,p.l,p.s,p.b].join("|"); let cv=cache.get(key); if(cv) return cv;
  composites++;
  const idx=base.slice();
  if(p.k>0) for(const [x,y,ch] of D.deltas[p.k-1]) if(!(p.a&&erased.has(y*W+x))) idx[y*W+x]=dec(ch);
  if(p.a){ for(const i of erased) idx[i]=0; for(const [x,y,v] of D.arms[p.a]) idx[y*W+x]=v; }
  if(p.b) for(const [x,y,v] of EYE[p.b===1?"half":"closed"]) idx[y*W+x]=v;
  if(p.f) for(const [x,y,v] of D.face[p.f]) idx[y*W+x]=v;
  if(p.g) for(const [x,y,v] of D.glint) idx[y*W+x]=v;
  // Row remap: legs fixed, body shifts by o, hair tips by o-l; gaps repeat the row below
  const src=new Int16Array(H).fill(-1);
  // torso+shoulders rise by c; head band stays, so the neck row tucks under the collar
  for(const [a,b,o] of [[SEAM,H,0],[WAIST,SEAM,p.o],[NECK,WAIST,p.o+p.c],[TIP,NECK,p.o+p.h],[0,TIP,p.o+p.h-p.l]])
    for(let s=a;s<b;s++){const d=s-o; if(d>=0&&d<H) src[d]=s;}
  let top=0; while(top<H&&src[top]<0) top++;
  for(let d=H-2;d>=top;d--) if(src[d]<0) src[d]=src[d+1];
  cv=document.createElement("canvas"); cv.width=W; cv.height=H;
  const cx=cv.getContext("2d"), im=cx.createImageData(W,H);
  for(let d=0;d<H;d++){const s=src[d]; if(s<0) continue; const sh=s<TIP?p.s:0;
    for(let x=0;x<W;x++){const sx=x-sh; if(sx<0||sx>=W) continue; const v=idx[s*W+sx];
      if(v){const c=PAL[v-1]; im.data.set([c[0],c[1],c[2],255],(d*W+x)*4);}}}
  cx.putImageData(im,0,0); cache.set(key,cv); return cv;
}

const R=(a,b)=>a+Math.floor(Math.random()*(b-a+1));
let anim="flex", speed=1, blinkOn=true, hairOn=true;
const IDLE={c:0,h:0,a:"",o:0,f:"",g:0,l:0};
// Idle breath: inhale lifts torso+shoulders 1px (head holds);
// exhale drops the torso and the head sinks 1px, then the head returns to rest.
// Hair tips trail the head both ways.
function breathSteps(){const deep=Math.random()<.2;
  return [[{k:0,c:0,h:0},R(8,16)],
          [{k:1,c:0,h:0},1],[{k:1,c:1,h:0},2],               // inhale
          [{k:2,c:1,h:0},deep?R(12,16):R(6,9)],             // hold
          [{k:1,c:1,h:0},2],
          [{k:1,c:0,h:-1,l:-1},1],[{k:0,c:0,h:-1,l:0},R(3,5)],// exhale: head sinks, tips lag up
          [{k:0,c:0,h:0,l:1},1]];}                          // head returns, tips lag down
// Flex: held key poses with single-tick transitions (GBA-style)
const FLEX=[
 [{k:0,a:"",     o:-1,f:"",    g:0,l:0}, 3], // anticipation dip
 [{k:0,a:"raise",o:0, f:"",    g:0,l:1}, 1], // smear, hair trails
 [{k:0,a:"flex", o:2, f:"grin",g:0,l:1}, 2], // snap with overshoot
 [{k:0,a:"flex", o:1, f:"grin",g:0,l:0}, 3], // settle
 [{k:0,a:"pump", o:1, f:"grin",g:0,l:0}, 3],
 [{k:0,a:"flex", o:1, f:"grin",g:0,l:0}, 2],
 [{k:0,a:"pump", o:1, f:"grin",g:1,l:0}, 5], // grin glint
 [{k:0,a:"flex", o:1, f:"grin",g:0,l:0}, 3],
 [{k:0,a:"pump", o:1, f:"grin",g:0,l:0}, 3],
 [{k:0,a:"flex", o:1, f:"grin",g:0,l:0}, 10],// hold
 [{k:0,a:"raise",o:0, f:"",    g:0,l:-1},1], // release, hair overshoots up
 [{k:0,a:"",     o:-1,f:"",    g:0,l:-1},2], // land
];
let seq=[], si=0, st=0, idleLeft=0;
function startIdle(){seq=breathSteps(); si=0; st=0;}
startIdle(); idleLeft=R(20,30);
function bodyTick(){
  const [p,n]=seq[si]; const out={...IDLE,...p};
  if(++st>=n){st=0; si++;
    if(si>=seq.length){
      if(seq===FLEX){startIdle(); idleLeft=R(30,48);}
      else if(anim==="flex"&&idleLeft<=0){seq=FLEX; si=0;}
      else startIdle();
    }}
  if(seq!==FLEX) idleLeft--;
  return out;
}
let blinkIn=R(30,60), blinkSeq=[];
function blinkTick(){ if(blinkSeq.length) return blinkSeq.shift();
  if(--blinkIn<=0){blinkIn=R(30,72); blinkSeq=[2,2,1]; if(Math.random()<.15) blinkSeq.push(0,0,1,2,1); return 1;} return 0;}
let sway=0, swayHold=R(18,48);
function hairTick(){ if(--swayHold>0) return sway;
  if(sway!==0){sway=0; swayHold=R(6,14);} else {sway=Math.random()<.5?-1:1; swayHold=R(8,20);} return sway;}

const hero=document.getElementById("hero"); hero.width=W; hero.height=H;
const zoom=document.getElementById("zoom"); zoom.width=zoom.height=36;
const hx=hero.getContext("2d"), zx=zoom.getContext("2d");
hx.imageSmoothingEnabled=zx.imageSmoothingEnabled=false;
sData.textContent=(JSON.stringify(D).length/1024).toFixed(1)+" KB";
let cur={...IDLE,k:0,s:0,b:0};
function step(){
  const p=bodyTick(); const flexing=!!p.a||p.f;
  const b=(blinkOn&&!p.f)?blinkTick():0;
  const s=hairOn?hairTick():0;
  cur={...p,s,b:flexing&&p.f?0:b};
}
function draw(){
  const c=pose(cur);
  hx.clearRect(0,0,W,H); hx.drawImage(c,0,0);
  zx.clearRect(0,0,36,36); zx.drawImage(c,8,0,36,36,0,0,36,36);
  sCache.textContent=cache.size; sComp.textContent=composites; sFps.textContent=reduce?0:12*speed;
  state.textContent=`Torso +${cur.c}px  Head ${cur.h}px  ${cur.a?"Arm: "+cur.a:"Arm: rest"}  Body ${cur.o>0?"+":""}${cur.o}px  Hair ${cur.s>0?"+":""}${cur.s}px  Eyes ${cur.f?"squint":["open","half","closed"][cur.b]}`;
}
function bindRadio(id,fn){const row=document.getElementById(id);
  row.querySelectorAll("button").forEach(b=>b.onclick=()=>{
    row.querySelectorAll("button").forEach(x=>x.setAttribute("aria-pressed",x===b)); fn(b.dataset.v);});}
bindRadio("anim",v=>{anim=v; if(v==="flex"){seq=FLEX; si=0; st=0;} else startIdle(); draw();});
bindRadio("speed",v=>{speed=+v;});
document.querySelectorAll("#chan button").forEach(b=>b.onclick=()=>{
  const on=b.getAttribute("aria-pressed")!=="true"; b.setAttribute("aria-pressed",on);
  if(b.dataset.v==="blink") blinkOn=on; else hairOn=on;});

const reduce=matchMedia("(prefers-reduced-motion: reduce)").matches;
let last=0, raf=0;
function loop(t){ if(t-last>=1000/(12*speed)){last=t; step(); draw();} raf=requestAnimationFrame(loop); }
document.addEventListener("visibilitychange",()=>{ if(document.hidden) cancelAnimationFrame(raf); else if(!reduce) raf=requestAnimationFrame(loop); });
draw(); if(!reduce) raf=requestAnimationFrame(loop);
window.__pose=pose;
</script></body></html>"""
open('/mnt/user-data/outputs/idle_and_flex.html','w').write(html.replace('__DATA__',data))
