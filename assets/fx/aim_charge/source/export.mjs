import{mkdirSync,writeFileSync,readFileSync}from'node:fs';import{resolve,dirname,join}from'node:path';import{pathToFileURL,fileURLToPath}from'node:url';import{createHash}from'node:crypto';
const here=dirname(fileURLToPath(import.meta.url)),vendor=process.env.PIXELFX_ROOT??'C:/Users/Administrator/.codex/vendor_imports/pixelfx-main';
const fxlib=await import(pathToFileURL(join(vendor,'tools/lib/fxlib.mjs')));const{encodePNG}=await import(pathToFileURL(join(vendor,'tools/lib/png.mjs')));
const mod=await import(pathToFileURL(join(here,'charge_sparks.mjs'))+'?v='+Date.now());
const round=+(process.argv.find(x=>x.startsWith('--round='))?.split('=')[1]??3),formal=process.argv.includes('--formal');
const out=process.argv.find(x=>x.startsWith('--out='))?.slice(6)??'C:/Users/Administrator/.codex/tmp/aim-charge-20261111';mkdirSync(out,{recursive:true});
const fx={id:'ui/aim-charge-sparks',file:join(here,'charge_sparks.mjs'),mod,meta:mod.meta};
const r=fxlib.renderFrames(fx,{bg:'light',actor:false,options:{round}});
writeFileSync(join(out,'round'+round+'-contact.png'),fxlib.contactSheet(fx,r,{max:16,zoom:3}));
// A tight 4x4 native-resolution atlas, transparent 6+px gutters in every tile.
const atlas=new Uint8ClampedArray(192*192*4);for(let n=0;n<16;n++){const f=r.frames[n].clear;for(let y=0;y<48;y++)atlas.set(f.subarray(y*48*4,(y+1)*48*4),(((n>>2)*48+y)*192+(n%4)*48)*4)}
const png=encodePNG(192,192,atlas);writeFileSync(join(out,'round'+round+'-atlas.png'),png);
const nonempty=r.frames.map(f=>{let n=0;for(let i=3;i<f.clear.length;i+=4)if(f.clear[i])n++;return n});
const bounds=r.frames.map(f=>{let x0=48,y0=48,x1=-1,y1=-1;for(let y=0;y<48;y++)for(let x=0;x<48;x++)if(f.clear[(y*48+x)*4+3]){x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y)}return x1<0?null:[x0,y0,x1,y1]});
const hash=b=>createHash('sha256').update(b).digest('hex');
const again=fxlib.renderFrames(fx,{bg:'light',actor:false,options:{round}});const deterministic=r.frames.every((f,i)=>Buffer.from(f.clear).equals(Buffer.from(again.frames[i].clear)));
const enlarged=fxlib.renderFrames(fx,{bg:'none',margin:24,actor:false,options:{round}});let outside=0;for(const f of enlarged.frames)for(let y=0;y<enlarged.h;y++)for(let x=0;x<enlarged.w;x++)if((x<24||x>=72||y<24||y>=72)&&f.clear[(y*enlarged.w+x)*4+3])outside++;
const stats={round,frames:r.n,fps:r.fps,size:[48,48],pivot:[24,24],nonempty,bounds,deterministic,outside,first_empty:nonempty[0]===0,last_empty:nonempty[15]===0,source_sha256:hash(readFileSync(fx.file)),atlas_sha256:hash(png)};
writeFileSync(join(out,'round'+round+'-stats.json'),JSON.stringify(stats,null,2));
if(!deterministic||outside||nonempty[0]||nonempty[15])throw Error('Authoring contract failed');
if(formal){const root=resolve(here,'..');writeFileSync(join(root,'charge_sparks.png'),png);writeFileSync(join(root,'charge_sparks.json'),JSON.stringify({name:'aim_charge_sparks',texture:'charge_sparks.png',texture_size:[192,192],frame_size:[48,48],columns:4,rows:4,frames:16,fps:30,duration:16/30,source_duration:.5,pivot:[24,24],pivot_normalized:[.5,.5],direction:'right; tail left',loop:false,first_frame_empty:true,last_frame_empty:true,channel:'RGBA color + restrained source light composite',tint:'neutral white; host element tint',sampling:'linear, no mipmaps, no repeat; clamp UV to each tile',geometry:'local glint only; no ring or attack radius',runtime_contract:'Host places 2-3 sparse particles at actual charge progress head/tangent. Texture animation clock does not change gameplay progress.',source_sha256:stats.source_sha256,png_sha256:stats.atlas_sha256},null,2));}
console.log(JSON.stringify(stats));