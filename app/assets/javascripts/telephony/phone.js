'use strict';
(() => {
const $=id=>document.getElementById(id);
let gateway=null, activeTicket=null, callerGeneration=0, directoryEntries=null, directoryLoading=false, directoryTarget='target', transferState=null;
const csrf=()=>document.querySelector('meta[name=csrf-token]').content;
let ua=null,session=null,stream=null,lease=null,heartbeat=null,started=null,ringTimer=null,audioContext=null,busy=false,pcConfig={iceServers:[]},micAnalyser=null,micSamples=null,remoteSource=null,remoteAnalyser=null,remoteSamples=null,remoteMedia=null,micSource=null,micSilentGain=null;
JsSIP.debug.disable();
let linkState='off',disableAfterCall=false,disableReason='',generation=0,renewingFor=null,renewalWarning=null,disableTask=null,renewalAbort=null;
function publish(){
 if(window.parent===window)return;
 const state=$('error').textContent?'error':session&&session.isEstablished()?'call':linkState;
 window.parent.postMessage({type:'ais-phone-state',state,status:$('status').textContent,error:$('error').textContent,
  enabled:!!ua,call:!!session,incoming:!!session&&session.direction==='incoming'&&!session.isEstablished(),
  callTitle:session?$('call-title').textContent:'',duration:$('duration').textContent},location.origin);
}
function check(id,text,state){const el=$('check-'+id);el.textContent=text;el.dataset.state=state;}
function status(text,state){if(state)linkState=state;$('status').textContent=text;publish();}
function error(text){$('error').textContent=text||'';publish();}
function controls(){const registered=!!ua&&ua.isRegistered();const call=!!session;const incoming=call&&session.direction==='incoming'&&!session.isEstablished();$('enable').disabled=!!ua||busy;$('identity').disabled=!!ua||busy;$('microphone').disabled=!!ua||busy;$('disable').disabled=!ua||call;$('answer').disabled=!incoming;$('reject').disabled=!incoming;$('hangup').disabled=!call;$('mute').disabled=!call||!session.isEstablished();$('test-call').disabled=!registered||call;$('transfer-panel').hidden=!call||!session.isEstablished();$('transfer-call').disabled=!call||!session.isEstablished()||!!transferState;$('transfer-target').disabled=!!transferState;$('transfer-directory').disabled=!!transferState;publish();}
function accessFailure(message){const e=new Error(message);e.accessDenied=true;return e;}
async function request(url,options,timeout=15000){
 if(!timeout)return fetch(url,options);
 const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),timeout);
 try{return await fetch(url,Object.assign({},options,{signal:controller.signal}));}
 catch(e){if(e.name==='AbortError')throw new Error('Сервер не ответил за 15 секунд. Проверьте соединение и повторите включение.');throw e;}
 finally{clearTimeout(timer);}
}
async function getTicket(timeout=15000,version=generation,signal){
 const r=await request('/telephony/ticket',{method:'POST',credentials:'same-origin',headers:{'X-CSRF-Token':csrf(),'Accept':'application/json'},signal},timeout);
 if(version!==generation)throw new Error('Операция отменена.');
 const json=(r.headers.get('Content-Type')||'').includes('application/json');
 if(r.status===401||r.status===403||(r.redirected&&!json))throw accessFailure('Сессия АИС завершена или доступ к телефонии отозван.');
 if(!r.ok||!json)throw new Error('АИС временно недоступна. Повторите проверку.');
 const c=await r.json();if(version!==generation)throw new Error('Операция отменена.');
 gateway=c.gateway;activeTicket=c.ticket;$('gateway-check').href=gateway+'/';return c;
}
async function api(path,data,timeout=15000,context={gateway,ticket:activeTicket},signal){
 const r=await request(context.gateway+'/ais'+path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(Object.assign({},data,{ticket:context.ticket})),signal},timeout);
 let result={};try{result=await r.json();}catch(e){if(r.ok)throw new Error('Некорректный ответ шлюза.');}
 if(!r.ok){const message=result.error||'Ошибка шлюза';const e=[401,403,409].includes(r.status)?accessFailure(message):new Error(message);e.gatewayResponded=true;throw e;}
 return result;
}
function clientLink(title,url){
 const a=document.createElement('a');a.textContent=title;
 const address=new URL(url,location.origin);if(address.origin!==location.origin)return a;
 a.href=address.href;a.target='_blank';a.rel='noopener';
 a.onclick=e=>{if(e.ctrlKey||e.metaKey||e.shiftKey||e.altKey)return;try{
  if(window.parent!==window&&window.parent.AisTelephonyWorkspace){window.parent.postMessage({type:'ais-phone-navigate',path:address.pathname+address.search+address.hash},location.origin);e.preventDefault();return;}
  if(window.opener&&!window.opener.closed){window.opener.location.assign(address.href);window.opener.focus();e.preventDefault();}
 }catch(err){}};
 return a;
}
async function callerContext(raw){
 const generation=++callerGeneration;const target=$('caller-context');target.replaceChildren();target.hidden=false;
 try {
  const r=await fetch('/telephony/caller?number='+encodeURIComponent(raw),{headers:{'Accept':'application/json'}});
  if(!r.ok)throw new Error();const c=await r.json();if(generation!==callerGeneration)return;
  const number=document.createElement('strong');number.textContent=c.number||raw;target.appendChild(number);
  if(c.directory){const label=document.createElement('p');label.textContent=[c.directory.label,c.directory.group].filter(Boolean).join(' · ');target.appendChild(label);}
  for(const client of c.clients){
   const group=document.createElement('div');
   for(const entity of client.entities){group.appendChild(clientLink(entity.title,entity.url));}
   group.appendChild(clientLink(client.name,client.url));target.appendChild(group);
  }
 }catch(e){if(generation===callerGeneration){const p=document.createElement('p');p.textContent=raw+' · Карточка клиента сейчас недоступна';target.appendChild(p);}}
}
function displayNumber(value){const raw=value.replace(/^(?:влд|сакх|vld|vdk|sakh|sah|uss|khd)[\s:;_-]*/i,'');try{return dialNumber(raw);}catch(e){return value;}}
function dialNumber(value){const raw=value.trim();if(/^\d{3,4}$/.test(raw))return raw;let digits=raw.replace(/[+()\s-]/g,'');if(/^8\d{10}$/.test(digits))digits='7'+digits.slice(1);if(!/^7\d{10}$/.test(digits))throw new Error('Введите номер с 7 или внутренний номер из 3–4 цифр.');return digits;}

function micError(e){return ({NotAllowedError:'Разрешите доступ к микрофону в настройках этого сайта.',NotFoundError:'Микрофон не найден. Подключите гарнитуру.',NotReadableError:'Микрофон недоступен или занят другой программой.',TypeError:'Не удалось включить микрофон. Проверьте защищённое подключение и выбранное устройство.'})[e.name]||e.message||'Не удалось включить телефон.';}
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
function attach(pc){if(attached.has(pc))return;attached.add(pc);pc.addEventListener('track',e=>connectRemote(pc,e.streams[0]||new MediaStream([e.track])));pc.addEventListener('iceconnectionstatechange',()=>{if(!session||session.connection!==pc)return;const state=pc.iceConnectionState;$('audio-status').textContent='Аудиосоединение: '+state;if(state==='failed')error('Не удалось установить звук. Завершите тест и проверьте сеть.');if(state==='connected'||state==='completed')connectRemote(pc);});connectRemote(pc);}
async function microphones(){const devices=await navigator.mediaDevices.enumerateDevices();const selected=$('microphone').value;$('microphone').replaceChildren(new Option('Системный по умолчанию',''));for(const d of devices.filter(d=>d.kind==='audioinput'))$('microphone').add(new Option(d.label||'Микрофон '+($('microphone').length),d.deviceId));$('microphone').value=selected;}

function finish(text){if(transferState){clearTimeout(transferState.timer);transferState=null;}$('original-caller').hidden=true;++callerGeneration;$('caller-context').hidden=true;stopRing();if(remoteSource)remoteSource.disconnect();if(remoteAnalyser)remoteAnalyser.disconnect();remoteSource=null;remoteAnalyser=null;remoteMedia=null;remoteSamples=null;session=null;started=null;$('call-title').textContent=text;$('mute').textContent='Выключить микрофон';$('remote').srcObject=null;$('play-audio').textContent='Включить звук';controls();if(disableAfterCall){disableAfterCall=false;const reason=disableReason;disableReason='';disable().then(()=>{if(reason)error(reason);});}}
function handleSession(e){const s=e.session;if(session){s.terminate({status_code:486,reason_phrase:'Busy Here'});return;}session=s;started=null;$('transfer-status').textContent='';$('transfer-target').value='';$('original-caller').hidden=s.direction!=='incoming';$('original-caller').textContent=s.direction==='incoming'?'Исходный номер: '+s.remote_identity.uri.user:'';error('');$('duration').textContent='00:00';$('audio-status').textContent='';$('call-title').textContent=(s.direction==='incoming'?'Входящий: ':'Вызов: ')+displayNumber(s.remote_identity.uri.user);
 const on=(name,handler)=>s.on(name,event=>{if(session===s)handler(event);});
 on('peerconnection',e=>attach(e.peerconnection));if(s.connection)attach(s.connection);
 on('confirmed',()=>{if(s.connection)connectRemote(s.connection);stopRing();started=Date.now();$('call-title').textContent='Разговор с '+displayNumber(s.remote_identity.uri.user);controls();});
 on('ended',()=>finish(s.data&&s.data.aisTransferTarget?'Разговор переведён на '+s.data.aisTransferTarget:'Разговор завершён'));
 on('failed',e=>{const reason=e.message&&e.message.getHeader&&e.message.getHeader('Reason');const other=reason&&/cause\s*=\s*200/.test(reason);finish(other?'Отвечен другим':s.direction==='incoming'&&e.cause==='Canceled'?'Звонящий отменил вызов':'Вызов завершён: '+e.cause);});
 if(s.direction==='incoming'){ring();callerContext(s.remote_identity.uri.user);}controls();
}
function disable(){
 if(session)return Promise.resolve();
 if(disableTask)return disableTask;
 disableTask=shutdown().finally(()=>{disableTask=null;});return disableTask;
}
async function shutdown(){
 ++generation;busy=true;
 clearInterval(heartbeat);heartbeat=null;
 const oldUa=ua,oldLease=lease,context={gateway,ticket:activeTicket};
 ua=null;lease=null;if(renewalAbort)renewalAbort.abort(); // JsSIP emits delayed events after stop; this UA is no longer current.
 if(oldUa)oldUa.stop();
 if(stream){stream.getTracks().forEach(t=>t.stop());stream=null;}
 if(micSource)micSource.disconnect();if(micSilentGain)micSilentGain.disconnect();
 micSource=null;micSilentGain=null;micAnalyser=null;micSamples=null;
 $('mic-status').textContent='Микрофон не включён';$('phone-settings').open=true;
 error('');check('registration','Регистрация: выключена','off');status('Телефония выключена','off');controls();
 try{if(oldLease)await api('/disable',oldLease,15000,context);}catch(e){/* Lease also expires server-side. */}
 finally{busy=false;controls();}
}
function stopWithError(message){
 if(session){if(disableAfterCall){if(message)disableReason=message;return;}disableAfterCall=true;disableReason=message;session.terminate();}
 else disable().then(()=>error(message));
}
async function renew(currentUa,version){
 if(ua!==currentUa||!lease||renewingFor===currentUa)return;
 renewingFor=currentUa;const abort=new AbortController();renewalAbort=abort;
 const currentLease=lease;
 try{
  const context=await getTicket(0,version,abort.signal);
  if(ua!==currentUa||lease!==currentLease)return;
  await api('/heartbeat',currentLease,0,context,abort.signal);
  if(ua!==currentUa||lease!==currentLease||version!==generation)return;
  if(ua===currentUa&&renewalWarning&&$('error').textContent===renewalWarning)error('');
  renewalWarning=null;
 }catch(e){
  if(ua!==currentUa||version!==generation)return;
  if(e.accessDenied)stopWithError(e.message);
  else{renewalWarning='Не удалось обновить доступ к телефонии. Повторяем проверку; текущий разговор продолжается.';error(renewalWarning);}
 }finally{if(renewingFor===currentUa){renewingFor=null;renewalAbort=null;}}
}
$('enable').onclick=async()=>{
 if(ua||busy)return;
 const version=++generation;let stage='microphone';
 gateway=null;activeTicket=null;busy=true;controls();error('');
 status('Проверяем микрофон…','checking');$('gateway-help').hidden=true;
 check('microphone','Микрофон: проверяется','checking');check('gateway','Шлюз: не проверен','off');check('registration','Регистрация: не проверена','off');
 try{
  if(!navigator.mediaDevices)throw new Error('Микрофон доступен только через защищённое подключение.');
  const candidate=await navigator.mediaDevices.getUserMedia({audio:$('microphone').value?{deviceId:{exact:$('microphone').value}}:true,video:false});
  if(version!==generation){candidate.getTracks().forEach(t=>t.stop());return;}
  stream=candidate;check('microphone','Микрофон: доступ разрешён','ok');await microphones();
  audioContext=audioContext||new(window.AudioContext||window.webkitAudioContext)();await audioContext.resume();
  if(version!==generation)return;
  micAnalyser=audioContext.createAnalyser();micAnalyser.fftSize=256;micSource=audioContext.createMediaStreamSource(stream);micSource.connect(micAnalyser);
  micSilentGain=audioContext.createGain();micSilentGain.gain.value=0;micAnalyser.connect(micSilentGain);micSilentGain.connect(audioContext.destination);micSamples=new Uint8Array(micAnalyser.fftSize);
  stage='ais';status('Проверяем доступ в АИС…','checking');
  const context=await getTicket(15000,version);
  stage='gateway';status('Проверяем защищённое соединение со шлюзом…','checking');check('gateway','Шлюз: проверяется','checking');
  const c=await api('/enable',{},15000,context);
  if(version!==generation){await api('/disable',{user:c.user,token:c.token},15000,context).catch(()=>{});return;}
  stage='registration';check('gateway','Шлюз: защищённое соединение установлено','ok');check('registration','Регистрация: подключается','checking');
  lease={user:c.user,token:c.token};pcConfig=c.pcConfig||{iceServers:[]};
  const currentUa=new JsSIP.UA({sockets:[new JsSIP.WebSocketInterface(c.wss)],uri:c.uri,password:c.password,contact_uri:c.contact_uri,register:true,register_expires:120,session_timers:false});
  ua=currentUa;c.password=null;
  const on=(name,handler)=>currentUa.on(name,event=>{if(currentUa===ua)handler(event);});
  on('connecting',()=>status('Подключение…','checking'));
  on('connected',()=>status('Соединение установлено, регистрация…','checking'));
  on('registered',()=>{
   if(document.body.classList.contains('embedded')){$('phone-settings').open=false;$('phone-meters').open=false;}
   check('registration','Регистрация: готов к звонкам','ok');status('Готов к звонкам · '+lease.user,'ready');error('');controls();renew(currentUa,version);
  });
  on('unregistered',()=>{check('registration','Регистрация: отсутствует','error');status('Не зарегистрирован','error');controls();});
  on('registrationFailed',e=>{check('registration','Регистрация: ошибка','error');status('Регистрация не выполнена','error');error(e.response&&e.response.status_code===403?'Этот телефон уже зарегистрирован в другом окне.':'Ошибка регистрации: '+e.cause);controls();});
  on('disconnected',()=>{check('registration','Регистрация: соединение потеряно','error');status('Соединение потеряно · повторное подключение…','checking');error('Проверьте доступность шлюза. В Chrome разрешите сайту АИС доступ к локальной сети.');controls();});
  on('newRTCSession',handleSession);
  heartbeat=setInterval(()=>renew(currentUa,version),15000);currentUa.start();
 }catch(e){
  if(version!==generation)return;
  await disable();
  if(stage==='gateway'){if(e.gatewayResponded){check('gateway','Шлюз: защищённое соединение установлено','ok');check('registration','Регистрация: шлюз отклонил включение','error');}else{check('gateway','Шлюз: соединение не установлено','error');$('gateway-help').hidden=false;}}
  else if(stage==='registration')check('registration','Регистрация: не выполнена','error');
  else if(stage==='microphone')check('microphone','Микрофон: нет доступа','error');
  else check('gateway','Шлюз: не проверен — нет ответа АИС','off');
  error(stage==='microphone'?micError(e):e.message);
 }finally{if(version===generation){busy=false;controls();}}
};
$('disable').onclick=disable;
$('answer').onclick=()=>{error('');stopRing();try{session.answer({mediaStream:stream,mediaConstraints:{audio:true,video:false},pcConfig:pcConfig});}catch(e){error(e.message);}};
$('reject').onclick=()=>{if(session)session.terminate({status_code:486,reason_phrase:'Busy Here'});};
$('hangup').onclick=()=>{if(session)session.terminate();};
$('mute').onclick=()=>{if(!session)return;if(session.isMuted().audio){session.unmute({audio:true});$('mute').textContent='Выключить микрофон';}else{session.mute({audio:true});$('mute').textContent='Включить микрофон';}};
$('test-call').onclick=()=>{error('');try{ua.call('sip:'+dialNumber($('target').value)+'@localhost',{mediaStream:stream,mediaConstraints:{audio:true,video:false},pcConfig:pcConfig});}catch(e){error(e.message);}};
function renderDirectory(){
 const list=$('directory-list'), query=$('directory-search').value.trim().toLocaleLowerCase();
 list.replaceChildren();let group=null, count=0;
 for(const entry of directoryEntries||[]){
  if(directoryTarget==='transfer-target'&&!/^\d{3,4}$/.test(entry.number))continue;
  if(query&&!`${entry.number} ${entry.label} ${entry.group||''}`.toLocaleLowerCase().includes(query))continue;
  const caption=entry.group||'Другие номера';
  if(group!==caption){const title=document.createElement('h3');title.textContent=caption;list.appendChild(title);group=caption;}
  const button=document.createElement('button');button.type='button';button.textContent=entry.number+' · '+entry.label;
  button.onclick=()=>{if(directoryTarget==='transfer-target'&&(!session||!session.isEstablished()||transferState))return;
   const input=$(directoryTarget);input.value=entry.number;input.focus();closeDirectory();};
  list.appendChild(button);count++;
 }
 $('directory-status').textContent=count?'Выберите номер':'Номера не найдены';
}
function closeDirectory(){$('phone-directory').hidden=true;$('directory-open').setAttribute('aria-expanded','false');}
async function openDirectory(target){
 directoryTarget=target;$('phone-directory').hidden=false;$('directory-open').setAttribute('aria-expanded','true');$('directory-search').focus();
 if(directoryEntries){renderDirectory();return;}
 if(directoryLoading)return;
 directoryLoading=true;$('directory-status').textContent='Загружаем адресную книгу…';
 try{const response=await request('/telephony/directory',{credentials:'same-origin',headers:{'Accept':'application/json'}});
  if(!response.ok)throw new Error();const data=await response.json();if(!Array.isArray(data.entries))throw new Error();
  directoryEntries=data.entries;renderDirectory();
 }catch(e){$('directory-status').textContent='Не удалось загрузить адресную книгу. Закройте и откройте её снова.';}
 finally{directoryLoading=false;}
}
$('directory-open').onclick=()=>{$('phone-directory').hidden||directoryTarget!=='target'?openDirectory('target'):closeDirectory();};
$('transfer-directory').onclick=()=>openDirectory('transfer-target');
$('directory-search').oninput=renderDirectory;
$('transfer-call').onclick=()=>{
 const s=session;if(!s||!s.isEstablished()||transferState)return;
 const target=$('transfer-target').value.trim();
 if(!/^\d{3,4}$/.test(target)){$('transfer-status').textContent='Укажите внутренний номер из 3–4 цифр.';return;}
 if(target===$('identity').value){$('transfer-status').textContent='Выберите номер другого сотрудника.';return;}
 if(!window.confirm('Перевести разговор на '+target+' без предварительного разговора с получателем?'))return;
 const state={session:s,target,timer:null};transferState=state;
 const active=()=>session===s&&transferState===state;
 const failure=text=>{if(!active())return;clearTimeout(state.timer);transferState=null;$('transfer-status').textContent=text;controls();};
 $('transfer-status').textContent='Переводим на '+target+'…';controls();
 state.timer=setTimeout(()=>failure('АТС не подтвердила перевод. Проверьте состояние разговора перед повтором.'),125000);
 try{s.refer('sip:'+target+'@localhost',{eventHandlers:{
  requestSucceeded:()=>{if(active())$('transfer-status').textContent='АТС приняла перевод на '+target+'…';},
  requestFailed:()=>failure('АТС отклонила перевод. Проверьте номер и повторите.'),
  progress:()=>{if(active())$('transfer-status').textContent='Вызов направлен на '+target+'…';},
  failed:()=>failure('Получатель недоступен или не ответил.'),
  accepted:()=>{if(!active())return;clearTimeout(state.timer);transferState=null;s.data=s.data||{};s.data.aisTransferTarget=target;$('transfer-status').textContent='Разговор переведён на '+target;s.terminate();}
 }});}catch(e){failure('Не удалось отправить перевод: '+e.message);}
};
$('play-audio').onclick=async()=>{try{if(audioContext)await audioContext.resume();if(!session||!session.connection||!connectRemote(session.connection)){$('audio-status').textContent='Входящий аудиопоток ещё не получен';return;}if(audioContext)await audioContext.resume();else await $('remote').play();$('play-audio').textContent='Звук включён';error('');}catch(e){error('Не удалось включить звук: '+e.message);}};
$('remote').addEventListener('playing',()=>error(''));
window.pilotDiagnostics=async()=>{if(!session||!session.connection)return {active:false};let inbound=0,outbound=0;const stats=await session.connection.getStats();let route='ожидание';for(const pair of stats.values())if(pair.type==='candidate-pair'&&pair.state==='succeeded'&&pair.nominated){const local=stats.get(pair.localCandidateId);route=local?local.candidateType:'неизвестен';}for(const r of stats.values()){if(r.type==='inbound-rtp'&&(r.kind==='audio'||r.mediaType==='audio'))inbound+=r.bytesReceived||0;if(r.type==='outbound-rtp'&&(r.kind==='audio'||r.mediaType==='audio'))outbound+=r.bytesSent||0;}let remoteLevel=0;if(remoteAnalyser&&remoteSamples){remoteAnalyser.getByteTimeDomainData(remoteSamples);remoteLevel=Math.max(...Array.from(remoteSamples,x=>Math.abs(x-128)));}return {active:true,ice:session.connection.iceConnectionState,route,inbound,outbound,remoteTracks:remoteMedia?remoteMedia.getAudioTracks().length:0,playback:audioContext?audioContext.state:'html',remoteLevel};};
setInterval(()=>{if(started){const seconds=Math.floor((Date.now()-started)/1000);$('duration').textContent=String(Math.floor(seconds/60)).padStart(2,'0')+':'+String(seconds%60).padStart(2,'0');}publish();},1000);
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
window.addEventListener('message',async e=>{
 if(window.parent===window||e.origin!==location.origin||e.source!==window.parent||!e.data||e.data.type!=='ais-phone-command')return;
 if(e.data.action==='terminate-disable')stopWithError('');
 else if(e.data.action==='disable'&&!session)await disable();
});
controls();
})();
