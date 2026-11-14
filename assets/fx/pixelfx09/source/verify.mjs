import {readFileSync,writeFileSync} from 'node:fs';
import {inflateSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..'),m=JSON.parse(readFileSync(resolve(root,'manifest.json'))),results=[];
for(const [key,e] of Object.entries(m.effects)){
 const b=readFileSync(resolve(root,`${key}.png`)),j=JSON.parse(readFileSync(resolve(root,`${key}.json`)));let at=8,W,H,parts=[];
 while(at<b.length){const len=b.readUInt32BE(at),type=b.toString('ascii',at+4,at+8),v=b.subarray(at+8,at+8+len);if(type==='IHDR'){W=v.readUInt32BE(0);H=v.readUInt32BE(4)}if(type==='IDAT')parts.push(v);at+=12+len}
 const raw=inflateSync(Buffer.concat(parts)),stride=W*4,rgba=new Uint8Array(W*H*4);
 for(let y=0;y<H;y++){if(raw[y*(stride+1)]!==1)throw Error('Unexpected PNG filter');for(let x=0;x<stride;x++)rgba[y*stride+x]=(raw[y*(stride+1)+1+x]+(x>=4?rgba[y*stride+x-4]:0))&255}
 let nonempty=0,empty=0,last=0,partial=0;
 for(let i=0;i<e.frame_count;i++){let n=0;for(let y=0;y<e.frame_height;y++)for(let x=0;x<e.frame_width;x++){const a=rgba[((Math.floor(i/e.cols)*e.frame_height+y)*W+(i%e.cols)*e.frame_width+x)*4+3];if(a)n++;if(a>0&&a<255)partial++}if(n)nonempty++;else empty++;if(i===e.frame_count-1)last=n}
 if(W!==e.cols*e.frame_width||H!==Math.ceil(e.frame_count/e.cols)*e.frame_height||j.frames.length!==e.frame_count||last!==0||nonempty<3||!partial)throw Error(`Asset check failed: ${key}`);
 if(!key.startsWith('harvest')&&e.duration>.6)throw Error('Lifetime exceeds integration budget');
 results.push({key,passed:true,sheet:[W,H],frames:e.frame_count,nonempty_frames:nonempty,empty_frames:empty,last_frame_pixels:last,partial_alpha_pixels:partial,sha256:createHash('sha256').update(b).digest('hex')});
}
writeFileSync(resolve(root,'source/asset-verification.json'),JSON.stringify({passed:results.length===7,scope:'PNG decoded, metadata grid count, alpha, empty end, source-time-compressed duration; no engine/GPU claim',results},null,2));console.log(JSON.stringify({passed:true,effects:results.length,frames:results.reduce((a,r)=>a+r.frames,0)}));
