'use strict';
(() => {
const $ = id => document.getElementById(id);
const content = $('ais-workspace-content'), phone = $('ais-workspace-phone');
const pathPattern = new RegExp(document.body.dataset.workspacePathPattern);
let activeCall = false, enabled = false, lastIncoming = false, lastError = '', fallbackNotice = false;
const panel = open => { $('phone-panel').hidden = !open; $('phone-toggle').setAttribute('aria-expanded', String(open)); };
let lastWaiting=0;
const command = action => phone.contentWindow.postMessage({type:'ais-phone-command', action}, location.origin);
const notice = text => { $('workspace-notice').textContent=text; $('workspace-notice').hidden=!text; };
function validPath(path){
 if(typeof path!=='string'||!pathPattern.test(path))return false;
 try{return pathPattern.test(decodeURIComponent(path.split(/[?#]/,1)[0]));}catch(e){return false;}
}
function navigate(path){if(validPath(path)){content.src=path;notice('');fallbackNotice=false;}}
$('phone-toggle').onclick = () => panel($('phone-panel').hidden);
$('phone-close').onclick = () => panel(false);
$('phone-disable').onclick = () => {
 if(activeCall && !window.confirm('Завершить разговор и выключить телефонию?')) return;
 command(activeCall ? 'terminate-disable' : 'disable');
};
$('phone-fallback').onclick = e => {
 e.preventDefault();
 if(enabled){panel(true);fallbackNotice=true;notice('Сначала выключите телефон здесь');return;}
 notice('');fallbackNotice=false;
 window.open(e.currentTarget.href,'ais-telephony','width=460,height=740,resizable=yes,scrollbars=yes');
};
window.addEventListener('message', event => {
 if(event.origin !== location.origin || event.source !== phone.contentWindow || !event.data) return;
 if(event.data.type==='ais-phone-navigate'){navigate(event.data.path);return;}
 if(event.data.type!=='ais-phone-state')return;
 const state = event.data;
 if(!['off','checking','ready','call','error'].includes(state.state)) return;
 activeCall = state.call === true; enabled = state.enabled === true;
 $('phone-dot').dataset.state = state.state;
 $('phone-summary').textContent = (state.error || state.status || 'Выключена')+(Number.isInteger(state.waiting)&&state.waiting>0?' · Ожидают: '+state.waiting:'');
 $('phone-call-summary').textContent = activeCall ? (state.callTitle || '') + (state.duration ? ' · '+state.duration : '') : '';
 $('phone-disable').hidden = !enabled;
 const waiting=Number.isInteger(state.waiting)&&state.waiting>0?state.waiting:0;
 if((state.incoming&&!lastIncoming)||(state.error&&state.error!==lastError)||waiting>lastWaiting)panel(true);
 lastWaiting=waiting;
 lastIncoming=!!state.incoming;lastError=state.error||'';
 if(!enabled&&fallbackNotice){notice('');fallbackNotice=false;}
});
function updatePage(){
 let path;
 try{const w=content.contentWindow;if(w.location.origin!==location.origin)return;path=w.location.pathname+w.location.search+w.location.hash;}catch(e){return;}
 if(path.startsWith('/users/sign_in')){command('terminate-disable');window.location.assign('/users/sign_in');return;}
 if(!validPath(path))return;
 try{document.title=content.contentDocument.title||'АИС · Телефония';}catch(e){}
 $('workspace-page').href=path;
 $('workspace-copy-status').textContent='';
 // iframe navigation already owns a joint history entry; adding another traps Back.
 history.replaceState({path},'', '/telephony/workspace?path='+encodeURIComponent(path));
}
$('workspace-copy').onclick = async () => {
 const feedback = $('workspace-copy-status');
 try {
  const w = content.contentWindow;
  const path = w.location.pathname + w.location.search + w.location.hash;
  if(w.location.origin !== location.origin || !validPath(path)) throw new Error();
  const url = new URL(path, location.origin).href;
  if(navigator.clipboard && navigator.clipboard.writeText) {
   await navigator.clipboard.writeText(url);
  } else {
   const input = document.createElement('textarea');
   input.value = url; input.style.position = 'fixed'; input.style.opacity = '0';
   document.body.appendChild(input);
   try { input.select(); if(!document.execCommand('copy')) throw new Error(); }
   finally { input.remove(); $('workspace-copy').focus(); }
  }
  feedback.textContent = 'Ссылка скопирована';
 } catch(e) { feedback.textContent = 'Не удалось скопировать ссылку'; }
};
content.addEventListener('load',updatePage);
// The initial frame may have loaded before this deferred script.
updatePage();
window.addEventListener('beforeunload', event => {if(activeCall){event.preventDefault();event.returnValue='';}});
})();
