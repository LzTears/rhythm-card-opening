import {mkdirSync,writeFileSync,readFileSync,copyFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';import {fileURLToPath,pathToFileURL} from 'node:url';
const here=dirname(fileURLToPath(import.meta.url)),vendor='C:/Users/Administrator/.codex/vendor_imports/pixelfx-main';
const {loadEffect,renderFrames,canvas}=await import(pathToFileURL(resolve(vendor,'tools/lib/fxlib.mjs')));
const groups={E05:['ice/snowflake-burst','ice/frost-nova','ice/ice-shatter']};
for(const [el,ids] of Object.entries(groups)){
 const out=resolve(here,'../../',el,'source');mkdirSync(resolve(out,'upstream'),{recursive:true});
 const board=canvas(3*300,3*250,[43,42,52,255]);
 for(let k=0;k<ids.length;k++){
  const fx=await loadEffect(ids[k]),r=renderFrames(fx,{actor:false,bg:'none'});copyFileSync(fx.file,resolve(out,'upstream',ids[k].replace('/','-')+'.js.txt'));
  const times=ids[k].includes('shatter')?[.65,.9,1.4]:ids[k].includes('frost')?[.5,.8,1.5]:ids[k].includes('snowflake')?[.2,.5,1.1]:ids[k].includes('acid')?[.4,.65,1.3]:[.2,1,2.2];
  for(let i=0;i<3;i++){const f=Math.min(r.n-1,Math.round(times[i]*r.fps));board.paste(r.frames[f].color,r.w,r.h,i*300+Math.floor((300-r.w)/2),k*250+45);board.text(ids[k]+' '+times[i].toFixed(2)+'s',i*300+5,k*250+8,1);}
 }
 writeFileSync(resolve(out,'round1-library-candidates.png'),board.png());
}
console.log('Candidate boards written; no runtime or engine.');
