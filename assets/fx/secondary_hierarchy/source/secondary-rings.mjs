// Original top-down secondary rings for 圆卡旋风, authored with pixelfx 0.3.0.
// Ring lighting/choreography references: pixelfx plasma-explosion and mana-burst.
// No original primary source is edited or truncated. Color and light stay separate.
import { fit, ease, TAU, WHITE } from 'file:///C:/Users/Administrator/.codex/vendor_imports/pixelfx-main/src/core/index.js';

export const palettes = {
  E01:['#28180d','#60422a','#a97942','#d8ad65','#f5d18b','#fff0c0','#fff9df'],
  E02:['#071b29','#164856','#287c92','#52bbd2','#8ce3ef','#c9f6ff','#f0fdff'],
  E05:['#18233e','#365178','#6389ae','#90b9d2','#bfdeea','#e2f3f5','#f7ffff'],
};

export function recipe(element, mode, round=1) {
  if (!palettes[element] || !['ripple','echo'].includes(mode)) throw Error('Unknown secondary recipe');
  const echo=mode==='echo';
  const duration=echo ? 0.6 : 1/3;
  const meta={name:element+' '+mode,desc:echo?'A tiny contact glint confirms the hit; broken ringlets contract, then a hollow pressure ring snaps outward and dissolves.':'A short, hollow top-down pressure ripple follows a local contact; the stepped rim breaks apart without filling its center.',tags:['topdown','secondary','ring','one-shot'],size:[128,128],origin:[64,64],duration,loop:false,fps:30,bg:'dark',options:{palette:palettes[element],seed:7}};
  function draw(p,t,o) {
    if (t<0 || t>=duration-1e-8) return;
    const C=fit(o.palette,7), E=element==='E02', I=element==='E05';
    const gather=echo ? 4/30 : 0;
    // The real echo has already struck. Confirm it immediately; do not await the ring release.
    if (echo && t<2/30) {
      const k=1-t/(2/30);
      p.line(-2,0,2,0,C[6],k);p.line(0,-2,0,2,WHITE,k);
      p.glow(0,0,5,C[4],0.3*k);
    }
    if (echo && t<gather) {
      const q=t/gather, r=26-18*ease.inCubic(q), power=0.45+q*0.5;
      for(let i=0;i<6;i++) {
        const a=i*TAU/6+0.12;
        p.arc(0,0,r,1.4,a,a+0.62,C[4],power);
        p.arc(0,0,r+2,1,a+0.02,a+0.38,C[2],power*.65);
      }
      p.glowRing(0,0,r,2.5,C[3],.16*power);
      return;
    }
    const q=(t-gather)/(duration-gather), spread=ease.outCubic(q);
    const r=8+44*spread, power=Math.pow(1-q,echo?1.25:1.05);
    const count=I?12:10, gap=round>=2 ? .09 : .055;
    for(let i=0;i<count;i++) {
      const a=i*TAU/count+(E?0.04:0), b=(i+1)*TAU/count-gap;
      if(q>.68 && (i+Math.floor(q*15))%3===0) continue;
      const rr=r+(E?(i%2?-.5:.5):0), hot=q<.19 && i>count/2 && i<count*.92;
      p.arc(0,0,rr,Math.max(1,2.0*(1-q)),a,b,hot?C[6]:C[4],power);
      p.arc(0,0,rr-1.5,1,a+.025,b-.025,C[2],power*.6);
      if(i%2===0 && q>.08 && q<.7) {
        const x=Math.cos(a)*rr,y=Math.sin(a)*rr;
        if(I) {
          const len=2+3*(1-q);p.line(x,y,x+Math.cos(a)*len,y+Math.sin(a)*len,C[5],power*.8);
          p.px(x-Math.sin(a),y+Math.cos(a),C[2]);
        } else if(E) {
          const a2=a+.035,p2=[Math.cos(a2)*(rr+2),Math.sin(a2)*(rr+2)];
          p.line(x,y,...p2,C[5],power);p.line(...p2,Math.cos(a+.08)*rr,Math.sin(a+.08)*rr,C[4],power);
        } else {
          p.arc(0,0,rr+2.2,1,a,a+.12,C[3],power*.75);
        }
      }
    }
    // Glow follows the rim; no large soft pool obscures the mouse or the pack below.
    p.glowRing(0,0,r,round>=3?2.6:3.4,C[3],(round>=3?.20:.27)*power);
    if(echo && q>.06 && q<.72) {
      const rear=5+34*ease.outCubic(Math.max(0,(q-.06)/.94));
      for(let i=0;i<6;i++) {
        const a=i*TAU/6+.18;
        p.arc(0,0,rear,1,a,a+.45,C[3],power*.5);
      }
    }
  }
  return {meta,draw};
}
