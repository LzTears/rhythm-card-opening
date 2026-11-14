// Radial tabletop adaptation of pixelfx ice/frost-nova and ice/snowflake-burst.
// Faceted crystal shading recipe derives from Sprite Fusion ice, MIT, Copyright (c) 2026 Hugo Duprez.
import {fit,Rng,clamp,smooth,ease,TAU,rand} from 'file:///C:/Users/Administrator/.codex/vendor_imports/pixelfx-main/src/core/index.js';
export const palette=['#102343','#174571','#236ea1','#369dcc','#58cbea','#9de9f5','#dcfbff','#ffffff'];
export function make(role='main',round=2){
 const D=role==='contact'?.5:3.4,S=role==='contact'?128:224;
 const meta={name:'Frost '+role+' overhead',size:[S,S],origin:[S/2,S/2],duration:D,loop:false,fps:30,bg:'none',options:{palette,seed:4}};
 return {meta,draw(p,t,o){
  if(t>=D)return;const C=fit(o.palette,8),R=new Rng(o.seed),fade=1-smooth(role==='contact'?.28:2.1,D,t),burst=role==='contact'?0:.16;
  const V=(a,u,v)=>[Math.cos(a)*u-Math.sin(a)*v,Math.sin(a)*u+Math.cos(a)*v];
  const crystal=(a,r,L,w,g,phase=0)=>{if(g<=0)return;const pt=(u,v)=>V(a,r+u*g,v*g);const tip=pt(L,0),back=pt(-w*.25,0),left=pt(L*.26,-w),right=pt(L*.22,w),ridge=pt(L*.55,-w*.15);
   p.poly([back,left,tip,right],C[0]);p.poly([back,left,ridge,tip],C[3]);p.poly([back,ridge,tip,right],C[1]);p.poly([back,ridge,right],C[2]);p.line(...left,...tip,C[5]);p.line(...back,...ridge,C[4]);p.line(...ridge,...tip,C[6]);
   if(phase<.35)p.line(...pt(L*.25,-w*.45),...pt(L*.62,-w*.17),C[7]);
  };
  if(role==='contact'){
   const k=clamp(t/.13),out=1-smooth(.06,.43,t);for(let j=0;j<11;j++){const a=j*TAU/11+R.range(-.12,.12),r=(3+R.range(8,23)*ease.outCubic(k));crystal(a,r,R.range(4,10),R.range(1.4,3),out,j%3*.3);}
   if(t<.11){p.glow(0,0,17,C[4],.55*(1-t/.11));for(let j=0;j<6;j++){const q=V(j*TAU/6,8*(1-t/.11),0);p.line(0,0,...q,C[6]);}}return;
  }
  const k=clamp((t-burst)/.58),fr=82*ease.outCubic(k),out=fade;
  if(t<burst){const r=3+7*(t/burst);for(let j=0;j<6;j++){const a=j*TAU/6+t*4,q=V(a,r,0);p.line(0,0,...q,C[5]);}p.glow(0,0,15,C[4],.42);return;}
  // Original three-ring recipe reorganized in the table plane, with no side-view y compression.
  if(role==='main'){
   const base=1-smooth(1.9,2.9,t);for(let y=-49;y<=49;y++)for(let x=-49;x<=49;x++){const r=Math.hypot(x,y),a=Math.atan2(y,x);if(r>fr*.67||r>48+Math.sin(a*9+1)*2)continue;const n=rand(x,y,19),rad=r/50;if(n<.12*base&&rad>.3)p.dot(x,y,C[2],base*.6);if(Math.abs(Math.sin(a*6+rad*5))<.035&&rad>.18)p.dot(x,y,C[4],base*.7);}
   for(let ring=2;ring>=0;ring--){const n=[8,11,15][ring],r=[3,23,42][ring];for(let j=0;j<n;j++){const a=j*TAU/n+ring*.37+R.range(-.12,.12),L=[25,21,12][ring]*R.range(.8,1.18),w=[6,5,3.5][ring]*R.range(.8,1.2),delay=burst+ring*.1+R.range(0,.055),g=ease.outBack(clamp((t-delay)/.15),1.6)*(1-smooth(1.95+ring*.13,2.65+ring*.13,t));crystal(a,r,L,w,g,(t*.9+j*.21)%1);}}
   const core=1-smooth(.18,.44,t);if(core>0){p.glow(0,0,26,C[4],.35*core);for(let i=0;i<6;i++){const q=V(i*TAU/6,14*core,0);p.line(0,0,...q,C[6]);}}
  }
  // Broken, faceted frost wave instead of a flat perspective ellipse.
  if(k>0&&k<1){const aout=1-smooth(.6,1,k);for(let j=0;j<90;j++){const a=j*TAU/90,r=fr+Math.sin(a*13+o.seed)*1.5,q=V(a,r,0);if(j%9!==0)p.dot(...q,C[j%5===0?6:4],aout);if(j%3===0){const q2=V(a,r-3,0);p.line(...q2,...q,C[2]);}}p.glowRing(0,0,fr,round===2?4:2.7,C[4],(round===2?.16:.11)*aout);}
  for(let j=0;j<(role==='wave'?36:25);j++){const a=j*2.399+R.range(-.13,.13),speed=R.range(40,96),life=R.range(.8,1.8),age=t-burst-R.range(0,.12);if(age<0||age>life)continue;const rr=10+speed*(1-Math.exp(-age*2.7))/2.7,sz=R.range(1.3,3.2)*(1-age/life),q=V(a,rr,0);if(sz>.8){const A=a+age*R.range(-2,2),ca=Math.cos(A),sa=Math.sin(A);p.poly([[q[0]+ca*sz*2,q[1]+sa*sz*2],[q[0]-sa*sz,q[1]+ca*sz],[q[0]-ca*sz,q[1]-sa*sz]],C[j%3?4:6]);p.px(q[0],q[1],C[2]);}}
  if(t>1&&t<3.2)for(let j=0;j<24;j++){const a=j*2.4,rr=R.range(15,69),tw=Math.sin(t*7+j*1.7);if(tw>.9){const q=V(a,rr,0);p.dot(...q,C[5],out);if(j%5===0){p.dot(q[0]+1,q[1],C[3],out);p.dot(q[0],q[1]+1,C[3],out);}}}
 }};
}
