(function(root,factory){const model=factory();if(typeof module==='object'&&module.exports)module.exports=model;else root.JMModel=model;})(typeof globalThis!=='undefined'?globalThis:this,function(){
 'use strict';
 const fields={spectrum:['实时曲线','参考曲线'],loudness:['整段 I','瞬时 M','短时 S','范围 LRA','最大瞬时'],history:['短时 S','瞬时 M','整段 I'],stereo:['向量图','相关度','左右平衡'],peaks:['True Peak','Sample Peak']};
 const titles={spectrum:'频谱',loudness:'响度',history:'响度历史',stereo:'立体声',peaks:'峰值'};
 const clone=x=>JSON.parse(JSON.stringify(x));
 const id=()=>typeof crypto!=='undefined'&&crypto.randomUUID?crypto.randomUUID():Date.now().toString(36)+'-'+Math.random().toString(36).slice(2);
 const widget=kind=>({id:id(),kind,width:1,height:1,fields:fields[kind].slice()});
 const standard={id:'default',name:'默认',widgets:['spectrum','loudness','history','stereo'].map(kind=>({...widget(kind),id:'default-'+kind}))};
 const defaults=()=>({theme:'system',interfaceLanguage:null,interfaceScale:1,transparency:35,unit:'LUFS',reference:-16,target:-16,peakLimit:-1,pinned:false,followTransport:true,layouts:[],selected:'default'});
 const number=(n,min,max,fallback)=>typeof n==='number'&&Number.isFinite(n)?Math.min(max,Math.max(min,n)):fallback;
 const sanitize=input=>{
  const p={...defaults(),...(input&&typeof input==='object'&&!Array.isArray(input)?input:{})};
  if(!['system','light','dark'].includes(p.theme))p.theme='system';
  if(!['zh-Hans','en'].includes(p.interfaceLanguage))p.interfaceLanguage=null;
  if(![.5,.75,1,1.2].includes(p.interfaceScale))p.interfaceScale=1;
  if(!['LUFS','LKFS','LU'].includes(p.unit))p.unit='LUFS';
  for(const [key,min,max,fallback]of[['transparency',0,85,35],['reference',-60,0,-16],['target',-60,0,-16],['peakLimit',-60,6,-1]])p[key]=number(p[key],min,max,fallback);
  p.pinned=p.pinned===true;p.followTransport=p.followTransport!==false;
  const ids=new Set(['default']);
  p.layouts=(Array.isArray(p.layouts)?p.layouts:[]).filter(l=>{if(!l||typeof l.id!=='string'||ids.has(l.id))return false;ids.add(l.id);return true;}).slice(0,64).map(l=>{
   const seen=new Set();const widgets=(Array.isArray(l.widgets)?l.widgets:[]).filter(w=>w&&Object.hasOwn(fields,w.kind)).slice(0,64).map(w=>{
    let wid=typeof w.id==='string'?w.id:id();if(seen.has(wid))wid=id();seen.add(wid);
    const list=[...new Set((Array.isArray(w.fields)?w.fields:[]).filter(f=>fields[w.kind].includes(f)))];
    return {id:wid,kind:w.kind,width:Math.round(number(w.width,1,2,1)),height:Math.round(number(w.height,1,2,1)),fields:list.length?list:[fields[w.kind][0]]};
   });return {id:l.id,name:String(l.name??'').slice(0,40),widgets:widgets.length?widgets:[widget('loudness')]};
  });
  if(p.selected!=='default'&&!p.layouts.some(l=>l.id===p.selected))p.selected='default';
  return p;
 };
 const pack=widgets=>{const used=new Set();return widgets.map(w=>{for(let cell=0;;cell++){const row=Math.floor(cell/2),column=cell%2;if(column+w.width>2)continue;const cells=[];for(let y=0;y<w.height;y++)for(let x=0;x<w.width;x++)cells.push((row+y)*2+column+x);if(cells.every(c=>!used.has(c))){cells.forEach(c=>used.add(c));return {widget:w,row,column};}}});};
 const formatted=(value,p,loudness=true)=>Number.isFinite(value)?(value-(loudness&&p.unit==='LU'?p.reference:0)).toFixed(1).replace('-','−'):'−∞';
 return {fields,titles,clone,id,widget,standard,defaults,sanitize,pack,formatted};
});
