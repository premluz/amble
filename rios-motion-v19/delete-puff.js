(function(global){
'use strict';
const defaults={duration:1.25,count:13,spread:86,lift:34,size:22,curl:22,stagger:.12,fadeStart:.42,scale:1,seed:7,background:'#191919',color:'#EDEBE5',shadow:'#A9A498',highlight:'#FFFFFF',objectColor:'#769AF5',showObject:true,transparent:false};
const clamp=x=>Math.max(0,Math.min(1,x)),smooth=x=>{x=clamp(x);return x*x*(3-2*x);},ease=x=>1-Math.pow(1-clamp(x),3),mix=(a,b,t)=>a+(b-a)*t;
const random=(seed,n)=>{const x=Math.sin(seed*71.3+n*127.1)*43758.5453;return x-Math.floor(x);};
function frame(seconds,options={}){
 const c={...defaults,...options},t=clamp(seconds/c.duration),clouds=[];
 for(let i=0;i<Math.round(c.count);i++){
  const r=n=>random(c.seed,i*19+n),birth=.09+r(1)*c.stagger,age=clamp((t-birth)/(1-birth));
  if(t<=birth||age>=1)continue;
  const angle=i/c.count*Math.PI*2+(r(2)-.5)*.26,travel=ease(age),drift=Math.sin(age*Math.PI)*c.curl*(r(3)-.5);
  const radius=(15+c.spread*travel)*( .85+r(4)*.3);
  const x=480+Math.cos(angle)*radius+drift,y=270+Math.sin(angle)*radius*.72-c.lift*age*age;
  const size=c.size*(.65+r(5)*.55)*smooth(age/.11)*(1-.84*smooth((age-.2)/.8));
  const opacity=(1-smooth((age-c.fadeStart)/(1-c.fadeStart)));
  const lobes=Array.from({length:5},(_,j)=>{const a=j/5*Math.PI*2;return {x:Math.cos(a)*size*.57,y:Math.sin(a)*size*.38,r:size*(.57+random(c.seed,i*31+j)*.22)};});
  clouds.push({x,y,size,opacity,lobes,rotation:(r(6)-.5)*30+age*(r(7)-.5)*35});
 }
 return {clouds,objectOpacity:1-smooth((t-.04)/.16),objectScale:mix(1,.35,smooth(t/.2)),stage:t<.1?'Ready':t<.26?'Puff':t<.68?'Drift':'Clear',scale:c.scale,config:c};
}
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&apos;'}[c]));
function svgAt(seconds,options={}){
 const f=frame(seconds,options),c=f.config;
 const lobes=(p,dy,shrink)=>p.lobes.map(l=>`<ellipse cx="${l.x}" cy="${l.y+dy*p.size}" rx="${l.r*shrink}" ry="${l.r*.78*shrink}"/>`).join('');
 return `<svg xmlns="http://www.w3.org/2000/svg" width="960" height="540" viewBox="0 0 960 540" role="img" aria-label="Procedural delete puff">${c.transparent?'':`<rect width="960" height="540" fill="${esc(c.background)}"/>`}<g transform="translate(480 270) scale(${f.scale}) translate(-480 -270)">${c.showObject?`<g opacity="${f.objectOpacity}" transform="translate(480 270) scale(${f.objectScale})"><rect x="-68" y="-24" width="136" height="48" rx="18" fill="${esc(c.objectColor)}"/><path d="M-43 -4h62M-43 6h40" fill="none" stroke="${esc(c.highlight)}" stroke-width="3" stroke-linecap="round" opacity=".7"/><circle cx="42" r="4" fill="${esc(c.highlight)}" opacity=".75"/></g>`:''}${f.clouds.map(p=>`<g opacity="${p.opacity}" transform="translate(${p.x} ${p.y}) rotate(${p.rotation})"><g fill="${esc(c.shadow)}">${lobes(p,.16,1)}</g><g fill="${esc(c.color)}">${lobes(p,0,.98)}</g><g fill="${esc(c.highlight)}">${p.lobes.filter((_,i)=>i===3||i===4).map(l=>`<ellipse cx="${l.x}" cy="${l.y-p.size*.13}" rx="${l.r*.84}" ry="${l.r*.44}"/>`).join('')}</g></g>`).join('')}</g></svg>`;
}
class DeletePuff{
 constructor(element,options={}){this.element=element;this.options={...defaults,...options};this.time=0;this.playing=false;this.seek(0);}
 configure(options){this.options={...this.options,...options};this.seek(this.time);}
 seek(seconds){this.time=Math.max(0,Math.min(this.options.duration,seconds));this.element.innerHTML=svgAt(this.time,this.options);this.onupdate?.(this.time,frame(this.time,this.options));}
 play(){if(this.playing)return;if(this.time>=this.options.duration)this.seek(0);this.playing=true;let last=performance.now();const tick=now=>{if(!this.playing)return;this.seek(this.time+(now-last)/1000);last=now;if(this.time>=this.options.duration){this.pause();this.oncomplete?.();return;}this.raf=requestAnimationFrame(tick);};this.raf=requestAnimationFrame(tick);}
 pause(){this.playing=false;cancelAnimationFrame(this.raf);this.onplaystate?.(false);}
 replay(){this.pause();this.seek(0);this.play();}
 destroy(){this.pause();this.element.innerHTML='';}
 svg(){return svgAt(this.time,this.options);}
}
global.DeletePuff=DeletePuff;global.DeletePuffTools={defaults,frame,svgAt};
})(typeof window==='undefined'?globalThis:window);
