'use strict';
(() => {
const $=id=>document.getElementById(id);
let gateway=null, activeTicket=null, callerGeneration=0;
const csrf=()=>document.querySelector('meta[name=csrf-token]').content;
let ua=null,session=null,stream=null,lease=null,heartbeat=null,started=null,ringTimer=null,audioContext=null,busy=false,pcConfig={iceServers:[]},micAnalyser=null,micSamples=null,remoteSource=null,remoteAnalyser=null,remoteSamples=null,remoteMedia=null,micSource=null,micSilentGain=null;
JsSIP.debug.disable();
function status(text){$('status').textContent=text;}
function error(text){$('error').textContent=text||'';}
function controls(){const registered=!!ua&&ua.isRegistered();const call=!!session;const incoming=call&&session.direction==='incoming'&&!session.isEstablished();$('enable').disabled=!!ua||busy;$('identity').disabled=!!ua||busy;$('microphone').disabled=!!ua||busy;$('disable').disabled=!ua||call;$('answer').disabled=!incoming;$('reject').disabled=!incoming;$('hangup').disabled=!call;$('mute').disabled=!call||!session.isEstablished();$('test-call').disabled=!registered||call;}
async function getTicket(){
 const r=await fetch('/telephony/ticket',{method:'POST',credentials:'same-origin',headers:{'X-CSRF-Token':csrf(),'Accept':'application/json'}});
 if(!r.ok||!r.headers.get('Content-Type').includes('application/json'))throw new Error('Сессия АИС завершена или доступ к телефонии отозван.');
 const c=await r.json();gateway=c.gateway;activeTicket=c.ticket;return c;
}
async function api(path,data){
 const r=await fetch(gateway+'/ais'+path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(Object.assign({},data,{ticket:activeTicket}))});
 const result=await r.json();if(!r.ok)throw new Error(result.error||'Ошибка шлюза');return result;
}
function clientLink(title,url){
 const a=document.createElement('a');a.textContent=title;
 const address=new URL(url,location.origin);if(address.origin!==location.origin)return a;
 a.href=address.href;a.target='_blank';a.rel='noopener';
 a.onclick=e=>{try{if(window.opener&&!window.opener.closed){window.opener.location.assign(address.href);window.opener.focus();e.preventDefault();}}catch(err){}};
 return a;
}
async function callerContext(raw){
 const generation=++callerGeneration;const target=$('caller-context');target.replaceChildren();target.hidden=false;
 try {
  const r=await fetch('/telephony/caller?number='+encodeURIComponent(raw),{headers:{'Accept':'application/json'}});
  if(!r.ok)throw new Error();const c=await r.json();if(generation!==callerGeneration)return;
  const number=document.createElement('strong');number.textContent=c.number||raw;target.appendChild(number);
  for(const client of c.clients){
   const group=document.createElement('div');
   for(const entity of client.entities){group.appendChild(clientLink(entity.title,entity.url));}
   group.appendChild(clientLink(client.name,client.url));target.appendChild(group);
  }
 }catch(e){if(generation===callerGeneration){const p=document.createElement('p');p.textContent=raw+' · Карточка клиента сейчас недоступна';target.appendChild(p);}}
}
function displayNumber(value){const raw=value.replace(/^(?:влд|сакх|vld|sakh)[\s:;_-]*/i,'');try{return dialNumber(raw);}catch(e){return value;}}
function dialNumber(value){const raw=value.trim();if(/^\d{3,4}$/.test(raw))return raw;let digits=raw.replace(/[+()\s-]/g,'');if(/^8\d{10}$/.test(digits))digits='7'+digits.slice(1);if(!/^7\d{10}$/.test(digits))throw new Error('Введите номер с 7 или внутренний номер из 3–4 цифр.');return digits;}

function micError(e){return ({NotAllowedError:'Разрешите доступ к микрофону в настройках этого сайта.',NotFoundError:'Микрофон не найден. Подключите гарнитуру.',NotReadableError:'Микрофон недоступен или занят другой программой.',TypeError:'Не удалось связаться со шлюзом. В Chrome разрешите АИС доступ к локальной сети и проверьте, что шлюз включён.'})[e.name]||e.message||'Не удалось включить телефон.';}
function ring(){if(!audioContext)return;ringTimer=setInterval(()=>{const o=audioContext.createOscillator(),g=audioContext.createGain();o.frequency.value=480;g.gain.value=.04;o.connect(g);g.connect(audioContext.destination);o.start();o.stop(audioContext.currentTime+.2);},1200);}
function stopRing(){clearInterval(ringTimer);ringTimer=null;}
const attached=new WeakSet();
function connectRemote(pc,eventStream){
 const tracks=eventStream?eventStream.getAudioTracks():pc.getReceivers().map(r=>r.track).filter(t=>t&&t.kind==='audio');
 if(!tracks.length)return false;
 const same=remoteMedia&&tracks.every(t=>remoteMedia.getTracks().includes(t));
 if(!same){
  if(remoteSource)remoteSource.disconnect();
  if(remoteAnalyser)remoteAnalyser.disconnect();
  remoteMedia=eventStream||new MediaStream(tracks);
  $('remote').srcObject=remoteMedia;
  if(audioContext){
   remoteSource=audioContext.createMediaStreamSource(remoteMedia);
   remoteAnalyser=audioContext.createAnalyser();remoteAnalyser.fftSize=256;remoteSamples=new Uint8Array(remoteAnalyser.fftSize);
   remoteSource.connect(remoteAnalyser);remoteAnalyser.connect(audioContext.destination);
  }
 }
 if(audioContext){$('remote').muted=true;audioContext.resume().then(()=>{$('play-audio').textContent=audioContext.state==='running'?'Звук включён':'Включить звук';}).catch(()=>error('Safari приостановил звук. Нажмите «Включить звук».'));}
 else{$('remote').muted=false;$('remote').volume=1;$('remote').play().then(()=>{$('play-audio').textContent='Звук включён';}).catch(()=>error('Нажмите «Включить звук».'));}
 return true;
}
function attach(pc){if(attached.has(pc))return;attached.add(pc);pc.addEventListener('track',e=>connectRemote(pc,e.streams[0]||new MediaStream([e.track])));pc.addEventListener('iceconnectionstatechange',()=>{const state=pc.iceConnectionState;$('audio-status').textContent='Аудиосоединение: '+state;if(state==='failed')error('Не удалось установить звук. Завершите тест и проверьте сеть.');if(state==='connected'||state==='completed')connectRemote(pc);});connectRemote(pc);}
async function microphones(){const devices=await navigator.mediaDevices.enumerateDevices();const selected=$('microphone').value;$('microphone').replaceChildren(new Option('Системный по умолчанию',''));for(const d of devices.filter(d=>d.kind==='audioinput'))$('microphone').add(new Option(d.label||'Микрофон '+($('microphone').length),d.deviceId));$('microphone').value=selected;}

function finish(text){++callerGeneration;$('caller-context').hidden=true;stopRing();if(remoteSource)remoteSource.disconnect();if(remoteAnalyser)remoteAnalyser.disconnect();remoteSource=null;remoteAnalyser=null;remoteMedia=null;remoteSamples=null;session=null;started=null;$('call-title').textContent=text;$('mute').textContent='Выключить микрофон';$('remote').srcObject=null;$('play-audio').textContent='Включить звук';controls();}
function handleSession(e){const s=e.session;if(session){s.terminate({status_code:486,reason_phrase:'Busy Here'});return;}session=s;started=null;error('');$('duration').textContent='00:00';$('audio-status').textContent='';$('call-title').textContent=(s.direction==='incoming'?'Входящий: ':'Вызов: ')+displayNumber(s.remote_identity.uri.user);
 s.on('peerconnection',e=>attach(e.peerconnection));if(s.connection)attach(s.connection);
 s.on('confirmed',()=>{if(s.connection)connectRemote(s.connection);stopRing();started=Date.now();$('call-title').textContent='Разговор с '+displayNumber(s.remote_identity.uri.user);controls();});
 s.on('ended',()=>finish('Разговор завершён'));
 s.on('failed',e=>{const reason=e.message&&e.message.getHeader&&e.message.getHeader('Reason');const other=reason&&/cause\s*=\s*200/.test(reason);finish(other?'Отвечен другим':s.direction==='incoming'&&e.cause==='Canceled'?'Звонящий отменил вызов':'Вызов завершён: '+e.cause);});
 if(s.direction==='incoming'){ring();callerContext(s.remote_identity.uri.user);}controls();
}
async function disable(){if(session)return;clearInterval(heartbeat);heartbeat=null;if(ua){ua.stop();ua=null;}if(stream){stream.getTracks().forEach(t=>t.stop());stream=null;if(micSource)micSource.disconnect();if(micSilentGain)micSilentGain.disconnect();micSource=null;micSilentGain=null;micAnalyser=null;micSamples=null;$('mic-status').textContent='Микрофон не включён';}if(lease){const old=lease;lease=null;await api('/disable',old).catch(()=>{});}status('Телефония выключена');controls();}
$('enable').onclick=async()=>{busy=true;controls();error('');try{if(!navigator.mediaDevices)throw new Error('Микрофон доступен только через защищённое подключение.');stream=await navigator.mediaDevices.getUserMedia({audio:$('microphone').value?{deviceId:{exact:$('microphone').value}}:true,video:false});await microphones();audioContext=audioContext||new(window.AudioContext||window.webkitAudioContext)();await audioContext.resume();micAnalyser=audioContext.createAnalyser();micAnalyser.fftSize=256;micSource=audioContext.createMediaStreamSource(stream);micSource.connect(micAnalyser);micSilentGain=audioContext.createGain();micSilentGain.gain.value=0;micAnalyser.connect(micSilentGain);micSilentGain.connect(audioContext.destination);micSamples=new Uint8Array(micAnalyser.fftSize);await getTicket();const c=await api('/enable',{});lease={user:c.user,token:c.token};pcConfig=c.pcConfig||{iceServers:[]};ua=new JsSIP.UA({sockets:[new JsSIP.WebSocketInterface(c.wss)],uri:c.uri,password:c.password,contact_uri:c.contact_uri,register:true,register_expires:120,session_timers:false});c.password=null;
 ua.on('connecting',()=>status('Подключение…'));ua.on('connected',()=>status('Соединение установлено, регистрация…'));ua.on('registered',()=>{api('/heartbeat',lease).catch(e=>error(e.message));status('Готов к звонкам · '+lease.user);error('');controls();});ua.on('unregistered',()=>{status('Не зарегистрирован');controls();});ua.on('registrationFailed',e=>{status('Регистрация не выполнена');error(e.response&&e.response.status_code===403?'Этот телефон уже зарегистрирован в другом окне.': 'Ошибка регистрации: '+e.cause);controls();});ua.on('disconnected',()=>{status('Соединение потеряно · повторное подключение…');error('Проверьте доступность шлюза. В Chrome разрешите сайту АИС доступ к локальной сети.');controls();});ua.on('newRTCSession',handleSession);heartbeat=setInterval(()=>{if(lease)getTicket().then(()=>api('/heartbeat',lease)).catch(async e=>{if(session)session.terminate();await disable();error(e.message);});},15000);ua.start();
}catch(e){error(micError(e));await disable();}finally{busy=false;controls();}};
$('disable').onclick=disable;
$('answer').onclick=()=>{error('');stopRing();try{session.answer({mediaStream:stream,mediaConstraints:{audio:true,video:false},pcConfig:pcConfig});}catch(e){error(e.message);}};
$('reject').onclick=()=>{if(session)session.terminate({status_code:486,reason_phrase:'Busy Here'});};
$('hangup').onclick=()=>{if(session)session.terminate();};
$('mute').onclick=()=>{if(!session)return;if(session.isMuted().audio){session.unmute({audio:true});$('mute').textContent='Выключить микрофон';}else{session.mute({audio:true});$('mute').textContent='Включить микрофон';}};
$('test-call').onclick=()=>{error('');try{ua.call('sip:'+dialNumber($('target').value)+'@localhost',{mediaStream:stream,mediaConstraints:{audio:true,video:false},pcConfig:pcConfig});}catch(e){error(e.message);}};
$('play-audio').onclick=async()=>{try{if(audioContext)await audioContext.resume();if(!session||!session.connection||!connectRemote(session.connection)){$('audio-status').textContent='Входящий аудиопоток ещё не получен';return;}if(audioContext)await audioContext.resume();else await $('remote').play();$('play-audio').textContent='Звук включён';error('');}catch(e){error('Не удалось включить звук: '+e.message);}};
$('remote').addEventListener('playing',()=>error(''));
window.pilotDiagnostics=async()=>{if(!session||!session.connection)return {active:false};let inbound=0,outbound=0;const stats=await session.connection.getStats();let route='ожидание';for(const pair of stats.values())if(pair.type==='candidate-pair'&&pair.state==='succeeded'&&pair.nominated){const local=stats.get(pair.localCandidateId);route=local?local.candidateType:'неизвестен';}for(const r of stats.values()){if(r.type==='inbound-rtp'&&(r.kind==='audio'||r.mediaType==='audio'))inbound+=r.bytesReceived||0;if(r.type==='outbound-rtp'&&(r.kind==='audio'||r.mediaType==='audio'))outbound+=r.bytesSent||0;}let remoteLevel=0;if(remoteAnalyser&&remoteSamples){remoteAnalyser.getByteTimeDomainData(remoteSamples);remoteLevel=Math.max(...Array.from(remoteSamples,x=>Math.abs(x-128)));}return {active:true,ice:session.connection.iceConnectionState,route,inbound,outbound,remoteTracks:remoteMedia?remoteMedia.getAudioTracks().length:0,playback:audioContext?audioContext.state:'html',remoteLevel};};
setInterval(()=>{if(started){const seconds=Math.floor((Date.now()-started)/1000);$('duration').textContent=String(Math.floor(seconds/60)).padStart(2,'0')+':'+String(seconds%60).padStart(2,'0');}},1000);
for(const id of ['mic-meter','remote-meter'])for(let i=0;i<20;i++)$(id).appendChild(document.createElement('i'));
function drawMeter(id,analyser,samples){let level=0;if(analyser&&samples&&audioContext&&audioContext.state==='running'){analyser.getByteTimeDomainData(samples);let power=0;for(const x of samples)power+=Math.pow((x-128)/128,2);const rms=Math.sqrt(power/samples.length);level=rms>0.002?Math.min(100,Math.round(Math.sqrt(rms)*160)):0;}const meter=$(id);meter.setAttribute('aria-valuenow',String(level));Array.from(meter.children).forEach((bar,i)=>bar.classList.toggle('on',level>i*5));return level;}
setInterval(()=>{const mic=drawMeter('mic-meter',micAnalyser,micSamples);drawMeter('remote-meter',remoteAnalyser,remoteSamples);$('mic-meter-hint').textContent=!stream?'Включите телефонию, затем скажите что-нибудь':audioContext&&audioContext.state!=='running'?'Аудиоканал приостановлен. Нажмите «Включить звук».':mic>0?'Микрофон получает звуковой сигнал':'Сигнал не обнаружен — говорите и проверьте выбранный микрофон';},50);
let previousAudio=null;
setInterval(async()=>{
 if(micAnalyser&&micSamples){micAnalyser.getByteTimeDomainData(micSamples);const level=Math.max(...Array.from(micSamples,x=>Math.abs(x-128)));$('mic-status').textContent='Микрофон: '+(stream.getAudioTracks()[0].label||'подключён')+' · уровень '+Math.round(level/128*100)+'%';}
 if(session&&session.isEstablished()){try{const d=await window.pilotDiagnostics();if(!d.active)return;const inbound=previousAudio&&d.inbound>previousAudio.inbound;const outbound=previousAudio&&d.outbound>previousAudio.outbound;$('rtp-status').textContent='Звук: отправка '+(outbound?'идёт':'ожидание')+' · получение '+(inbound?'идёт':'ожидание')+' · воспроизведение '+(audioContext?audioContext.state==='running'?'включено':'остановлено':$('remote').paused?'остановлено':'включено')+' · входящий уровень '+Math.round((d.remoteLevel||0)/128*100)+'% · маршрут '+d.route;previousAudio=d;if(!previousAudio.inbound&&started&&Date.now()-started>10000)error('Ответ получен, но звук не приходит со шлюза.');}catch(e){$('rtp-status').textContent='Диагностика звука пока недоступна';}}
 else previousAudio=null;
},1000);
if(navigator.mediaDevices)microphones().catch(()=>{});
window.addEventListener('beforeunload',e=>{if(session){e.preventDefault();e.returnValue='';}});
window.addEventListener('pagehide',()=>{if(ua)ua.stop();if(lease)fetch(gateway+'/ais/disable',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(Object.assign({},lease,{ticket:activeTicket})),keepalive:true}).catch(()=>{});});
controls();
})();
