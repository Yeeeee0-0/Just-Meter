'use strict';
const assert=require('node:assert/strict');
const M=require('../Sources/Windows/Web/model.js');
assert.deepEqual(M.pack(M.standard.widgets).map(p=>[p.column,p.row]),[[0,0],[1,0],[0,1],[1,1]]);
const mixed=[{width:1,height:2},{width:1,height:1},{width:1,height:1},{width:2,height:1},{width:2,height:2}];
const used=new Set();
for(const {widget:w,column:x,row:y}of M.pack(mixed))for(let dy=0;dy<w.height;dy++)for(let dx=0;dx<w.width;dx++){const key=[x+dx,y+dy].join();assert(!used.has(key));used.add(key);assert(x+dx<2);}
const legacy={theme:'dark',unit:'LU',layouts:[{id:'custom',name:'录音室',widgets:[{id:'stereo',kind:'stereo',width:2,height:1,fields:['左右平衡','相关度']}]}],selected:'custom'};
const p=M.sanitize(legacy);assert.equal(p.interfaceScale,1);assert.equal(p.followTransport,true);assert.deepEqual(p.layouts,legacy.layouts);assert.equal(M.formatted(-20,p),'−4.0');assert.equal(M.formatted(5,p,false),'5.0');assert.equal(M.formatted(null,p),'−∞');
const broken=M.sanitize({theme:null,transparency:Infinity,interfaceScale:0,layouts:[{id:'default'},{id:'x',widgets:[{kind:'stereo',id:'a',width:9,height:0,fields:['unknown']},{kind:'stereo',id:'a',width:1,height:1}]}],selected:'missing'});
assert.equal(broken.selected,'default');assert.equal(broken.layouts.length,1);assert.equal(broken.layouts[0].widgets[0].width,2);assert.notEqual(broken.layouts[0].widgets[0].id,broken.layouts[0].widgets[1].id);assert.equal(broken.transparency,35);
assert.deepEqual(M.sanitize(null),M.defaults());
console.log('PASS: default grid, mixed widget packing, macOS preferences, units, malformed state');
