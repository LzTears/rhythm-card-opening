// Reproducible isolated export. Writes only secondary_hierarchy and the chosen QA directory.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {recipe} from './secondary-rings.mjs';
const here=dirname(fileURLToPath(import.meta.url)), out=resolve(here,'..');
const vendor='C:/Users/Administrator/.codex/vendor_imports/pixelfx-main';
const {renderFrames,contactSheet}=await import(pathToFileURL(resolve(vendor,'tools/lib/fxlib.mjs')));
const {encodePNG}=await import(pathToFileURL(resolve(vendor,'tools/lib/png.mjs')));
const round=Number(process.argv[2]??3), qa=resolve(process.argv[3]??'C:/Users/Administrator/.codex/tmp/secondary-hierarchy',`round${round}`);
mkdirSync(qa,{recursive:true});
const source=resolve(here,'secondary-rings.mjs');
const sha=p=>createHash('sha256').update(readFileSync(p)).digest('hex');
const manifest={version:1,round,art_direction:'Fine 16-bit top-down hollow rims for the dark wooden desktop. Immediate contact confirmation, short secondary wave, separate contraction→pulse echo. No opaque blast or global pool.',runtime_contract:'Independent authored secondary assets; all own frames, endpoint, native 30FPS and dual color/mix + light/add channels retained. Does not edit any primary or existing wave/path/contact source.',reference_ids:['explosions/plasma-explosion','arcane/mana-burst'],sheets:{}};
for(const element of ['E01','E02','E05']) for(const mode of ['ripple','echo']) {
  const mod=recipe(element,mode,round), fx={id:`secondary_hierarchy/${mode}_${element}`,file:source,mod,meta:mod.meta};
  const r=renderFrames(fx,{actor:false,bg:'none'}),columns=5,rows=Math.ceil(r.n/columns),width=r.w*columns,height=r.h*rows;
  const color=new Uint8ClampedArray(width*height*4),light=new Uint8ClampedArray(color.length);
  for(let f=0;f<r.n;f++)for(let y=0;y<r.h;y++)for(let x=0;x<r.w;x++) {
    const p=y*r.w+x,d=((Math.floor(f/columns)*r.h+y)*width+f%columns*r.w+x)*4,c=r.frames[f].raw[p],l=r.frames[f].light[p];
    color.set([c&255,c>>>8&255,c>>>16&255,c>>>24],d);
    light.set([l&255,l>>>8&255,l>>>16&255,(l&0xffffff)?255:0],d);
  }
  const folder=resolve(out,element);mkdirSync(folder,{recursive:true});
  for(const [channel,pixels]of [['color',color],['light',light]])writeFileSync(resolve(folder,`${mode}-${channel}.png`),encodePNG(width,height,pixels));
  const meta={key:`${mode}_${element}`,role_hint:mode,element,source_id:fx.id,source_file:'source/secondary-rings.mjs',source_sha256:sha(source),size:[r.w,r.h],pivot:mod.meta.origin,columns,rows,frames:r.n,fps:r.fps,source_duration:mod.meta.duration,sample_end:(r.n-1)/r.fps,duration:r.n/r.fps,body_radius_px:56,color:`${mode}-color.png`,light:`${mode}-light.png`,color_sha256:sha(resolve(folder,`${mode}-color.png`)),light_sha256:sha(resolve(folder,`${mode}-light.png`)),immediate_contact_seconds:mode==='echo'?2/30:0,contraction_seconds:mode==='echo'?4/30:0};
  writeFileSync(resolve(folder,mode+'.json'),JSON.stringify(meta,null,2)+'\n');
  const contact=contactSheet(fx,renderFrames(fx,{actor:false,bg:'dark'}),{max:12,zoom:2});
  writeFileSync(resolve(qa,`${element}-${mode}-contact.png`),contact);
  manifest.sheets[meta.key]=meta;
  console.log(meta.key,`${r.n}f/${r.fps}FPS`,meta.duration+'s');
}
writeFileSync(resolve(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
writeFileSync(resolve(qa,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
