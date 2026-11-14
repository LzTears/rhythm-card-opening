// Export the retained E05 quality17 element directory only. No Godot/runtime writes.
import {readFileSync,writeFileSync} from 'node:fs';import {resolve,dirname} from 'node:path';import {pathToFileURL,fileURLToPath} from 'node:url';import {createHash} from 'node:crypto';
const here=dirname(fileURLToPath(import.meta.url)),vendor='C:/Users/Administrator/.codex/vendor_imports/pixelfx-main';
const {loadEffect,renderFrames,canvas}=await import(pathToFileURL(resolve(vendor,'tools/lib/fxlib.mjs')));const {encodePNG}=await import(pathToFileURL(resolve(vendor,'tools/lib/png.mjs')));
const sha=p=>createHash('sha256').update(readFileSync(p)).digest('hex');
const ramps={E05:{palette:['#102343','#174571','#236ea1','#369dcc','#58cbea','#9de9f5','#dcfbff','#ffffff'],accent:['#102343','#174571','#369dcc','#9de9f5','#ffffff'],sparks:['#dcfbff','#9de9f5','#58cbea','#369dcc']}};
const onTable=(f,w,h,bg)=>{const a=new Uint8ClampedArray(w*h*4);for(let i=0;i<w*h;i++){const c=f.raw[i],l=f.light[i],alpha=(c>>>24)/255;for(let j=0;j<3;j++)a[i*4+j]=Math.min(255,bg[j]*(1-alpha)+(c>>>(j*8)&255)*alpha+(l>>>(j*8)&255));a[i*4+3]=255;}return a;};
export async function exportElement(el){
 if(!['E05'].includes(el))throw Error('Unowned element');const out=resolve(here,'../../',el),src=resolve(out,'source');
 const frost=await import(pathToFileURL(resolve(src,'snowflake-overhead.mjs'))),wave=await import(pathToFileURL(resolve(src,'plasma-wave.mjs')));
 const thrust=await loadEffect('melee/thrust'),spark=await loadEffect('impacts/hit-spark'),f=m=>({meta:m.meta,mod:m});
 const recipes=[{role:'main',fx:f(frost),options:{},pivot:[96,96],body:40,source:'ice/snowflake-burst#overhead-spatial-adaptation',file:'snowflake-overhead.mjs',kind:'Original create/draw and flake/flare/particle/light drawing retained; coordinate anchor and table-plane particle motion adapted. No frames or source times removed.'},
 {role:'wave',fx:f(wave),options:{palette:ramps[el].palette,accent:ramps[el].accent},pivot:[112,100],body:92,source:'explosions/plasma-explosion#complete-shock-rings-track',file:'plasma-wave.mjs',kind:'Original two shock-ring draw tracks, native widths/time. No tilted ring, shell or source lightning. Element palette adaptation.'},
 {role:'path',fx:thrust,options:{palette:ramps[el].palette,sparks:ramps[el].sparks},pivot:[43,42],body:66,source:'melee/thrust#actor-free',file:'upstream/melee-thrust.js.txt',kind:'Complete stock actor-free thrust with element palette. Exact authored from=(43,42), to=(109,42), span66; no geometry/time rewrite.'},
 {role:'contact',fx:spark,options:{palette:ramps[el].palette},pivot:[44,44],body:37,source:'impacts/hit-spark#actor-free',file:'upstream/impacts-hit-spark.js.txt',kind:'Complete stock impact, bright frame0 cross/diamond, chips and light; element palette. Original .5 second source duration.'}];
 const manifest={element:el,catalog:'quality17',scope:'Assets only; no damage, rules, event, runtime, input or save changes.',original_fps:true,split_channels:{color:'raw straight-alpha color, blend_mix',light:'raw additive RGB, blend_add; black transparent'},loop:false,sheets:{},sources:{},rounds:[{round:1,contact:'source/round1-library-candidates.png',decision:'Reject direct side-view frost wall/puddle/cloud; inspect actual library candidates.'},{round:2,contact:'source/round2-overhead-contact.png',decision:'Rejected simplified geometric crystal and fixed star-lobed poison composition; no final PNG uses this candidate.'},{round:3,contact:'source/round3-overhead-contact.png',decision:'Retain stock snowflake drawing; source double shock-ring tracks; irregular oil/foam poison composition; local timing native.'}],limits:['Overhead adaptations are explicitly disclosed, not claimed as unchanged source pixels.','This is asset/contact-sheet inspection, not real Main or FPS/performance validation.','Wave has its original blank trailing time; no duration trimming.'],sheets_count:4,png_count:8};
 const board=canvas(4*250,4*255,[29,28,35,255]);
 for(let ri=0;ri<recipes.length;ri++){
  const q=recipes[ri],r=renderFrames(q.fx,{actor:false,bg:'none',options:q.options}),cols=7,rows=Math.ceil(r.n/cols),color=new Uint8ClampedArray(r.w*cols*r.h*rows*4),light=new Uint8ClampedArray(color.length);
  let edgeColor=0,edgeLight=0,lastColor=0,lastLight=0;
  for(let fi=0;fi<r.n;fi++)for(let y=0;y<r.h;y++)for(let x=0;x<r.w;x++){const i=y*r.w+x,d=((Math.floor(fi/cols)*r.h+y)*r.w*cols+fi%cols*r.w+x)*4,c=r.frames[fi].raw[i],l=r.frames[fi].light[i];color.set([c&255,c>>>8&255,c>>>16&255,c>>>24],d);light.set([l&255,l>>>8&255,l>>>16&255,(l&0xffffff)?255:0],d);if(fi===r.n-1){if(c>>>24)lastColor++;if(l&0xffffff)lastLight++;}if(x===0||y===0||x===r.w-1||y===r.h-1){if(c>>>24)edgeColor++;if(l&0xffffff)edgeLight++;}}
  for(const [channel,pixels]of [['color',color],['light',light]])writeFileSync(resolve(out,q.role+'-'+channel+'.png'),encodePNG(r.w*cols,r.h*rows,pixels));
  const meta={key:q.role==='path'?'thrust_'+el:q.role+'_'+el,source_id:q.source,source_file:'source/'+q.file,source_sha256:sha(resolve(src,q.file)),adaptation:q.kind,size:[r.w,r.h],floor_pivot:q.fx.meta.origin,pivot:q.pivot,columns:cols,rows,frames:r.n,fps:r.fps,source_duration:q.fx.meta.duration,sample_end:(r.n-1)/r.fps,duration:r.n/r.fps,body_radius_px:q.body,options:q.options,color:q.role+'-color.png',light:q.role+'-light.png',color_sha256:sha(resolve(out,q.role+'-color.png')),light_sha256:sha(resolve(out,q.role+'-light.png')),terminal_pixels:{color:lastColor,light:lastLight},outer_edge_pixels_all_frames:{color:edgeColor,light:edgeLight}};
  if(q.role==='path'){meta.path_source_span_px=66;meta.path_from_px=[43,42];meta.path_to_px=[109,42];}
  writeFileSync(resolve(out,q.role+'.json'),JSON.stringify(meta,null,2));manifest.sheets[q.role]=meta;
  const times=q.role==='main'?[0,.2,.5,1.2]:q.role==='wave'?[0,.1,.23,.45]:[0,1/r.fps,.1,.25];
  for(let j=0;j<4;j++){const fi=Math.min(r.n-1,Math.round(times[j]*r.fps)),img=onTable(r.frames[fi],r.w,r.h,j%2?[184,145,93]:[44,40,46]);board.paste(img,r.w,r.h,j*250+4,ri*255+25);board.text(el+' '+q.role+' '+(fi/r.fps).toFixed(3)+'s',j*250+4,ri*255+5,1);}
  console.log(el,q.role,r.n+'f',r.fps+'fps',meta.duration.toFixed(6)+'s','terminal',lastColor,lastLight);
 }
 for(const name of ['source/export.mjs','source/snowflake-overhead.mjs','source/plasma-wave.mjs']){const p=resolve(out,name);try{manifest.sources[name]=sha(p);}catch{}}
 writeFileSync(resolve(src,'round4-final-table-contact.png'),board.png());writeFileSync(resolve(out,'manifest.json'),JSON.stringify(manifest,null,2));
 return manifest;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))await exportElement('E05');
