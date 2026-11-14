import {mkdirSync,readFileSync,writeFileSync,copyFileSync,cpSync,existsSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {loadEffect,renderFrames,spriteSheet,contactSheet,canvas,upscale,writeVideo} from 'file:///C:/Users/Administrator/.codex/vendor_imports/pixelfx-main/tools/lib/fxlib.mjs';
const lib='C:/Users/Administrator/.codex/vendor_imports/pixelfx-main';
const project='C:/Users/Administrator/Desktop/代号1/圆卡旋风';
const dst=join(project,'assets/fx/feedback10'),qa=join(project,'verification/feedback10/art');
const warm=['#532a22','#8b4529','#bc632d','#df8b36','#f3b650','#ffe095','#fff0c6'];
const cold=['#173f50','#205b71','#287d91','#3a9da7','#64bac0','#9ed7ce','#def0dc'];
const green=['#31443a','#456246','#5b8248','#78a14a','#a2bd56','#c7d87b','#e1e9a9'];
const violet=['#3f315b','#634378','#855aa2','#a17bbe','#bf9ed0','#d6bfdf','#ece0e6'];
const defs=[
 ['heavy','impacts/crit-hit',13,0,.9,warm,220],
 ['lightning','lightning/zap-hit',13,0,.9,cold,190],
 ['frost','ice/ice-spikes',18,.1,3,cold,205],
 ['echo','pickups/collect-burst',15,0,1.35,violet,130],
 ['aftershock','water/ripples',18,0,1.9,cold,190],
 ['harvest_coin','pickups/coin-spin',19,0,1.5,warm,38],
 ['harvest_card','pickups/collect-burst',16,0,1.35,warm,72],
 ['contact','impacts/hit-spark',13,0,.5,warm,95],
 ['break','ui/confetti',18,.1,3.4,warm,112],
 ['harvest','pickups/collect-burst',16,0,1.35,warm,64],
];
const round=Number(process.argv[2]??1);mkdirSync(dst,{recursive:true});mkdirSync(qa,{recursive:true});
if(round===1){cpSync(join(lib,'src/core'),join(dst,'source/core'),{recursive:true});copyFileSync(join(lib,'LICENSE'),join(dst,'LICENSE.txt'));writeFileSync(join(dst,'source/package.json'),'{"type":"module"}\n');}
const manifest={version:'feedback10-a2',license:'MIT',source:'https://github.com/patch-gg/pixelfx',round,engine_filter:'nearest',effects:{}};
const overview=canvas(1450,defs.length*140+34,[243,218,174,255]);overview.text('A2 FEEDBACK '+round+' - CONSECUTIVE ANIMATION FRAMES',8,8,2,[62,58,47]);
for(let di=0;di<defs.length;di++){
 const [key,id,n,start,end,palette,display]=defs[di];
 const original=join(lib,'src/fx',id+'.js');const target=join(dst,'source/original/fx',id+'.js');mkdirSync(dirname(target),{recursive:true});copyFileSync(original,target);
 if(id.startsWith('impacts/'))copyFileSync(join(lib,'src/fx/impacts/_lib.js'),join(dirname(target),'_lib.js'));
 const fx=await loadEffect(id);let mod=fx.mod;
 if(round>=3&&['break','vortex','poison','harvest','harvest_card'].includes(key)){
  const adaptedDir=join(dst,'source/adapted');const adaptedPath=join(adaptedDir,id+'.js');mkdirSync(dirname(adaptedPath),{recursive:true});
  let source=readFileSync(original,'utf8');
  if(key==='break')source=source.replace('{ x: -74, y: -1','{ x: -8, y: -28').replace('{ x: 74, y: -1','{ x: 8, y: -28').replace('t: 0.1','t: 0.0').replace('t: 0.26','t: 0.03').replace('i < 46','i < 14').replace('i < 4','i < 2').replace('R.range(2, 3)','R.range(3.4, 4.6)').replace('R.range(3, 4.6)','R.range(4, 6)').replace('popper(p, pp.x, pp.y, pp.a, k, C, 1 - seg(t, 2.5, 2.9));','// Paper wrapping fragments only; no party popper prop.');
  if(key==='vortex')source=source.replace('D, 76, o.seed','D, 28, o.seed').replace('D, 58, o.seed','D, 40, o.seed').replace('front ? WHITE','front ? C[5]');
  if(round>=4&&key==='vortex')source=source.replace('0.07 + 0.24 * rim + 0.12 * swirl','0.13 + 0.32 * rim + 0.16 * swirl').replace('rim > 0.5 ? C[6] : swirl > 0.6 ? C[5] : C[4]','rim > 0.5 ? C[4] : swirl > 0.6 ? C[3] : C[2]');
  if(round>=5&&key==='vortex')source=source.replace('0.13 + 0.32 * rim + 0.16 * swirl','0.28 + 0.42 * rim + 0.18 * swirl').replace('u < 0.15 ? WHITE : u < 0.5 ? C[6] : C[5]','u < 0.15 ? C[6] : u < 0.5 ? C[4] : C[2]');
  if(round>=4&&key==='poison')source=source.replace('a: 0.46','a: 0.55').replace('a: 0.5','a: 0.6').replace('a: 0.56','a: 0.66');
  if(key==='harvest'||key==='harvest_card')source=source.replace('i % 3 === 0 ? 2.6 : R.range(1.2, 2)','i % 3 === 0 ? 4.2 : R.range(2, 2.8)');
  writeFileSync(adaptedPath,source);cpSync(join(lib,'src/core'),join(dst,'source/core'),{recursive:true});
  const helper=join(dirname(original),'_lib.js');if(existsSync(helper))copyFileSync(helper,join(dirname(adaptedPath),'_lib.js'));
  const adapted=await loadEffect(id,adaptedDir);fx.mod=adapted.mod;mod=adapted.mod;
 }
 const options={seed:27,light:round===1?.18:round===2?.1:.065,palette:round===1?fx.meta.options.palette:palette};
 if(round>=5&&key==='vortex')options.palette=['#153f3d','#1d5a50','#277866','#39987a','#59b08b','#86c9a6','#b6ddbc'];
 if(round>=5&&key==='poison')options.palette=['#233b28','#36532e','#4a7034','#638d3b','#82a845','#a8c35e','#cadc8b'];
 if(key==='poison')options.spread=round===1?.72:.5;
 if(key==='vortex')options.height=round===1?80:64;
 const originalDuration=fx.meta.duration;
 const raw=renderFrames(fx,{fps:60,bg:'none',actor:false,options});
 const w=raw.w,h=raw.h;
 const frames=[];
 for(let i=0;i<n;i++){
  const t=i/(n-1),si=Math.min(raw.n-1,Math.round((start+(end-start)*t)*60));let data=new Uint8ClampedArray(raw.frames[si].clear);
  // Looped library assets become finite world bursts, without extending game event lifetime.
  let envelope=fx.meta.loop?Math.min(1,(t+.06)/.18,Math.max(0,(1-t)/.28)):1;
  if(key==='break')envelope=Math.min(1,t/.06,(1-t)/.28);
  if(i===n-1)envelope=0;
  if(round>=2){
   const source=data.slice();
   for(let y=1;y<h-1;y++)for(let x=1;x<w-1;x++){
    const p=(y*w+x)*4,a=source[p+3];
    if(a>150){
     const lum=Math.max(source[p],source[p+1],source[p+2]);
     if(lum>235&&(round===2||Math.min(source[p],source[p+1],source[p+2])>210)){data[p]=key==='poison'?215:palette===cold?185:255;data[p+1]=palette===cold?229:key==='poison'?229:236;data[p+2]=palette===cold?221:key==='poison'?151:190;}
    }
    if(a<16&&['heavy','lightning','shock','frost','contact','break','harvest','harvest_card','echo'].includes(key)){
     if([p-4,p+4,p-w*4,p+w*4].some(q=>source[q+3]>190)){
      const c=palette===cold?[35,87,100]:[119,65,38];data.set([...c,round===2?140:190],p);
     }
    }
   }
  }
  for(let p=0;p<data.length;p+=4){data[p+3]=Math.round(data[p+3]*envelope*(key==='poison'&&round===2?.8:1));if(data[p+3]===0)data[p]=data[p+1]=data[p+2]=0;}
  const bg=new Uint8ClampedArray(data.length);for(let p=0;p<data.length;p+=4){const a=data[p+3]/255;bg[p]=data[p]*a+243*(1-a);bg[p+1]=data[p+1]*a+218*(1-a);bg[p+2]=data[p+2]*a+174*(1-a);bg[p+3]=255;}
  frames.push({t:i/30,clear:data,color:bg});
 }
 const r={w,h,n,fps:30,frames};const patched={...fx,meta:{...fx.meta,loop:false,duration:n/30},mod:{...mod,act:undefined}};
 const directory=join(qa,'round'+round,key);mkdirSync(directory,{recursive:true});
 writeFileSync(join(directory,'contact.png'),contactSheet(patched,r,{max:n,zoom:1,width:1600}));
 // Sequential 8-frame strip is also the offline animation review evidence.
 overview.text(key.toUpperCase(),6,40+di*140,2,[62,58,47]);
 for(let j=0;j<8;j++){
  const fi=Math.min(n-1,Math.floor(j*(n-1)/7));let rw=Math.min(w,160),rh=Math.min(h,110);const cell=new Uint8ClampedArray(rw*rh*4);
  for(let y=0;y<rh;y++)for(let x=0;x<rw;x++){const sx=Math.floor(x*w/rw),sy=Math.floor(y*h/rh);cell.set(frames[fi].color.slice((sy*w+sx)*4,(sy*w+sx)*4+4),(y*rw+x)*4);}
  overview.paste(cell,rw,rh,130+j*164,36+di*140);overview.text(String(fi),130+j*164,148+di*140,1,[62,58,47]);
 }
 const sheet=spriteSheet(patched,r,key);
 const info={path:'res://assets/fx/feedback10/'+key+'.png',metadata:key+'.json',source_id:id,frame_size:[w,h],frame_width:w,frame_height:h,frame_count:n,cols:sheet.json.meta.pixelfx.columns,fps:30,pivot_px:fx.meta.origin,pivot:fx.meta.origin,duration:n/30,display_width:display,source_time:[start,end],options,ending_empty:frames[n-1].clear.every(v=>v===0),recipe:'palette + low glow + selective 1px contour + finite burst envelope',license:'MIT'};
 manifest.effects[key]=info;
 if(round>=3){writeFileSync(join(dst,key+'.png'),sheet.png);writeFileSync(join(dst,key+'.json'),JSON.stringify(sheet.json,null,2));}
}
writeFileSync(join(qa,'round'+round+'-all.png'),overview.png());writeFileSync(join(qa,'round'+round+'-manifest.json'),JSON.stringify(manifest,null,2));if(round>=3)writeFileSync(join(dst,'manifest.json'),JSON.stringify(manifest,null,2));
console.log('round '+round+' complete '+join(qa,'round'+round+'-all.png'));

