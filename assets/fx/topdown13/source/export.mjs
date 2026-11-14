// TASK-119: reproducible top-down asset fork. No runtime/gameplay code or old asset is written.
import{readFileSync,writeFileSync,copyFileSync,mkdirSync}from'node:fs';
import{resolve,dirname,join}from'node:path';import{fileURLToPath}from'node:url';import{createHash}from'node:crypto';
import{loadEffect,renderFrames,canvas}from'./vendor_snapshot/tools/lib/fxlib.mjs';
import{encodePNG}from'./vendor_snapshot/tools/lib/png.mjs';
import * as paper from './paper-press.mjs';
const src=dirname(fileURLToPath(import.meta.url)),out=resolve(src,'..');mkdirSync(out,{recursive:true});
const sha=file=>createHash('sha256').update(readFileSync(file)).digest('hex');
const ramps=[
 ['#351b12','#653719','#a65d25','#cf8a39','#efbd72','#fff0c6','#fffce8'],
 ['#12374e','#155573','#147e9c','#24a5bf','#64cfdd','#b3edf0','#edffff'],
 ['#4e1d17','#8a2c1b','#bc471e','#e56a24','#fa9b37','#ffd16c','#fff0bb'],
 ['#453015','#765023','#aa7e31','#d3a143','#edc364','#ffe39c','#fff3d4'],
 ['#143c55','#206383','#2f8ca5','#57b4c8','#88d6df','#bceaf0','#f2ffff'],
 ['#263322','#425635','#638037','#89a743','#adc65b','#d3e187','#ecf1b5'],
 ['#173d39','#216859','#2d8c70','#43ac85','#7bcea4','#b4e5c8','#eaffea'],
 ['#493516','#7e5f24','#b18b38','#d5af4c','#eed079','#ffe7ac','#fff6dc']
];
const names=['heavy','lightning',null,null,'frost',null,null,null];
const legacy=[.46,.46,.60,.46,.60,.60,.60,16/30];
const native=[
 {id:'custom/paper-press',start:.10,end:1.4,offset:[0,0],paper:true},
 {id:'lightning/zap-hit',start:.05,end:.9,offset:[0,0]},
 null, // retired emitter slot; preserve all remaining indices

 {id:'arcane/mana-burst',start:.22,end:1.8,offset:[0,-28]},
 {id:'ice/snowflake-burst',start:.16,end:3.2,offset:[0,-48]},
 {id:'nature/poison-cloud',start:.10,end:3.9,offset:[0,-18],radial_cloud:true},
 {id:'water/whirlpool',start:0,end:3,offset:[0,0],sy:.6,scale:1.18},
 {id:'holy/sunburst',start:0,end:4,offset:[0,0]}
];
const waves=[
 {...native[0],start:.15,options:{core:false}},
 {id:'explosions/plasma-explosion',start:.16,end:1.7,offset:[0,0]},
 null, // retired emitter slot

 {id:'water/ripples',start:0,end:2,offset:[0,0],sy:.26,scale:1.12},
 {...native[4],start:.32},native[5],native[6],native[7]
];
const manifest={version:'topdown13-task119',license:'MIT',source:'https://github.com/patch-gg/pixelfx',
 production_playback_contract:'Committed event count, geometry and lifetime are unchanged. Production keeps the existing floor(age/event_duration*frame_count) full-sequence mapping. Source FPS/duration below describe source art, never a new attack clock.',
 legacy_native_min_duration:Object.fromEntries(legacy.flatMap((v,i)=>![0,1,4].includes(i)?[]:[['E0'+(i+1),v]])),
 selection:'V5 native top-down paper press for heavy; radial zap/plasma/mana/snowflake; original poison-cloud texture reassembled as three radial planar lobes (no upright billboards); whirlpool and transparent ripple ridges geometrically unproject authored Y squash. All center pivots are registered on the actual committed tabletop point. Existing eight elemental route strips retain their original pixels and use true XZ segments.',
 effects:{},reuse:[],source_files:{}};
const sheets=new Map(),renderCache=new Map();
function writeSheet(key,frames,W,H,pivot,metadata,record,image=key+'.png'){
 const cols=Math.ceil(Math.sqrt(frames.length*H/W)),rows=Math.ceil(frames.length/cols),pixels=new Uint8ClampedArray(W*cols*H*rows*4);
 frames.forEach((f,i)=>{for(let y=0;y<H;y++)pixels.set(f.subarray(y*W*4,(y+1)*W*4),((Math.floor(i/cols)*H+y)*W*cols+i%cols*W)*4);});
 writeFileSync(join(out,image),encodePNG(W*cols,H*rows,pixels));
 const json={frames:frames.map((_,i)=>({filename:key+' '+i,frame:{x:i%cols*W,y:Math.floor(i/cols)*H,w:W,h:H},rotated:false,trimmed:false,spriteSourceSize:{x:0,y:0,w:W,h:H},sourceSize:{w:W,h:H},duration:33})),
 meta:{app:'https://github.com/patch-gg/pixelfx',image,format:'RGBA8888',size:{w:W*cols,h:H*rows},pixelfx:{id:record.source_id,fps:30,loop:false,frames:frames.length,frameSize:[W,H],pivot,columns:cols,topdown:true,...metadata}}};
 writeFileSync(join(out,key+'.json'),JSON.stringify(json,null,2));
 manifest.effects[key]={path:'res://assets/fx/topdown13/'+image,metadata:key+'.json',frame_count:frames.length,fps:30,frame_size:[W,H],pivot,...record,png_sha256:sha(join(out,image))};
 sheets.set(key,{frames,W,H,pivot,json});
}
function alias(key,target,role,gain=1){
 const base=sheets.get(target),json=structuredClone(base.json);json.meta.pixelfx.alias_of=target;json.meta.pixelfx.role=role;json.meta.pixelfx.visual_gain=gain;
 writeFileSync(join(out,key+'.json'),JSON.stringify(json,null,2));
 manifest.effects[key]={...manifest.effects[target],metadata:key+'.json',alias_of:target,role,visual_gain:gain};
 sheets.set(key,{...base,json});
}
async function renderRecipe(recipe,e){
 const options={palette:ramps[e],accent:ramps[e],seed:29,light:.28,...recipe.options};
 if(recipe.paper){delete options.palette;delete options.accent;options.seed=71;options.light=.85;}
 const tag=JSON.stringify([recipe.id,e,options,!!recipe.surface]);if(renderCache.has(tag))return renderCache.get(tag);
 let fx=recipe.paper?{id:'custom/paper-press',mod:paper,meta:paper.meta,file:join(src,'paper-press.mjs')}:await loadEffect(recipe.id);
 if(recipe.surface){const original=fx.mod;fx={...fx,mod:{meta:fx.meta,draw(p,t,o){original.drawBack(p,t,o);}}};}
 const r=renderFrames(fx,{actor:false,bg:'none',options});const result={fx,r,options};renderCache.set(tag,result);return result;
}
async function circular(key,recipe,e,role,W=192){
 const {fx,r,options}=await renderRecipe(recipe,e),center=[fx.meta.origin[0]+recipe.offset[0],fx.meta.origin[1]+recipe.offset[1]],sy=recipe.sy??1;
 const selected=r.frames.filter(f=>f.t+1e-7>=recipe.start&&f.t<=recipe.end+1e-7),extent=W===128?54:76;
 let maximum=1;
 if(!recipe.paper&&!recipe.scale)for(const frame of selected)for(let y=0;y<r.h;y++)for(let x=0;x<r.w;x++)if(frame.clear[(y*r.w+x)*4+3]>12)maximum=Math.max(maximum,Math.abs(x-center[0]),Math.abs(y-center[1])/sy);
 const scale=recipe.paper?1:(recipe.scale??extent/maximum),frames=[];
 for(let i=0;i<selected.length;i++){
  const input=selected[i].clear,frame=new Uint8ClampedArray(W*W*4),u=i/Math.max(1,selected.length-1),grow=role==='aftershock'&&e>=5?.32+.68*(1-Math.pow(1-Math.min(u/.72,1),3)):1;
  const fade=Math.min(1,(1-u)/.14);
  for(let y=0;y<W;y++)for(let x=0;x<W;x++){
   const dx=x-W/2,dy=y-W/2;
   if(recipe.radial_cloud){
    let A=0,red=0,green=0,blue=0;
    for(let lobe=0;lobe<3;lobe++){
     const angle=lobe*Math.PI*2/3+.17,rx=dx*Math.cos(angle)+dy*Math.sin(angle),ry=-dx*Math.sin(angle)+dy*Math.cos(angle);
     const sx=Math.round(center[0]+rx/(scale*grow)),sY=Math.round(center[1]+ry/(scale*grow));if(sx<0||sY<0||sx>=r.w||sY>=r.h)continue;
     const at=(sY*r.w+sx)*4,a=input[at+3]/255*.70,next=a+A*(1-a);if(next<=0)continue;
     red=(input[at]*a+red*A*(1-a))/next;green=(input[at+1]*a+green*A*(1-a))/next;blue=(input[at+2]*a+blue*A*(1-a))/next;A=next;
    }
    const at=(y*W+x)*4,mask=Math.max(0,Math.min(1,(81*grow-Math.hypot(dx,dy))/7));frame.set([Math.round(red),Math.round(green),Math.round(blue),Math.round(A*255*fade*mask)],at);continue;
   }
   const sx=Math.round(center[0]+dx/(scale*grow)),sY=Math.round(center[1]+dy*sy/(scale*grow));
   if(sx<0||sY<0||sx>=r.w||sY>=r.h)continue;
   if(recipe.surface&&(sY<fx.meta.origin[1]-10||sY>fx.meta.origin[1]+3))continue;
   const a=(sY*r.w+sx)*4,b=(y*W+x)*4;frame.set(input.subarray(a,a+4),b);
   const mask=recipe.surface?Math.max(0,Math.min(1,(79*grow-Math.hypot(dx,dy))/4)):1;
   const ridge=role==='aftershock'&&e===3?Math.max(0,Math.min(1,(Math.max(frame[b],frame[b+1],frame[b+2])-170)/50)):1;
   frame[b+3]=Math.round(frame[b+3]*fade*mask*ridge);
  }
  if(i===selected.length-1)frame.fill(0);frames.push(frame);
 }
 const file=fx.file;manifest.source_files[recipe.id]=sha(file);
 writeSheet(key,frames,W,W,[W/2,W/2],{role,visual_radius_px:extent,visual_gain:1,source_duration:fx.meta.duration,legacy_native_min_duration:legacy[e]},
 {source_id:recipe.id,source_sha256:sha(file),source_fps:r.fps,source_duration:fx.meta.duration,source_samples:[selected[0].t,selected.at(-1).t],options,
  adaptation:recipe.radial_cloud?'Original poison-cloud RGBA reassembled as three rotated overlapping planar lobes, radial alpha edge and finite fade; no side-view upright plume':recipe.sy?'Inverse authored Y squash '+recipe.sy+'; square center registration; shock ripples retain bright original ridges and suppress dark water-disc fill':recipe.paper?'V5 author source from RELEASE; center registration; aftershock may suppress original center core through explicit source option':'Original radial source artwork, center registration/uniform fit, source release crop, finite fade'});
 console.log(key+' '+recipe.id+' '+frames.length+' frames');
}
for(const e of [0,1,4]){
 const element='E0'+(e+1);await circular(names[e],native[e],e,'native');
 alias('pulse_'+element,names[e],'pulse');alias('echo_'+element,names[e],'echo',1.08);
 const waveKey='aftershock_'+element;await circular(waveKey,waves[e],e,'aftershock');alias('bond_'+element,waveKey,'bond',.24);
 const wave=sheets.get(waveKey),coverage=wave.frames.map(input=>{const frame=input.slice();for(let y=0;y<wave.H;y++)for(let x=0;x<wave.W;x++){
  const dx=x-wave.W/2,dy=y-wave.H/2,radius=Math.hypot(dx,dy),angle=Math.atan2(dy,dx),inner=Math.max(0,Math.min(1,(radius-34)/10));
  const broken=Math.sin(angle*3+.7)+.45*Math.sin(angle*7-.2)>-.10?1:.14;
  const at=(y*wave.W+x)*4+3;frame[at]=Math.round(frame[at]*inner*broken*.72);
 }return frame;});
 const waveRecord=manifest.effects[waveKey];
 writeSheet('coverage_'+element,coverage,wave.W,wave.H,wave.pivot,{role:'coverage',visual_radius_px:76,visual_gain:1,source_duration:waveRecord.source_duration},
  {source_id:waveRecord.source_id,source_sha256:waveRecord.source_sha256,source_fps:waveRecord.source_fps,source_duration:waveRecord.source_duration,source_samples:waveRecord.source_samples,options:waveRecord.options,adaptation:'Corresponding original elemental wave pixels, center removed and low-density broken outer coverage retained for actual C01 full radius; no new event or target'});
 await circular('contact_'+element,{id:'impacts/hit-spark',start:0,end:.5,offset:[0,-20]},e,'contact',128);
}
// The complete existing elemental strips are retained byte-for-byte. Runtime fixes the
// old camera-plane placement by using true XZ from/to axes; no generic lightning swap.
const old=JSON.parse(readFileSync(join(src,'legacy_routes/manifest.json'),'utf8'));
for(const e of [1,2,5])for(const role of ['chain','penetration','pull']){
 const key=role+'_E0'+e,json=JSON.parse(readFileSync(join(src,'legacy_routes',key+'.json'),'utf8'));
 json.meta.pixelfx.topdown=true;json.meta.pixelfx.role=role;json.meta.pixelfx.source_duration=old.effects[key].source_time[1]-old.effects[key].source_time[0];
 copyFileSync(join(src,'legacy_routes',key+'.png'),join(out,key+'.png'));writeFileSync(join(out,key+'.json'),JSON.stringify(json,null,2));
 manifest.effects[key]={...old.effects[key],path:'res://assets/fx/topdown13/'+key+'.png',metadata:key+'.json',reuse:'Unmodified complete existing elemental directional sheet; only XZ presentation axes change',png_sha256:sha(join(out,key+'.png'))};
}
alias('break','heavy','wrapper_burst');
manifest.reuse.push({key:'break',reuse:'Existing V5 native top-down paper burst texture; no extra drawing. Original World registration width and 420ms event remain authoritative.'},
 {key:'trail',path:'res://assets/fx/combat11/trail.png',reuse:'Unmodified actual texture already follows 48 true velocity samples on XZ; no new drawing or changed 620ms history.'},
 {key:'contact',path:'res://assets/fx/combat11/contact.png',reuse:'Legacy compatibility only; normal new hits select contact_E01/E02/E05.'});
manifest.native_and_aux_keys={};for(const e of [0,1,4])manifest.native_and_aux_keys['E0'+(e+1)]=[names[e],...['pulse','echo','aftershock','bond','chain','penetration','pull','contact','coverage'].map(x=>x+'_E0'+(e+1)),'break','contact','trail'];
writeFileSync(join(out,'manifest.json'),JSON.stringify(manifest,null,2));
// Five real source frames for each unique role/element, for mandatory visual review.
const review=canvas(1120,8*330,[214,184,140,255]);
for(const e of [0,1,4]){for(const [row,key]of[[0,names[e]],[1,'aftershock_E0'+(e+1)]]){const s=sheets.get(key);review.text(key,4,e*330+row*160+3,1,[48,29,17]);for(let j=0;j<5;j++)review.paste(s.frames[Math.min(s.frames.length-2,Math.round(j*(s.frames.length-2)/5))],s.W,s.H,110+j*200,e*330+row*160+10,{scale:.72});}}
writeFileSync(join(out,'source/overview.png'),review.png());
console.log('TOPDOWN13 '+Object.keys(manifest.effects).length+' keys, complete source manifest written');
