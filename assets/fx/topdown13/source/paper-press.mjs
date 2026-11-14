// Original top-down paper impact; choreography informed by pixelfx sword-slash,
// frost-nova and small-explosion. Uses pixelfx core (MIT, Patch / Hugo Duprez).
import {Particles,P,Rng,fit,clamp,smooth,ease,TAU} from './vendor_snapshot/src/core/index.js';
export const RELEASE=.10;
export const meta={name:'Paper press — native top-down',desc:'A paper pressure burst opens unevenly, cracks and broken arcs run across the tabletop, wrapper chips hop and settle in every direction.',
  tags:['impact','paper','top-down','one-shot'],size:[192,192],origin:[96,96],duration:1.4,fps:30,loop:false,bg:'light',
  options:{palette:['#351b12','#653719','#a65d25','#cf8a39','#efbd72','#fff0c6','#fffce8'],seed:71}};
const OUTLINE=[[-14,-8],[-4,-16],[10,-10],[16,1],[7,12],[-8,10],[-17,1]];
const FLAPS=[[[-8,-6],[-28,-26],[-21,-12],[-14,-2]],[[-11,4],[-34,7],[-28,15],[-14,13]],[[10,3],[30,14],[28,3],[17,-4]]];
const FACETS=[[[-10,-6],[-2,-12],[0,-2],[-7,3]],[[4,-7],[12,-3],[8,4],[2,1]],[[-3,6],[7,3],[9,10],[-7,9]]];
const rotate=(x,y,a)=>[x*Math.cos(a)-y*Math.sin(a),x*Math.sin(a)+y*Math.cos(a)];

export function create(o){
  const C=fit(o.palette,7),R=new Rng(o.seed),ps=new Particles({rng:R,ground:()=>Infinity});
  const cracks=[-.19,.91,2.08,3.22,4.77].map((a,i)=>{
    a+=R.range(-.19,.19);const length=R.range(22,46),points=[[Math.cos(a)*10,Math.sin(a)*10]];
    for(let j=1;j<5;j++){const d=length*j/4,n=R.range(-3,3);points.push([Math.cos(a)*d-Math.sin(a)*n,Math.sin(a)*d+Math.cos(a)*n]);}
    return {points,length,a,delay:R.range(0,.025),fork:i%2===0};
  });
  const arcs=Array.from({length:4},(_,i)=>({a:[-.48,1.15,2.83,4.65][i]+R.range(-.16,.16),span:R.range(.30,.72),delay:R.range(0,.07),reach:R.range(49,72),w:R.range(1.9,3.0)}));
  const papers=Array.from({length:20},(_,i)=>{const a=R.range(0,TAU),v=R.range(100,205);return{x:Math.cos(a)*5,y:Math.sin(a)*5,z:0,vx:Math.cos(a)*v,vy:Math.sin(a)*v,vz:R.range(95,145),a:R.range(0,TAU),spin:R.range(-18,18),w:R.range(3.0,5.4),h:R.range(1.6,3.2),delay:RELEASE+R.range(0,.035),age:0,life:R.range(.60,.90),bounced:false,color:i%4===0?C[3]:i%3===0?C[5]:C[6]};});
  let t=0,released=false;
  const drawCracks=p=>{
    const age=t-RELEASE;if(age<0)return;const fade=1-smooth(.31,.77,age);
    for(const c of cracks){const u=clamp((age-c.delay)/.15),count=Math.max(1,Math.ceil(u*4));
      for(let j=1;j<=Math.min(4,count);j++){const a=c.points[j-1],b=c.points[j];p.line(a[0],a[1]+1,b[0],b[1]+1,C[3],fade*.8);p.line(a[0],a[1],b[0],b[1],C[0],fade);}
      if(c.fork&&age>.12){const q=c.points[2],d=12+u*8;p.line(q[0],q[1],q[0]+Math.cos(c.a+.52)*d,q[1]+Math.sin(c.a+.52)*d,C[1],fade*.8);}
    }
  };
  return{
    update(dt){
      t+=dt;
      if(!released&&t+1e-8>=RELEASE){released=true;
        for(let i=0;i<19;i++){const a=R.range(0,TAU),d=R.range(11,20),v=R.range(60,125);ps.spawn(P.DUST,Math.cos(a)*d,Math.sin(a)*d,Math.cos(a)*v,Math.sin(a)*v,R.range(.28,.55),C[3],R.range(3.5,6.3));}
        for(let i=0;i<14;i++){const a=R.range(0,TAU),v=R.range(90,170);ps.spawn(P.MOTE,Math.cos(a)*8,Math.sin(a)*8,Math.cos(a)*v,Math.sin(a)*v,R.range(.14,.31),C[5],R.range(.7,1.1));}
      }
      ps.update(dt);
      for(const b of papers){if(t<b.delay)continue;b.age+=dt;b.x+=b.vx*dt;b.y+=b.vy*dt;b.vx*=Math.exp(-3.2*dt);b.vy*=Math.exp(-3.2*dt);b.z+=b.vz*dt;b.vz-=780*dt;b.a+=b.spin*dt;
        if(b.z<0){b.z=0;if(!b.bounced){b.vz=Math.abs(b.vz)*.20;b.bounced=true;b.spin*=.35;}else{b.vz=0;b.spin*=Math.exp(-10*dt);}}
      }
    },
    drawBack(p){if(t>=meta.duration)return;drawCracks(p);ps.draw(p,'back');
      for(const b of papers){if(t<b.delay||b.age>b.life)continue;const fade=1-smooth(b.life-.20,b.life,b.age);p.ellipse(b.x+1+b.z*.13,b.y+2+b.z*.11,b.w*.9,b.h*.7,C[0],fade*(b.z>1?.18:.28));}
    },
    draw(p){
      if(t>=meta.duration)return;const h=Math.max(0,t-RELEASE);
      if(t+1e-8<RELEASE){const u=clamp(t/RELEASE);for(const a of [.18,1.8,3.45,5.22]){const r=24-13*u;p.line(Math.cos(a)*r,Math.sin(a)*r,Math.cos(a)*(r+5),Math.sin(a)*(r+5),C[1],u*.8);p.dot(Math.cos(a)*(r-1),Math.sin(a)*(r-1),C[5],u); }return;}
      if(h<.135 && o.core!==false){const sc=h<.020?.72:h<.060?1.08:1.15,fade=h<.060?1:1-smooth(.060,.135,h);
        const travel=Math.max(0,h-.025)*90;
        for(const flap of FLAPS){const cx=flap.reduce((v,q)=>v+q[0],0)/flap.length,cy=flap.reduce((v,q)=>v+q[1],0)/flap.length,L=Math.hypot(cx,cy);
          const points=flap.map(([x,y])=>[x*sc+cx/L*travel,y*sc+cy/L*travel]);p.poly(points,C[0],fade);p.poly(points.map(([x,y])=>[x*.94,y*.94]),C[3],fade);p.poly(points.map(([x,y])=>[x*.82,y*.82]),h<.060?C[6]:C[4],fade);}
        if(h<.020){p.poly(OUTLINE.map(([x,y])=>[x*sc,y*sc]),C[1]);p.poly(OUTLINE.map(([x,y])=>[x*sc*.82,y*sc*.82]),C[6]);}
        else for(const facet of FACETS){const cx=facet.reduce((v,q)=>v+q[0],0)/facet.length,cy=facet.reduce((v,q)=>v+q[1],0)/facet.length,L=Math.max(1,Math.hypot(cx,cy));
          const points=facet.map(([x,y])=>[x*sc+cx/L*travel,y*sc+cy/L*travel]);p.poly(points.map(([x,y])=>[x+1,y+1]),C[1],fade);p.poly(points,h<.060?C[6]:C[5],fade);}
        p.glow(0,0,32,C[4],.15*fade);
      }
      for(const s of arcs){const u=(h-s.delay)/.35;if(u<=0||u>=1)continue;const radius=14+(s.reach-14)*ease.outCubic(u),a=1-smooth(.45,1,u),width=Math.max(.8,s.w*(1-u*.55));
        p.arc(0,0,radius,width+1.2,s.a,s.a+s.span,C[1],a);p.arc(0,0,radius-.8,width*.55,s.a+.015,s.a+s.span-.025,u<.3?C[6]:C[5],a);}
      ps.draw(p,'front');
      for(const b of papers){if(t<b.delay||b.age>b.life)continue;const fade=1-smooth(b.life-.20,b.life,b.age),lift=1+b.z*.012,fold=.45+.55*Math.abs(Math.cos(b.a*.75));
        const corners=[[-b.w,-b.h],[b.w,-b.h*.6],[b.w*.65,b.h],[-b.w*.82,b.h*.7]].map(([x,y])=>{const q=rotate(x*lift,y*fold*lift,b.a);return[b.x+q[0],b.y+q[1]];});
        p.poly(corners.map(([x,y])=>[x+1,y+1]),C[1],fade);p.poly(corners,b.color,fade);const q=rotate(b.w*.7,0,b.a);p.line(b.x-q[0],b.y-q[1],b.x+q[0],b.y+q[1],C[3],fade*.65);
      }
    }
  };
}
