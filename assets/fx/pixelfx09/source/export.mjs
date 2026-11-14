import {mkdirSync,writeFileSync,readFileSync,copyFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {loadEffect,renderFrames,canvas,upscale} from './vendor_snapshot/tools/lib/fxlib.mjs';
import {encodePNG} from './vendor_snapshot/tools/lib/png.mjs';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const vendor=resolve(dirname(fileURLToPath(import.meta.url)),'vendor_snapshot');
const rounds=Number(process.argv[2]??2);
const palettes={
 gold:['#38190c','#713514','#ac571c','#dc8a25','#efb635','#ffcf53','#ffe6a0','#fff7db'],
 ice:['#102a46','#17496d','#187394','#299bb5','#4dbfd2','#8bdfeb','#c5f4f7','#f0ffff'],
 violet:['#28154b','#4e2873','#7243a4','#9d64cb','#bb8ae5','#d8b0f6','#ecd6ff','#fff1ff'],
 poison:['#24213c','#343553','#465e4b','#44853b','#6ca832','#a0c841','#cce96b','#e9f4a0']
};
// These are stock variants, not newly authored effects. Source time ranges preserve the hero release.
const specs=[
 ['heavy','impacts/crit-hit','gold',.43,0,.9,[0,-26],220],
 ['lightning','lightning/zap-hit','ice',.43,0,.9,[0,0],190],
 ['frost','ice/snowflake-burst','ice',.60,.12,3.2,[0,-48],180],
 ['echo','pickups/collect-burst','violet',.5,0,1.35,[0,-30],130],
 ['aftershock','water/ripples','ice',.60,0,1.9,[0,0],190],
 ['harvest_coin','pickups/coin-spin','gold',.62,0,1.5,[0,-22],38],
 ['harvest_card','pickups/collect-burst','gold',.52,0,1.35,[0,-30],72]
];
const board=canvas(1536,specs.length*150,[209,180,137,255]);
const manifest={version:'pixelfx09-a2',license:'MIT',engine_filter:'nearest',fps:30,effects:{},source_root:vendor};
for(let si=0;si<specs.length;si++){
 const [key,id,pal,duration,start,end,offset,width]=specs[si];
 const fx=await loadEffect(id);
 const opts=rounds===0?{}:{palette:palettes[pal],light:rounds===1?.55:.22,seed:17,...(key==='poison'?{spread:.72}:{})};
 const r=renderFrames(fx,{fps:60,actor:false,bg:'none',options:opts});
 const n=Math.ceil(duration*30), frames=[];
 for(let i=0;i<n;i++){
  const u=i/(n-1),t=start+(end-start)*u,src=r.frames[Math.min(r.n-1,Math.round(t*60))].clear;
  const data=new Uint8ClampedArray(src);
  let fade=1;
  if(fx.meta.loop)fade=Math.min(1,u*9)*(Math.max(0,Math.min(1,(1-u)*4)));
  else fade=Math.max(0,Math.min(1,(1-u)*5));
  // Clouds retain transparency on the bright desk. Do not wash out the mouse landing marker.
  if(key==='poison')fade*=rounds===2?.70:1;
  for(let p=3;p<data.length;p+=4)data[p]=Math.round(data[p]*fade);
  // A one-pixel dark ink outside solid fragments makes pale cores readable on A2 wood.
  if(rounds===2 && ['heavy','shock','frost','harvest_coin','harvest_card','echo'].includes(key)){
   const mask=new Uint8ClampedArray(data);
   const ink=pal==='gold'?[91,47,26]:pal==='violet'?[58,30,88]:[19,66,89];
   for(let y=1;y<r.h-1;y++)for(let x=1;x<r.w-1;x++){
    const p=(y*r.w+x)*4;
    if(mask[p+3]>72)continue;
    if([-1,1,-r.w,r.w].some(q=>mask[p+q*4+3]>190)){
     data[p]=ink[0];data[p+1]=ink[1];data[p+2]=ink[2];data[p+3]=Math.round(150*fade);
    }
   }
  }
  frames.push({t:i/30,clear:data,color:data});
 }
 const cols=4,rows=Math.ceil(n/cols),W=r.w*cols,H=r.h*rows,rgba=new Uint8ClampedArray(W*H*4);
 frames.forEach((f,i)=>{for(let y=0;y<r.h;y++)rgba.set(f.clear.subarray(y*r.w*4,(y+1)*r.w*4),((Math.floor(i/cols)*r.h+y)*W+(i%cols)*r.w)*4)});
 const pivot=[fx.meta.origin[0]+offset[0],fx.meta.origin[1]+offset[1]];
 const json={frames:frames.map((f,i)=>({filename:`${key} ${i}`,frame:{x:i%cols*r.w,y:Math.floor(i/cols)*r.h,w:r.w,h:r.h},rotated:false,trimmed:false,spriteSourceSize:{x:0,y:0,w:r.w,h:r.h},sourceSize:{w:r.w,h:r.h},duration:33})),meta:{app:'https://github.com/patch-gg/pixelfx',image:`${key}.png`,format:'RGBA8888',size:{w:W,h:H},pixelfx:{id,fps:30,loop:false,frames:n,frameSize:[r.w,r.h],pivot,columns:cols}}};
 let bx=r.w,by=r.h,ex=-1,ey=-1,peak=0,hero=0;
 frames.forEach((f,i)=>{let count=0;for(let y=0;y<r.h;y++)for(let x=0;x<r.w;x++)if(f.clear[(y*r.w+x)*4+3]>20){count++;bx=Math.min(bx,x);by=Math.min(by,y);ex=Math.max(ex,x);ey=Math.max(ey,y)}if(count>peak){peak=count;hero=i}});
 const record={path:`res://assets/fx/pixelfx09/${key}.png`,metadata:`${key}.json`,source_id:id,frame_size:[r.w,r.h],frame_width:r.w,frame_height:r.h,cols,frame_count:n,fps:30,pivot_px:pivot,pivot,duration:n/30,last_sample_time:(n-1)/30,display_width:width,visible_bounds:[bx,by,ex-bx+1,ey-by+1],hero_frame:hero,source_time:[start,end],options:opts,source_sha256:createHash('sha256').update(readFileSync(fx.file)).digest('hex')};
 manifest.effects[key]=record;
 const out=rounds===2?root:resolve(root,`source/round${rounds}`);mkdirSync(out,{recursive:true});
 writeFileSync(resolve(out,`${key}.png`),encodePNG(W,H,rgba));writeFileSync(resolve(out,`${key}.json`),JSON.stringify(json,null,2));
 board.text(key,6,si*150+6,2,[43,30,35]);
 for(let j=0;j<6;j++){
  const f=frames[Math.round(j*(n-2)/5)],scale=Math.min(1,220/r.w,115/r.h); const dw=Math.round(r.w*scale),dh=Math.round(r.h*scale),buf=new Uint8ClampedArray(dw*dh*4);
  for(let y=0;y<dh;y++)for(let x=0;x<dw;x++){const q=(Math.min(r.h-1,Math.floor(y/scale))*r.w+Math.min(r.w-1,Math.floor(x/scale)))*4;buf.set(f.clear.subarray(q,q+4),(y*dw+x)*4)}
  board.paste(buf,dw,dh,j*256+12,si*150+30);
 }
 console.log(`${key}: ${n} frames ${r.w}x${r.h}, pivot ${pivot}`);
}
mkdirSync(resolve(root,'source'),{recursive:true});
writeFileSync(resolve(root,`source/round${rounds}-contact.png`),board.png());
if(rounds===2){writeFileSync(resolve(root,'manifest.json'),JSON.stringify(manifest,null,2));copyFileSync(resolve(vendor,'LICENSE'),resolve(root,'LICENSE.txt'));}
