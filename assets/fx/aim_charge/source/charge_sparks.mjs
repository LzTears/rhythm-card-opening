// Original small charge-head glint, using pixelfx's pure-effect/Painter contract.
// Choreography references: ui/countdown burning head and pickups/key-glint sparkle.
// pixelfx / Sprite Fusion, MIT, Copyright (c) 2026 Patch and Hugo Duprez.
export const meta={name:'Aim charge sparks',desc:'One tiny white glint with a thin trailing whisker and two dim grains; drawn at the true charge head by the host.',tags:['ui','charge','spark','one-shot'],size:[48,48],origin:[24,24],duration:0.5,loop:false,fps:30,bg:'light',options:{round:3,palette:['#858585','#b8b8b8','#ededed','#ffffff'],seed:17}};
const clamp=(x,a=0,b=1)=>Math.max(a,Math.min(b,x));
const rgb=h=>{const n=parseInt(h.replace('#',''),16);return (255<<24)|((n&255)<<16)|(n&0xff00)|((n>>>16)&255)};
const bell=u=>Math.sin(Math.PI*clamp(u));
export function draw(p,t,o){
 if(t<=0||t>=meta.duration)return;
 const u=t/meta.duration,round=o.round??3,C=(o.palette??meta.options.palette).map(rgb);
 const k=Math.pow(bell(u),1.35),x=-1+5*(1-Math.pow(1-u,2)),y=-.8*Math.sin(u*Math.PI);
 const thick=round===1?1.8:round===2?1.15:.78;
 const length=(round===1?18:round===2?14:12)*Math.pow(bell(u),.75);
 // Thin tapered wisp: no ring, smoke, actor, random speckle or attack geometry.
 for(let j=0;j<24;j++){
  const q=j/23,xx=x-length*(1-q),yy=y+1.4*Math.sin(q*Math.PI)*Math.sin(u*4+0.3);
  const a=k*Math.pow(q,1.8)*(round===1?.7:.52);
  p.disc(xx,yy,thick*(.2+.6*q),C[q>.82?2:1],a);
 }
 // Light is deliberately restrained over the bright A2 wood surface.
 p.glow(x,y,round===1?10:round===2?6.5:5,C[2],k*(round===1?.42:round===2?.22:.045));
 const arm=(round===1?4.7:round===2?3.6:2.8)*k;
 p.beam(x-arm,y,x+arm,y,.62,C[2],k*.9);
 p.beam(x,y-arm*.7,x,y+arm*.7,.65,C[2],k*.8);
 p.disc(x,y,round===3?.55+.65*k:.85+1.05*k,C[3],k);
 // Two low-energy fragments, staggered; these are not three equally bright stars.
 for(let i=0;i<2;i++){
  const v=(u-(i===0?.12:.28))/(i===0?.65:.58);if(v<=0||v>=1)continue;
  const a=bell(v)*(round===1?.9:round===2?.63:.45);
  const xx=x-(3.5+i*4.5)*(1-v),yy=y+(i===0?-1:1)*(2+i+v*2);
  p.disc(xx,yy,round===1?1.1:.65,C[2],a);
  if(round!==3)p.glow(xx,yy,3,C[2],a*.12);
 }
}