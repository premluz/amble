(function(global){
'use strict';
const defaults={duration:11.2,ending:'out',amplitude:24,wavelength:610,spacing:40,stroke:14,individuality:.6,dots:.75,tailCount:4,tailSpacing:35,tailSize:9,tailTaper:.9,tailStagger:.13,exitStagger:.16,formationStagger:.12,scaleStagger:.06,letterStagger:.05,letterFade:.8,frontDots:.65,hold:1,tailFollowDelay:.3,entranceFrequency:2.5,exitFrequency:3.5,exitDepth:7,dropRate:6,morphLead:.8,formationDuration:.85,dispersionDuration:3.5,bubbleLinger:3,bubbleEmission:.7,bubbleRate:6,bubbleStagger:.6,bubbleRandomness:1,linkWaves:false,bubbleTravel:135,bubbleSpread:95,textRevealLead:.75,textExitOffset:0,textExitFade:.65,logoGap:26,fontWeight:600,fontFamily:'arial',letterSpacing:0,assembledLogoScale:1,colors:['#9950E9','#91A5FF','#19A59F'],theme:'dark',background:'#191919',ink:'#F3F0EB',wordmark:'Rios'};
const fontStacks={system:'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',arial:'Arial, Helvetica, sans-serif',helvetica:'"Helvetica Neue", Helvetica, Arial, sans-serif',georgia:'Georgia, "Times New Roman", serif',trebuchet:'"Trebuchet MS", Arial, sans-serif',mono:'"Courier New", monospace'};
const fontMetrics={system:{R:53,i:19,o:44,s:39},arial:{R:53,i:18,o:43,s:40},helvetica:{R:52,i:17,o:42,s:38},georgia:{R:56,i:21,o:47,s:40},trebuchet:{R:55,i:21,o:44,s:40},mono:{R:45.6,i:45.6,o:45.6,s:45.6}};
const clamp=x=>Math.max(0,Math.min(1,x)),lerp=(a,b,t)=>a+(b-a)*t,smooth=x=>{x=clamp(x);return x*x*x*(x*(x*6-15)+10);};
const phase=(t,a,b)=>smooth((t-a)/(b-a));
function config(c={}){const result={...defaults,...c,colors:[...(c.colors||defaults.colors)]};if(c.theme==='light'){if(c.background===undefined)result.background='#F3F1EF';if(c.ink===undefined)result.ink='#242321';}else if(c.theme==='dark'){if(c.background===undefined)result.background='#191919';if(c.ink===undefined)result.ink='#F3F0EB';}result.entranceFrequency=c.entranceFrequency??(c.wavelength?960/c.wavelength:defaults.entranceFrequency);result.exitFrequency=c.exitFrequency??(c.exitWavelength?960/c.exitWavelength:defaults.exitFrequency);result.wavelength=960/result.entranceFrequency;result.exitWavelength=960/(result.linkWaves?result.entranceFrequency:result.exitFrequency);return result;}
function point(x,time,c,lane,blend=0,u=0){
  const k=2*Math.PI/c.wavelength, angle=k*(x-480)-time*.43;
  const a=lerp(c.amplitude,3.4,blend), frequency=lerp(k,2*Math.PI/88,blend);
  const theta=lerp(angle,u*Math.PI*1.5+.3,blend);
  const y=270+a*Math.sin(theta),slope=a*frequency*Math.cos(theta);
  const offset=(lane-1)*lerp(c.spacing,21,blend),norm=Math.sqrt(1+slope*slope);
  return [x-offset*slope/norm,y+offset/norm];
}
function frame(seconds,options={}){
 const c=config(options),scaleStart=3.4-c.morphLead;
 const formationEnd=Math.max(scaleStart+c.formationDuration+.1+2*c.scaleStagger,scaleStart+c.formationDuration+2*c.formationStagger,3.4+2*.12*c.individuality);
 const letterStart=Math.max(scaleStart,formationEnd+.08-c.textRevealLead);
 const bubbleEnd=Math.max(3.4+.24*c.individuality,scaleStart+c.formationDuration)+2*c.bubbleStagger+c.bubbleEmission+c.bubbleLinger;
 const holdEnd=Math.max(letterStart+c.letterFade+(c.wordmark.length-1)*c.letterStagger+c.hold*.65,bubbleEnd);
 const assemblyEnd=Math.max(formationEnd,letterStart+c.letterFade+(c.wordmark.length-1)*c.letterStagger);
 const lettersOutStart=holdEnd+c.textExitOffset;
 const lettersOutEnd=lettersOutStart+c.textExitFade+(c.wordmark.length-1)*c.letterStagger;
 const waveExitStart=holdEnd;
 const scoreEnd=Math.max(lettersOutEnd,waveExitStart+2*c.exitStagger+c.tailFollowDelay+c.dispersionDuration)+.1;
 const t=clamp(seconds/c.duration)*scoreEnd,pass=t<2.2?0:1;
 const paths=[],dots=[];
 for(let lane=0;lane<3;lane++){
   const lag=lane*.12*c.individuality,arrival=phase(t-lag,2.2,3.4);
   // Entrance is a full river pass. Logo formation is a separate, late beat.
   const formationStart=scaleStart+lane*c.formationStagger;
   const settle=phase(t,formationStart,formationStart+c.formationDuration);
   const shrink=phase(t,scaleStart+lane*c.scaleStagger,scaleStart+lane*c.scaleStagger+c.formationDuration+.1);
   const exitStart=waveExitStart+lane*c.exitStagger;
   const exit=c.ending==='out'?phase(t,exitStart,exitStart+c.dispersionDuration):0;
   const flowingLength=lerp(690,[760,660,570][lane],c.individuality);
   const groupScale=lerp(1,66/180,shrink),groupCenter=lerp(480,376,shrink);
   let length,center,amplitude,spacing,cycles,offset,width;
   if(!pass){length=flowingLength;center=lerp(-650,1850,phase(t-lag,0,2.12));amplitude=c.amplitude;spacing=c.spacing;cycles=length/c.wavelength;offset=(center-length/2-480)/c.wavelength*2*Math.PI-t*.43;width=c.stroke;}
   else {
     length=lerp(flowingLength,180,settle)*groupScale;
     // Approach the final mark position monotonically; no overshoot then retreat.
     center=lerp(-650,376,arrival);
     amplitude=lerp(c.amplitude,9.3,settle)*groupScale;spacing=lerp(c.spacing,57.3,settle)*groupScale;
     const riverPhase=(center-flowingLength/2-480)/c.wavelength*2*Math.PI-t*.43;
     cycles=lerp(flowingLength/c.wavelength,.75,settle);offset=lerp(riverPhase,.3,settle);width=lerp(c.stroke,21.8,settle)*groupScale;
     // On release only the endpoints advance. The existing curve stays fixed.
   }
   amplitude=Math.min(amplitude,length*length/((2*Math.PI*cycles)**2*Math.max(3*spacing,1)));
   const releaseActive=pass&&c.ending==='out'&&t>=exitStart;
   const tailTravel=releaseActive?1750*phase(t,exitStart+c.tailFollowDelay,exitStart+c.tailFollowDelay+c.dispersionDuration):0;
   const headTravel=releaseActive?1900*exit:0;
   const releasePoint=distanceAlong=>{
     const endTheta=.3+Math.PI*1.5,kLogo=Math.PI*1.5/66,k=2*Math.PI/c.exitWavelength;
     let yy,slope;
     if(distanceAlong<=66){const theta=.3+kLogo*distanceAlong;yy=270+3.4*Math.sin(theta);slope=3.4*kLogo*Math.cos(theta);}
     else {const d=distanceAlong-66,initialSlope=3.4*kLogo*Math.cos(endTheta),initialCurvature=-3.4*kLogo*kLogo*Math.sin(endTheta);
       // Match position, tangent and curvature exactly at the logo join (C2).
       // A shorter period restores the next up/down bend early in the release.
       const depth=c.exitDepth,correction=initialCurvature-depth*k*k,decay=Math.exp(-d/40);
       yy=270+3.4*Math.sin(endTheta)+(initialSlope/k)*Math.sin(k*d)+depth*(1-Math.cos(k*d))+.5*correction*d*d*decay;
       slope=initialSlope*Math.cos(k*d)+depth*k*Math.sin(k*d)+correction*decay*(d-d*d/80);
     }
     const normal=Math.sqrt(1+slope*slope),distance=(lane-1)*21;
     return [343+distanceAlong-distance*slope/normal,yy+distance/normal];
   };
   const sample=u=>{if(releaseActive)return releasePoint(lerp(tailTravel,66+headTravel,u));const theta=u*2*Math.PI*cycles+offset;
     const slope=amplitude*2*Math.PI*cycles/length*Math.cos(theta),normal=Math.sqrt(1+slope*slope),distance=(lane-1)*spacing;
     return [center+(u-.5)*length-distance*slope/normal,270+amplitude*Math.sin(theta)+distance/normal];};
   const pts=Array.from({length:161},(_,n)=>sample(n/160));
   paths.push({points:pts,color:c.colors[lane],width});
   // A continuing dotted tail, sampled on the same curve behind the trailing endpoint.
   for(let j=0;j<Math.round(c.tailCount);j++){
     const fadeIn=phase(t-lag-j*c.tailStagger,pass?2.2:0,(pass?2.2:0)+.4);
     const fadeOut=pass?1-phase(t-j*c.tailStagger,formationStart,formationStart+.5):1;
     const exitIn=pass&&c.ending==='out'?phase(t-j*c.tailStagger,exitStart+c.tailFollowDelay,exitStart+c.tailFollowDelay+.25):0;
     // Cycling ages emit new drops at the endpoint as older drops shrink and fade.
     const age=c.dropRate>0?((j+seconds*c.dropRate+lane*.19)%Math.max(1,c.tailCount))/Math.max(1,c.tailCount):0;
     const distance=c.dropRate>0?c.tailSpacing*(.12+age*c.tailCount):c.tailSpacing*(j+1);
     const life=c.dropRate>0?phase(age,0,.08)*(1-smooth(age)):1;
     const opacity=c.dots*Math.max(fadeIn*fadeOut,exitIn)*(c.dropRate>0?life:1-j*.08);
     const q=sample(-distance/(releaseActive?66+headTravel-tailTravel:length)),taper=c.dropRate>0?Math.pow(1-age,.8):1-c.tailTaper*j/Math.max(1,c.tailCount-1);
     if(opacity>.001)dots.push({x:q[0],y:q[1],radius:c.tailSize*taper,opacity,color:c.colors[lane]});
   }
   // Seeded variation: reproducible births, sizes and buoyant trajectories.
   const random=seed=>{const n=Math.sin(seed*127.1+lane*311.7)*43758.5453;return n-Math.floor(n);};
   const bubbleStart=Math.max(3.4+lag,formationStart)+lane*c.bubbleStagger;
   const count=Math.ceil(c.bubbleEmission*c.bubbleRate);
   for(let j=0;j<count;j++){
     const birth=bubbleStart+(j+random(j+1)*c.bubbleRandomness*.65)/c.bubbleRate;
     const lifetime=c.bubbleLinger*(1-c.bubbleRandomness*.3*random(j+7));
     const age=(t-birth)/lifetime;
     if(!pass||age<0||age>=1||t>=holdEnd)continue;
     const opacity=c.frontDots*phase(age,0,.1)*(1-smooth(age))*(1-phase(t,holdEnd-.2,holdEnd));
     const front=sample(1),spread=c.bubbleRandomness;
     const heading=-.65+(random(j+3)-.5)*1.6*spread;
     const travel=age*c.bubbleTravel*(.7+random(j+4)*.6*spread);
     const scatter=Math.sin(age*Math.PI/2)*c.bubbleSpread*spread;
     dots.push({x:front[0]+6+travel*Math.cos(heading)+(random(j+8)-.25)*scatter,y:front[1]+travel*Math.sin(heading)+(random(j+9)-.7)*scatter,radius:c.tailSize*(.65+random(j+5)*.5*spread)*(1-age*.8),opacity,color:c.colors[lane]});
   }
 }
 const wordStart=409+c.logoGap,metrics=fontMetrics[c.fontFamily]||fontMetrics.arial;
 const advances=[...c.wordmark].map(ch=>metrics[ch]??42);
 const letters=Array.from(c.wordmark).map((char,i)=>({char,x:wordStart+advances.slice(0,i).reduce((a,b)=>a+b+c.letterSpacing,0),opacity:phase(t,letterStart+i*c.letterStagger,letterStart+i*c.letterStagger+c.letterFade)*(c.ending==='out'?1-phase(t,lettersOutStart+i*c.letterStagger,lettersOutStart+c.textExitFade+i*c.letterStagger):1)}));
 const wordWidth=advances.reduce((a,b)=>a+b,0)+Math.max(0,c.wordmark.length-1)*c.letterSpacing;
 const logoCenter=(343+wordStart+wordWidth)/2,logoSize=lerp(1,c.assembledLogoScale,phase(t,scaleStart,formationEnd));
 return {paths,dots,letters,timing:{scoreEnd,scaleStart,formationEnd,letterStart,assemblyEnd,holdEnd,lettersOutStart,lettersOutEnd,waveExitStart},wordOpacity:Math.max(0,...letters.map(l=>l.opacity)),wordX:wordStart,wordY:292,fontWeight:c.fontWeight,fontFamily:c.fontFamily,fontStack:fontStacks[c.fontFamily]||fontStacks.arial,letterSpacing:c.letterSpacing,logoCenter,logoSize,stage:t<2.2?'Flow':t<letterStart?'Gather':t<holdEnd||c.ending==='hold'?'Settle':'Release',background:c.background,ink:c.ink,wordmark:c.wordmark};
}
const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&apos;'}[c]));
function svgAt(seconds,options={}){
 const f=frame(seconds,options);
 return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 960 540" width="960" height="540" role="img" aria-label="Rios signature motion"><rect width="960" height="540" fill="${escape(f.background)}"/><g transform="translate(${(f.logoCenter*(1-f.logoSize)).toFixed(3)} ${(270*(1-f.logoSize)).toFixed(3)}) scale(${f.logoSize.toFixed(4)})">${f.paths.map(p=>`<path d="${p.points.map((q,i)=>(i?'L':'M')+q.map(v=>v.toFixed(3)).join(' ')).join(' ')}" stroke="${escape(p.color)}" stroke-width="${p.width}" stroke-linecap="round" stroke-linejoin="round" fill="none"/>`).join('')}${f.dots.map(d=>`<circle cx="${d.x}" cy="${d.y}" r="${d.radius}" opacity="${d.opacity}" fill="${escape(d.color)}"/>`).join('')}${f.letters.map(l=>`<text x="${l.x}" y="${f.wordY}" fill="${escape(f.ink)}" opacity="${l.opacity}" font-family="${escape(f.fontStack)}" font-size="76" font-weight="${f.fontWeight}" letter-spacing="${f.letterSpacing}">${escape(l.char)}</text>`).join('')}</g></svg>`;
}
class RiosMotion {
 constructor(element,options={}){this.element=element;this.options=config(options);this.time=0;this.playing=false;this.seek(0);}
 configure(options){this.options=config({...this.options,...options});this.seek(Math.min(this.time,this.options.duration));}
 seek(seconds){this.time=Math.max(0,Math.min(this.options.duration,seconds));this.element.innerHTML=svgAt(this.time,this.options);this.onupdate?.(this.time,frame(this.time,this.options));}
 play(){if(this.playing)return;if(this.time>=this.options.duration)this.seek(0);this.playing=true;let last=performance.now();const tick=now=>{if(!this.playing)return;this.seek(this.time+(now-last)/1000);last=now;if(this.time>=this.options.duration){this.pause();return;}this.raf=requestAnimationFrame(tick);};this.raf=requestAnimationFrame(tick);}
 pause(){this.playing=false;cancelAnimationFrame(this.raf);this.onplaystate?.(false);}
 replay(){this.pause();this.seek(0);this.play();}
 destroy(){this.pause();this.element.innerHTML='';}
 svg(){return svgAt(this.time,this.options);}
}
global.RiosMotion=RiosMotion;global.RiosMotionTools={defaults,frame,svgAt};
})(typeof window==='undefined'?globalThis:window);
