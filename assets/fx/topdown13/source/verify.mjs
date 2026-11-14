// Checks authored PNGs/metadata/sources only. Real Main, lifetime and GL checks are separate.
import {readFileSync,writeFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {inflateSync} from 'node:zlib';
import {createHash} from 'node:crypto';
const src=dirname(fileURLToPath(import.meta.url)),root=resolve(src,'..');
const manifest=JSON.parse(readFileSync(resolve(root,'manifest.json'))),cache=new Map(),failures=[],reports=[];
const hash=file=>createHash('sha256').update(readFileSync(file)).digest('hex');
const check=(ok,message)=>{if(!ok)failures.push(message);};
function png(file){
 if(cache.has(file))return cache.get(file);
 const data=readFileSync(file),width=data.readUInt32BE(16),height=data.readUInt32BE(20),parts=[];
 check(data[24]===8&&data[25]===6,file+' RGBA8');
 for(let at=8;at<data.length;){const n=data.readUInt32BE(at);if(data.toString('ascii',at+4,at+8)==='IDAT')parts.push(data.subarray(at+8,at+8+n));at+=n+12;}
 const pixels=inflateSync(Buffer.concat(parts)),stride=width*4+1;
 for(let y=0;y<height;y++){check(pixels[y*stride]===1,file+' supported Sub filter');for(let x=4;x<width*4;x++)pixels[y*stride+1+x]=(pixels[y*stride+1+x]+pixels[y*stride+1+x-4])&255;}
 const result={width,height,pixels,stride,sha256:hash(file)};cache.set(file,result);return result;
}
for(const [key,effect] of Object.entries(manifest.effects)){
 const json=JSON.parse(readFileSync(resolve(root,effect.metadata))),meta=json.meta.pixelfx;
 const image=resolve(root,json.meta.image),p=png(image),[w,h]=meta.frameSize,cols=meta.columns,counts=[],bounds=[];
 check(meta.topdown===true&&meta.fps===30&&meta.frames===effect.frame_count,key+' registered metadata');
 check(p.width===w*cols&&p.height===h*Math.ceil(meta.frames/cols),key+' complete sheet dimensions');
 check(p.sha256===effect.png_sha256,key+' exported SHA');
 const effectSource=effect.source_id==='custom/paper-press'?resolve(src,'paper-press.mjs'):resolve(src,'vendor_snapshot/src/fx',effect.source_id+'.js');
 check(hash(effectSource)===effect.source_sha256,key+' effect source SHA');
 check(meta.pivot.every((v,i)=>v===effect.pivot[i]),key+' unchanged pivot');
 for(let frame=0;frame<meta.frames;frame++){
  let n=0,x0=w,y0=h,x1=-1,y1=-1;
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){
   const gx=frame%cols*w+x,gy=Math.floor(frame/cols)*h+y;
   if(p.pixels[gy*p.stride+1+gx*4+3]>0){n++;x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y);}
   if(key.startsWith('coverage_')&&Math.hypot(x-w/2,y-h/2)<=34)check(p.pixels[gy*p.stride+1+gx*4+3]===0,key+' coverage center empty');
  }
  counts.push(n);bounds.push(n?[x0,y0,x1,y1]:null);
 }
 check(counts.some(n=>n>10),key+' visible source');check(counts.at(-1)===0,key+' transparent terminal frame');
 if(effect.alias_of){const other=JSON.parse(readFileSync(resolve(root,manifest.effects[effect.alias_of].metadata)));check(json.meta.image===other.meta.image,key+' shares target PNG');}
 if(effect.reuse)check(hash(resolve(src,'legacy_routes',key+'.png'))===p.sha256,key+' byte-identical legacy path');
 reports.push({key,frames:meta.frames,fps:meta.fps,source_duration:meta.source_duration,alias_of:effect.alias_of??null,sha256:p.sha256,first_visible:counts.findIndex(n=>n>0),terminal_empty:counts.at(-1)===0,peak_pixels:Math.max(...counts),bounds});
}
const source_hashes={};
for(const [id,expected] of Object.entries(manifest.source_files)){
 const file=id==='custom/paper-press'?resolve(src,'paper-press.mjs'):resolve(src,'vendor_snapshot/src/fx',id+'.js');source_hashes[id]=hash(file);check(source_hashes[id]===expected,id+' source SHA');
}
check(Object.keys(manifest.effects).length===31,'31 retained registered sheet keys');check(cache.size===21,'21 retained unique PNG textures');
const heavy=reports.find(x=>x.key==='heavy');check(heavy.first_visible===0,'E01 begins on release frame without gameplay lead-in');
const result={passed:failures.length===0,scope:'PNG/source/metadata only; no claim of GL or gameplay validation',sheet_keys:reports.length,unique_pngs:cache.size,failures:[...new Set(failures)],source_hashes,effects:reports};
writeFileSync(resolve(src,'asset-verification.json'),JSON.stringify(result,null,2));
console.log(JSON.stringify({passed:result.passed,sheet_keys:reports.length,unique_pngs:cache.size,failures:result.failures}));
if(failures.length)process.exitCode=1;
