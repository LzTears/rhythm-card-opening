import {readFileSync,writeFileSync,readdirSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {inflateSync} from 'node:zlib';
import {createHash} from 'node:crypto';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..'),art=resolve(root,'../../../verification/combat11/art');
const m=JSON.parse(readFileSync(resolve(root,'manifest.json'))),reports=[],fail=[];
function assert(ok,msg){if(!ok)fail.push(msg);}
for(const [key,e] of Object.entries(m.effects)){
 const j=JSON.parse(readFileSync(resolve(root,e.metadata))),p=j.meta.pixelfx,b=readFileSync(resolve(root,key+'.png'));
 const W=b.readUInt32BE(16),H=b.readUInt32BE(20),parts=[];let o=8;
 while(o<b.length){let n=b.readUInt32BE(o),type=b.toString('ascii',o+4,o+8);if(type==='IDAT')parts.push(b.subarray(o+8,o+8+n));o+=n+12;}
 const raw=inflateSync(Buffer.concat(parts));const stride=W*4+1;
 for(let y=0;y<H;y++){assert(raw[y*stride]===1,key+' PNG filter');for(let x=4;x<W*4;x++)raw[y*stride+1+x]=(raw[y*stride+1+x]+raw[y*stride+1+x-4])&255;}
 assert(p.fps===30&&p.frames===e.frame_count&&p.columns===4,key+' metadata');
 assert(W===e.frame_width*4&&H===e.frame_height*Math.ceil(e.frame_count/4),key+' dimensions');
 const counts=[],bounds=[];
 for(let f=0;f<e.frame_count;f++){
  let count=0,x0=e.frame_width,x1=-1,y0=e.frame_height,y1=-1;
  for(let y=0;y<e.frame_height;y++)for(let x=0;x<e.frame_width;x++){
   const gy=Math.floor(f/4)*e.frame_height+y,gx=f%4*e.frame_width+x;
   if(raw[gy*stride+1+gx*4+3]>0){count++;x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);}
  }
  counts.push(count);bounds.push(count?[x0,y0,x1,y1]:null);
 }
 assert(counts.some(n=>n>10),key+' visible');if(!e.loop)assert(counts.at(-1)===0,key+' terminal empty');
 if(e.direction)assert(Math.max(...bounds.filter(Boolean).map(b=>b[2]))>=e.frame_width*.89,key+' reaches endpoint');
 const expect=key.startsWith('pulse_')?10:key.startsWith('echo_')?15:key.startsWith('aftershock_')?16:key==='contact'?10:key==='trail'?12:13;
 assert(e.frame_count===expect,key+' timing');
 reports.push({key,frames:e.frame_count,duration:e.duration,visible_pixels:counts,bounds,terminal_empty:counts.at(-1)===0,sha256:createHash('sha256').update(b).digest('hex')});
}
assert(reports.length===53,'53 keys');
const result={passed:fail.length===0,failures:[...new Set(fail)],effects:reports,render_look_refine_rounds:5,background:'#d1b489'};
writeFileSync(resolve(art,'asset-verification.json'),JSON.stringify(result,null,2));
const hashes={};function walk(dir){for(const n of readdirSync(dir,{withFileTypes:true})){const p=resolve(dir,n.name);if(n.isDirectory())walk(p);else hashes[p.slice(root.length+1).replaceAll('\\','/')]=createHash('sha256').update(readFileSync(p)).digest('hex');}}
walk(resolve(root,'source/vendor_snapshot'));writeFileSync(resolve(root,'source/source-sha256.json'),JSON.stringify(hashes,null,2));
console.log(JSON.stringify({passed:result.passed,failures:result.failures,effects:reports.length,frames:reports.reduce((s,r)=>s+r.frames,0)}));if(fail.length)process.exit(1);

