// Exercise the actual heartbeat handler without network or SIP registrations.
const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const source=fs.readFileSync(path.join(__dirname,'../../app/assets/javascripts/telephony/phone.js'),'utf8');
const renew=source.slice(source.indexOf('async function renew('),source.indexOf('async function enablePhone('));
(async()=>{
 const currentUa={},currentLease={},fresh={iceTransportPolicy:'relay',iceServers:[{username:'8300:7776'}]};
 const state={ua:currentUa,lease:currentLease,generation:1,renewingFor:null,renewalAbort:null,renewalWarning:null,pcConfig:{iceServers:[{username:'4600:7776'}]},AbortController,
  getTicket:async()=>({}),api:async()=>({ok:true,pcConfig:fresh}),$:()=>({textContent:''}),error:()=>{},stopWithError:()=>{throw Error('unexpected access denial');}};
 vm.createContext(state);vm.runInContext(renew,state);
 await state.renew(currentUa,1);assert.strictEqual(state.pcConfig,fresh);
 // A response from a closed/replaced phone must never overwrite new credentials.
 state.pcConfig={newPhone:true};const replacement=state.pcConfig;
 state.api=async()=>{state.generation=2;return {pcConfig:fresh};};
 await state.renew(currentUa,1);assert.strictEqual(state.pcConfig,replacement);
 console.log('TURN_HEARTBEAT_REFRESH_AND_STALE_RESPONSE_PASSED');
})().catch(e=>{console.error(e);process.exit(1);});
