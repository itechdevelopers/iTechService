// Run the actual answer handler, including repeated clicks during async setup.
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync(path.join(__dirname,'../../app/assets/javascripts/telephony/phone.js'),'utf8');
const handler=source.slice(source.indexOf("$('answer').onclick="),source.indexOf("$('reject').onclick="));
const helper=source.slice(source.indexOf('function awaitingAnswer('),source.indexOf('function publish('));
let calls=0,mediaCalls=0,ringStops=0,message='',established=false,ended=false;
const button={},s={data:{},direction:'incoming',isEnded:()=>ended,isEstablished:()=>established,answer:()=>{calls++;}};
const state={session:s,pcConfig:{},$:()=>button,error:text=>{message=text;},stopRing:()=>{ringStops++;},controls:()=>{},callMedia:()=>{mediaCalls++;return {};}};
vm.createContext(state);vm.runInContext(helper+handler,state);
button.onclick();button.onclick();assert.equal(calls,1);assert.equal(mediaCalls,1);assert.equal(ringStops,1);assert.equal(message,'');assert(!state.awaitingAnswer(s));
established=true;button.onclick();assert.equal(calls,1);
state.session=null;button.onclick();assert.equal(calls,1);
state.session=s;established=false;ended=true;s.data.aisAnswering=false;button.onclick();assert.equal(calls,1);
ended=false;s.data={};s.answer=()=>{throw Error('media setup failed');};button.onclick();assert(message.includes('media setup failed'));assert.equal(s.data.aisAnswering,false);assert(state.awaitingAnswer(s));
s.answer=()=>{calls++;};button.onclick();assert.equal(calls,2);assert.equal(message,'');
console.log('ANSWER_DOUBLE_CLICK_END_RACE_AND_REAL_FAILURE_RETRY_PASSED');
