'use strict';
(() => {
window.AisTelephonyWorkspace = true;
const $ = id => document.getElementById(id);
const content = $('ais-workspace-content'), phone = $('ais-workspace-phone');
let activeCall = false, enabled = false, ready = false, lastPath = null;
const panel = open => { $('phone-panel').hidden = !open; $('phone-toggle').setAttribute('aria-expanded', String(open)); };
const command = action => phone.contentWindow.postMessage({type:'ais-phone-command', action}, location.origin);
$('phone-toggle').onclick = () => panel($('phone-panel').hidden);
$('phone-close').onclick = () => panel(false);
$('phone-disable').onclick = () => {
 if(activeCall && !window.confirm('Завершить разговор и выключить телефонию?')) return;
 command(activeCall ? 'terminate-disable' : 'disable');
};
$('phone-fallback').onclick = e => {
 if(enabled){ e.preventDefault(); panel(true); $('phone-summary').textContent='Сначала выключите телефон здесь'; }
};
window.addEventListener('message', event => {
 if(event.origin !== location.origin || event.source !== phone.contentWindow || !event.data || event.data.type !== 'ais-phone-state') return;
 const state = event.data;
 if(!['off','checking','ready','call','error'].includes(state.state)) return;
 activeCall = state.call === true; enabled = state.enabled === true;
 $('phone-dot').dataset.state = state.state;
 $('phone-summary').textContent = state.error || state.status || 'Выключена';
 $('phone-call-summary').textContent = activeCall ? (state.callTitle || '') + (state.duration ? ' · '+state.duration : '') : '';
 $('phone-disable').hidden = !enabled;
 if(state.incoming || state.error) panel(true);
});
function pathOf(frame){
 try { const w=frame.contentWindow; if(w.location.origin !== location.origin) return null; return w.location.pathname+w.location.search+w.location.hash; } catch(e){return null;}
}
content.addEventListener('load', () => {
 const path=pathOf(content); if(!path) return;
 if(path.startsWith('/users/sign_in')){ command('terminate-disable'); window.location.assign('/users/sign_in'); return; }
 try { document.title=content.contentDocument.title || 'АИС · Телефония'; } catch(e){}
 if(!ready){ready=true;lastPath=path;return;}
 if(path !== lastPath){lastPath=path;history.pushState({path},'', '/telephony/workspace?path='+encodeURIComponent(path));}
});
window.addEventListener('popstate', () => {
 const path=new URL(location.href).searchParams.get('path') || '/';
 if(path.startsWith('/') && !path.startsWith('//') && !/[\\\x00-\x1f\x7f]/.test(path) && !/^\/telephony(?:\/|\?|#|$)/.test(path)){
  lastPath=path;content.src=path;
 }
});
window.addEventListener('beforeunload', event => {if(activeCall){event.preventDefault();event.returnValue='';}});
})();
