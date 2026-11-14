import {writeFileSync} from 'node:fs';import {resolve,dirname} from 'node:path';import {fileURLToPath,pathToFileURL} from 'node:url';
const here=dirname(fileURLToPath(import.meta.url)),round=Number(process.argv[2]??2),vendor='C:/Users/Administrator/.codex/vendor_imports/pixelfx-main';
const {renderFrames,canvas}=await import(pathToFileURL(resolve(vendor,'tools/lib/fxlib.mjs')));
for(const [el,file] of [['E05','frost.mjs']]){
 const folder=resolve(here,'../../',el,'source'),mod=await import(pathToFileURL(resolve(folder,file))+'?v='+Date.now());
 const board=canvas(4*240,2*250,[43,42,52,255]);
 for(let ri=0;ri<2;ri++){const role=['main','wave'][ri];let m=mod.make(role,round),options={};if(round>=3&&el==='E05'&&role==='main')m=await import(pathToFileURL(resolve(folder,'snowflake-overhead.mjs')));if(round>=3&&role==='wave'){m=await import(pathToFileURL(resolve(folder,'plasma-wave.mjs')));options={palette:el==='E05'?mod.palette:['#261435','#453053','#287469','#48ad7b','#8fda8d','#d6f1ae','#ffffff'],accent:el==='E05'?['#102343','#174571','#369dcc','#9de9f5','#ffffff']:['#261435','#49355b','#329e72','#8fda8d','#e4f9b3']};}const r=renderFrames({mod:m,meta:m.meta},{actor:false,bg:'none',options});const times=role==='wave'?[.1,.23,.45,.9]:el==='E05'?[.2,.5,1.2,2.5]:[.37,.55,1.2,2.35];for(let i=0;i<4;i++){const f=Math.min(r.n-1,Math.round(times[i]*r.fps));board.paste(r.frames[f].color,r.w,r.h,i*240+8,ri*250+24);board.text(el+' '+role+' '+times[i].toFixed(2)+'s R'+round,i*240+5,ri*250+5,1);}}
 writeFileSync(resolve(folder,'round'+round+'-overhead-contact.png'),board.png());
}
console.log('Round '+round+' contacts written.');
