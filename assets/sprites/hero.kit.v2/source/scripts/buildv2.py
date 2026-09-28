imgs=open('imgs2.json').read()
html=r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Character variants v2</title>
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
.side{display:flex;flex-direction:column;gap:12px;flex:1;min-width:260px}
.row{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.row>span{width:70px;color:var(--mute);font-size:13px}
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
<h1>Character variants v2</h1>
<p class="sub">Handoff layers stacked back hair, body, front hair, then recolored by palette swap. Wolf cut and long flowy are cleaned in v2. Toggle Layers to compare with the original handoff.</p>
<div class="stage">
 <canvas id="hero" class="checker" width="64" height="128" aria-label="Character preview"></canvas>
 <div class="side">
  <div class="row" id="gender"><span>Character</span></div>
  <div class="row" id="style"><span>Hairstyle</span></div>
  <div class="row" id="hair"><span>Hair color</span></div>
  <div class="row" id="skin"><span>Skin tone</span></div>
  <div class="row" id="ver"><span>Layers</span></div>
 </div>
</div>
<div class="stats">
 <div class="stat"><b>4</b><small>layers cleaned</small></div>
 <div class="stat"><b>150</b><small>total combinations</small></div>
 <div class="stat"><b id="sCache">0</b><small>composites cached</small></div>
 <div class="stat"><b>10</b><small>palette ramps</small></div>
</div>
<h2 id="gridTitle">All combinations</h2>
<canvas id="grid"></canvas>
</main>
<script>
const IMG=__IMGS__;
const STYLES={
 male:{buzz:["male_hair_buzz_front"],medium:["male_hair_medium_front"],wolf:["male_hair_wolf_back","male_hair_wolf_front"]},
 female:{blunt:["female_hair_blunt_front"],long:["female_hair_long_back","female_hair_long_front"],ponytail:["female_hair_ponytail_back","female_hair_ponytail_front"]}};
const LABEL={buzz:"Buzz",medium:"Medium",wolf:"Wolf cut",blunt:"Blunt bob",long:"Long flowy",ponytail:"Warrior ponytail"};
// Placeholder ramps in the handoff (dark to light)
const HAIR_KEY=["#0e2a12","#1d4a24","#2f6e37","#4a9652","#74c07a"];
const SKIN_KEY=["#8d6050","#b77f63","#d69b75","#eab58d","#f5c69d"];
// Proposed ramps (dark to light)
const HAIR={Black:["#16171f","#1f212b","#2c2f3c","#3f4456","#5d6680"],
 Brown:["#2a1810","#472a1a","#6b4127","#8f5d38","#b3804f"],
 Blonde:["#5a3f1e","#8a6a30","#b8954a","#dcc070","#f3e2a0"],
 Auburn:["#3a1410","#62211a","#8e3524","#b84e30","#d9744a"],
 Silver:["#3c4150","#626a7c","#8d95a6","#b8bfcb","#e2e6ec"]};
const SKIN={Fair:["#946451","#c08a6c","#deac8c","#f2cbae","#fbe0c8"],
 Light:["#8d6050","#b77f63","#d69b75","#eab58d","#f5c69d"],
 Tan:["#6a4029","#8c5a38","#ad744a","#c98e60","#e0a878"],
 Brown:["#472816","#633c22","#80502f","#9c6440","#b87a50"],
 Deep:["#28150c","#3b2013","#4e2d1b","#633b25","#7a4a30"]};
const hex=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));
const key=c=>(c[0]<<16)|(c[1]<<8)|c[2];

// Decode each layer once into packed colors
const layers={};
async function load(){
  await Promise.all(Object.entries(IMG).map(([n,src])=>new Promise(res=>{
    const im=new Image(); im.onload=()=>{const c=document.createElement("canvas");c.width=64;c.height=128;
      const x=c.getContext("2d");x.drawImage(im,0,0);layers[n]=x.getImageData(0,0,64,128).data;res();}; im.src=src;})));
}
const cache=new Map();
function compose(g,st,hc,sk){
  const k=[g,st,hc,sk,S.v].join("|"); let cv=cache.get(k); if(cv) return cv;
  const map=new Map();
  HAIR_KEY.forEach((h,i)=>map.set(key(hex(h)),hex(HAIR[hc][i])));
  SKIN_KEY.forEach((h,i)=>map.set(key(hex(h)),hex(SKIN[sk][i])));
  const hairL=st==="bald"?[]:STYLES[g][st];
  const order=[...hairL.filter(n=>n.endsWith("_back")),`${g}_body_bald`,...hairL.filter(n=>n.endsWith("_front"))];
  cv=document.createElement("canvas"); cv.width=64; cv.height=128;
  const cx=cv.getContext("2d"), out=cx.createImageData(64,128), o=out.data;
  for(const n0 of order){const n=(S.v==="v2"&&layers[n0+"@v2"])?n0+"@v2":n0; const d=layers[n];
    for(let i=0;i<d.length;i+=4){ if(!d[i+3]) continue;
      const c=[d[i],d[i+1],d[i+2]], m=map.get(key(c))||c;
      o[i]=m[0];o[i+1]=m[1];o[i+2]=m[2];o[i+3]=255;}}
  cx.putImageData(out,0,0); cache.set(k,cv); return cv;
}

const S={g:"male",st:"wolf",hc:"Black",sk:"Light",v:"v2"};
function radio(id,opts,get,set,chip){
  const row=document.getElementById(id); row.querySelectorAll("button").forEach(b=>b.remove());
  for(const [v,label] of opts){const b=document.createElement("button");
    if(chip){const s=document.createElement("i");s.className="chip";s.style.background=chip(v);b.append(s);}
    b.append(label); b.setAttribute("aria-pressed",v===get());
    b.onclick=()=>{set(v);render();}; row.append(b);}
}
function controls(){
  radio("gender",[["male","Male"],["female","Female"]],()=>S.g,v=>{S.g=v;S.st=Object.keys(STYLES[v])[1];});
  radio("style",[["bald","Bald"],...Object.keys(STYLES[S.g]).map(s=>[s,LABEL[s]])],()=>S.st,v=>S.st=v);
  radio("hair",Object.keys(HAIR).map(h=>[h,h]),()=>S.hc,v=>S.hc=v,v=>HAIR[v][3]);
  radio("ver",[["v1","v1 handoff"],["v2","v2 cleaned"]],()=>S.v,v=>S.v=v);
  radio("skin",Object.keys(SKIN).map(h=>[h,h]),()=>S.sk,v=>S.sk=v,v=>SKIN[v][3]);
}
const hero=document.getElementById("hero").getContext("2d");
const grid=document.getElementById("grid"), gx=grid.getContext("2d");
const CW=36, CHh=50, COLS=15;
function render(){
  controls();
  hero.clearRect(0,0,64,128); hero.drawImage(compose(S.g,S.st,S.hc,S.sk),0,0);
  const styles=Object.keys(STYLES[S.g]), combos=[];
  for(const sk of Object.keys(SKIN)) for(const st of styles) for(const hc of Object.keys(HAIR)) combos.push([st,hc,sk]);
  grid.width=COLS*CW; grid.height=Math.ceil(combos.length/COLS)*CHh;
  gx.clearRect(0,0,grid.width,grid.height);
  combos.forEach(([st,hc,sk],i)=>gx.drawImage(compose(S.g,st,hc,sk),14,4,CW,CHh,(i%COLS)*CW,Math.floor(i/COLS)*CHh,CW,CHh));
  document.getElementById("gridTitle").textContent=`All ${combos.length} ${S.g} combinations (rows: skin tone; groups: hairstyle × hair color)`;
  document.getElementById("sCache").textContent=cache.size;
}
load().then(render);
</script></body></html>"""
open('/mnt/user-data/outputs/character_variants_v2.html','w').write(html.replace('__IMGS__',imgs))
