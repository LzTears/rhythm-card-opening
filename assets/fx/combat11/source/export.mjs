import {mkdirSync,writeFileSync,readFileSync,copyFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {loadEffect,renderFrames,canvas} from './vendor_snapshot/tools/lib/fxlib.mjs';
import {encodePNG} from './vendor_snapshot/tools/lib/png.mjs';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..'), art=resolve(root,'../../../verification/combat11/art');
const round=Number(process.argv[2]??2), dst=round>=2?root:resolve(art,`round${round}`);
mkdirSync(dst,{recursive:true});mkdirSync(art,{recursive:true});
const ramps=[
 ['#452511','#713e19','#a66325','#d28a32','#efb749','#ffda78','#fff0c2'],
 ['#12374e','#155573','#147e9c','#24a5bf','#64cfdd','#b3edf0','#edffff'],
 ['#4e1d17','#8a2c1b','#bc471e','#e56a24','#fa9b37','#ffd16c','#fff0bb'],
 ['#453015','#765023','#aa7e31','#d3a143','#edc364','#ffe39c','#fff3d4'],
 ['#143c55','#206383','#2f8ca5','#57b4c8','#88d6df','#bceaf0','#f2ffff'],
 ['#263322','#425635','#638037','#89a743','#adc65b','#d3e187','#ecf1b5'],
 ['#173d39','#216859','#2d8c70','#43ac85','#7bcea4','#b4e5c8','#eaffea'],
 ['#493516','#7e5f24','#b18b38','#d5af4c','#eed079','#ffe7ac','#fff6dc']
];
// Explicit source windows preserve each recipe's release; roles have different choreography.
const sources=[
 [['impacts/blunt-hit',0,.9,[0,-26]],['impacts/crit-hit',0,.9,[0,-26]],['nature/quake',.18,2.9,[0,-8]]],
 [['lightning/zap-hit',.03,.88,[0,0]],['lightning/thunderclap',.08,1.8,[0,-20]],['explosions/plasma-explosion',.08,1.65,[0,0]]],
 null, // retired emitter slot; other element indices stay unchanged
 [['impacts/parry',0,.96,[0,-26]],['arcane/mana-burst',.16,1.75,[0,0]],['water/ripples',.1,1.9,[0,0]]],
 [['ice/snowflake-burst',.1,3.1,[0,-48]],['ice/frost-nova',.3,3.3,[0,-10]],['ice/ice-shatter',.16,2.7,[0,-18]]],
 [['nature/poison-cloud',.2,3.8,[0,-18]],['nature/acid-splash',.05,2.75,[0,-12]],['nature/toxic-puddle',.2,3.8,[0,-10]]],
 [['nature/tornado',.12,1.9,[0,-50]],['nature/leaf-storm',.1,2.3,[0,-30]],['water/whirlpool',.1,2.9,[0,0]]],
 [['holy/sunburst',.1,3.8,[0,0]],['holy/smite',.3,2.7,[0,-15]],['arcane/rune-circle',.1,2,[0,0]]]
];
const specs=[];for(const e of [0,1,4])for(let role=0;role<3;role++)specs.push({key:`${['pulse','echo','aftershock'][role]}_E0${e+1}`,source:sources[e][role],e,n:[10,15,16][role],width:[155,175,180][role]});
specs.push(
 {key:'contact',source:['impacts/hit-spark',0,.5,[0,-26]],e:0,n:10,width:64},
 {key:'chain',source:['lightning/chain-lightning',.18,1.25,[10,-16]],e:1,n:13,width:210,path:true},
 {key:'penetration',source:['arcane/arcane-beam',0,1.16,[15,-24]],e:7,n:13,width:210,path:true},
 {key:'pull',source:['explosions/implosion',.05,.79,[0,0]],e:6,n:13,width:210,path:true},
 {key:'trail',source:['arcane/arcane-beam',0,1.2,[15,-24]],e:6,n:12,width:55,loop:true}
);
const pathRecipes=[
 [['impacts/crit-hit',0,.8,[0,-26]],['impacts/hit-spark',0,.5,[0,-26]],['impacts/blunt-hit',0,.85,[0,-26]]],
 [['lightning/chain-lightning',.18,1.25,[10,-16]],['lightning/zap-hit',.06,.85,[0,0]],['lightning/charge-up',.1,1.8,[0,-24]]],
 null, // retired emitter slot; other element indices stay unchanged
 [['impacts/parry',0,.95,[0,-26]],['water/wave-crash',.35,2.5,[0,-20]],['water/ripples',.08,1.9,[0,0]]],
 [['ice/snowflake-burst',.15,2.8,[0,-48]],['ice/frost-breath',0,1.2,[55,-25]],['ice/ice-spikes',.2,2.8,[0,-25]]],
 [['nature/acid-splash',.1,2.5,[0,-10]],['nature/poison-cloud',.15,3.5,[0,-18]],['nature/toxic-puddle',.1,3.6,[0,-10]]],
 [['nature/leaf-storm',.1,2.3,[0,-30]],['nature/tornado',.1,1.9,[0,-50]],['water/whirlpool',.1,2.8,[0,0]]],
 [['holy/sunburst',.1,3.8,[0,0]],['arcane/arcane-beam',0,1.16,[15,-24]],['arcane/rune-circle',.1,3.8,[0,0]]]
];
for(const e of [0,1,4])for(let role=0;role<3;role++)specs.push({key:`${['chain','penetration','pull'][role]}_E0${e+1}`,source:pathRecipes[e][role],e,n:13,width:210,path:true,variant:true,role});
const board=canvas(1400,specs.length*165,[209,180,137,255]), manifest={version:'combat11-a2',license:'MIT',fps:30,engine_filter:'nearest',effects:{}};
for(let s=0;s<specs.length;s++){
 const q=specs[s],[id,start,end,offset]=q.source,fx=await loadEffect(id);
 const options={palette:ramps[q.e],seed:29,light:[.65,.35,.18][Math.min(2,round)]};
 const r=renderFrames(fx,{fps:30,bg:'none',actor:false,options});
 let minX=r.w,maxX=0,minY=r.h,maxY=0;
 if(q.variant)for(const f of r.frames.filter(f=>f.t>=start&&f.t<=end))for(let y=0;y<r.h;y++)for(let x=0;x<r.w;x++)if(f.clear[(y*r.w+x)*4+3]>85){minX=Math.min(minX,x);maxX=Math.max(maxX,x);minY=Math.min(minY,y);maxY=Math.max(maxY,y);}
 let W=q.path?224:q.key==='trail'?80:192,H=q.path?88:q.key==='trail'?40:144,pivot=q.path?[12,44]:q.key==='trail'?[72,20]:[96,72];
 let origin=[fx.meta.origin[0]+offset[0],fx.meta.origin[1]+offset[1]], scale=Math.min(1,176/r.w,128/r.h);
 if(q.path)scale=1;
 const frames=[];
 for(let i=0;i<q.n;i++){
  let u=q.loop?i/q.n:i/(q.n-1),t=start+(end-start)*(q.variant&&q.role===2?1-u:u);
  const src=r.frames[Math.min(r.n-1,Math.round(t*30))].clear,buf=new Uint8ClampedArray(W*H*4);
  let fade=q.loop?1:Math.min(1,(1-u)*(round===0?3:5));
  if(fx.meta.loop&&!q.loop)fade*=Math.min(1,u*10+.5);
  if(q.e===5)fade*=round>=2?1.65:1;
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){
   let sx,sy;
   if(q.variant){
    if(x<12||x>212||y<15||y>73)continue;
    let v=(x-12)/200;
    if(q.role===0){v=(v*3)%1;if(v<.055||v>.945)continue;}
    if(q.role===2)v=Math.min(1,Math.max(0,(v-u*.18)/(1-u*.18)));
    sx=Math.round(minX+(maxX-minX)*.08+v*(maxX-minX)*.84);sy=Math.round(minY+(y-15)/58*(maxY-minY));
    if(q.e===6&&q.role===1){sx=Math.round(minX+(maxX-minX)*(.1+(y-15)/58*.8));sy=Math.round(maxY-(maxY-minY)*(.05+v*.9));}
   }
   else if(q.key==='pull') {sx=Math.round(20+(x-12)/208*84);sy=Math.round(92+(y-44)*1.8);} // left hemisphere of implosion accelerates toward right endpoint
   else if(q.key==='trail'){sx=Math.round(origin[0]+35+x*.75);sy=Math.round(origin[1]+(y-20));} // tail-only crop: fireball head at x112 excluded
   else if(q.key==='chain'){sx=Math.round(origin[0]+(x-12)*140/200);sy=Math.round(origin[1]+(y-44));}
   else if(q.key==='penetration'){sx=Math.round(origin[0]+(x-12)*168/200);sy=Math.round(origin[1]+(y-44));}
   else {sx=Math.round(origin[0]+(x-pivot[0])/scale);sy=Math.round(origin[1]+(y-pivot[1])/scale);}
   if(sx<0||sy<0||sx>=r.w||sy>=r.h)continue;
   const a=(sy*r.w+sx)*4,b=(y*W+x)*4;buf.set(src.subarray(a,a+4),b);buf[b+3]=Math.min(255,Math.round(buf[b+3]*fade));
  }
  if(round>=2){
   if(([1,5,7].includes(q.e)||q.variant))for(let z=0;z<buf.length;z+=4){if(buf[z+3]===0)continue;const lum=Math.max(buf[z],buf[z+1],buf[z+2])/255,ix=Math.min(6,Math.max(0,Math.round(lum*6)));const rgb=ramps[q.e][ix].slice(1).match(/../g).map(v=>parseInt(v,16));buf.set(rgb,z);}
   const copy=new Uint8ClampedArray(buf),ink=ramps[q.e][0].slice(1).match(/../g).map(v=>parseInt(v,16));
   for(let y=1;y<H-1;y++)for(let x=1;x<W-1;x++){const z=(y*W+x)*4;if(copy[z+3]>65)continue;if([-1,1,-W,W].some(d=>copy[z+d*4+3]>(q.e===5?85:150))){buf.set(ink,z);buf[z+3]=Math.round(185*fade);}}
   // Keep the hero flash brief on the bright desk; only two output frames retain full white.
   if(i>1)for(let z=0;z<buf.length;z+=4)if(buf[z]>235&&buf[z+1]>235&&buf[z+2]>225){buf[z]=Math.round(buf[z]*.94);buf[z+1]=Math.round(buf[z+1]*.94);buf[z+2]=Math.round(buf[z+2]*.94);}
  }
  if(q.variant)for(let y=0;y<H;y++)for(let x=0;x<W;x++){const edge=Math.min(1,Math.max(0,(x-11)/5),Math.max(0,(213-x)/5),Math.max(0,(y-14)/5),Math.max(0,(74-y)/5));const travel=q.role===0?Math.min(1,Math.max(0,u*8-Math.floor((x-12)/67)*.65+.4)):1;buf[(y*W+x)*4+3]=Math.round(buf[(y*W+x)*4+3]*edge*travel);}
  if(q.key==='trail')for(let y=0;y<H;y++)for(let x=0;x<W;x++)buf[(y*W+x)*4+3]=Math.round(buf[(y*W+x)*4+3]*Math.min(1,Math.max(0,(76-x)/10)));
  if(!q.loop&&i===q.n-1)buf.fill(0);
  if(q.key==='pull')for(let z=0;z<buf.length;z+=4)if(Math.max(buf[z],buf[z+1],buf[z+2])<105)buf[z+3]=0;
  frames.push(buf);
 }
 const cols=4,rows=Math.ceil(q.n/cols),rgba=new Uint8ClampedArray(W*cols*H*rows*4);
 frames.forEach((f,i)=>{for(let y=0;y<H;y++)rgba.set(f.subarray(y*W*4,(y+1)*W*4),((Math.floor(i/cols)*H+y)*W*cols+(i%cols)*W)*4);});
 const meta={id,fps:30,loop:!!q.loop,frames:q.n,frameSize:[W,H],pivot,columns:cols};
 const json={frames:frames.map((_,i)=>({filename:`${q.key} ${i}`,frame:{x:i%cols*W,y:Math.floor(i/cols)*H,w:W,h:H},rotated:false,trimmed:false,spriteSourceSize:{x:0,y:0,w:W,h:H},sourceSize:{w:W,h:H},duration:33})),meta:{app:'https://github.com/patch-gg/pixelfx',image:q.key+'.png',format:'RGBA8888',size:{w:W*cols,h:H*rows},pixelfx:meta}};
 writeFileSync(resolve(dst,q.key+'.png'),encodePNG(W*cols,H*rows,rgba));writeFileSync(resolve(dst,q.key+'.json'),JSON.stringify(json,null,2));
 manifest.effects[q.key]={path:`res://assets/fx/combat11/${q.key}.png`,metadata:q.key+'.json',source_id:id,frame_size:[W,H],frame_width:W,frame_height:H,cols,frame_count:q.n,fps:30,pivot,pivot_px:pivot,duration:q.n/30,display_width:q.width,loop:!!q.loop,source_time:[start,end],options,source_sha256:createHash('sha256').update(readFileSync(fx.file)).digest('hex'),...(q.path?{path_start:pivot,path_end:[212,44],direction:'right'}:{})};
 board.text(q.key,4,s*165+3,1,[47,31,26]);for(let j=0;j<5;j++){const f=frames[Math.round(j*(q.n-2)/4)];board.paste(f,W,H,150+j*240,s*165+15,{scale:.6});}
 console.log(q.key+' '+id);
}
writeFileSync(resolve(art,`round${round}-overview.png`),board.png());
for(let row=0;row<specs.length;row+=14){const h=Math.min(14,specs.length-row)*165;writeFileSync(resolve(art,`round${round}-panel${Math.floor(row/14)+1}.png`),encodePNG(board.w,h,board.data.subarray(row*165*board.w*4,(row*165+h)*board.w*4)));}
if(round>=2){writeFileSync(resolve(root,'manifest.json'),JSON.stringify(manifest,null,2));copyFileSync(resolve(root,'source/vendor_snapshot/LICENSE'),resolve(root,'LICENSE.txt'));}








