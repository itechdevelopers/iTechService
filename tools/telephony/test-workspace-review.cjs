// Regression tests for PR 767: actual JsSIP registrar/timers, stubbed network only.
const fs=require('fs'),path=require('path');
const pilot=process.env.AIS_TELEPHONY_PILOT_ROOT||'/Users/mac/Library/Application Support/com.itech.call-pipeline/runtime/work/webrtc-pilot';
const {chromium}=require(path.join(pilot,'test-tools/node_modules/playwright'));
const repo=path.resolve(__dirname,'../..'),fixtures=process.env.AIS_PHONE_BROWSER_FIXTURES||'/tmp/ais-native-fixtures';
const delay=ms=>new Promise(r=>setTimeout(r,ms));
function registrar(){
 const RealUA=JsSIP.UA;window.testUas=[];
 JsSIP.UA=class extends RealUA{constructor(c){super(c);window.testUas.push(this);}};
 JsSIP.WebSocketInterface=class{
  constructor(){this.url='wss://gateway.example.test/ws';this.via_transport='WSS';this.sip_uri='sip:localhost;transport=ws';this.connected=false;}
  isConnected(){return this.connected;}
  isConnecting(){return false;}
  connect(){this.connected=true;setTimeout(()=>this.onconnect(),0);}
  disconnect(){this.connected=false;setTimeout(()=>this.ondisconnect(false),0);}
  send(data){
   if(!data.startsWith('REGISTER '))return true;
   const header=name=>(data.match(new RegExp('^'+name+':\\s*(.*)$','im'))||[])[1];
   const expires=header('Expires')||'120';
   let contact=header('Contact')||'';contact=contact.replace(/;expires=\d+/g,'')+';expires='+expires;
   const reply=['SIP/2.0 200 OK','Via: '+header('Via'),'From: '+header('From'),'To: '+header('To')+';tag=stub','Call-ID: '+header('Call-ID'),'CSeq: '+header('CSeq'),'Contact: '+contact,'Expires: '+expires,'Content-Length: 0','',''].join('\r\n');
   setTimeout(()=>this.ondata(reply),20);return true;
  }
 };
}
(async()=>{
 let browser;try{
  browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream']});
  const ctx=await browser.newContext({permissions:['microphone']});
  let ticketMode='ok',gatewayMode='ok',slowWorkspace=true;const errors=[];
  await ctx.route('https://ise.itech.pw/**',async r=>{
   const u=new URL(r.request().url());
   if(u.pathname.startsWith('/assets/telephony/')){
    const ext=u.pathname.endsWith('.js')?'.js':'.css';
    const name=['workspace.js','workspace.css','phone.js','phone.css','jssip.min.js'].find(n=>n.endsWith(ext)&&u.pathname.includes(n.slice(0,-ext.length)));
    if(name==='workspace.js'&&slowWorkspace){slowWorkspace=false;await delay(1500);}
    let body=fs.readFileSync(path.join(repo,name==='jssip.min.js'?'vendor/assets/javascripts/telephony':ext==='.js'?'app/assets/javascripts/telephony':'app/assets/stylesheets/telephony',name),'utf8');
    if(name==='jssip.min.js')body+='\n;('+registrar.toString()+')();';
    return r.fulfill({contentType:ext==='.js'?'application/javascript':'text/css',body});
   }
   if(u.pathname==='/telephony/ticket'){
    if(ticketMode==='down')return r.abort('failed');
    if(ticketMode==='deny')return r.fulfill({status:403,contentType:'application/json',body:'{}'});
    return r.fulfill({contentType:'application/json',body:JSON.stringify({ticket:'test-only',gateway:'https://gateway.example.test',extension:'7779'})});
   }
   if(u.pathname==='/telephony/workspace'||u.pathname==='/telephony')return r.fulfill({contentType:'text/html',body:fs.readFileSync(path.join(fixtures,u.pathname.endsWith('workspace')?'workspace.html':'phone.html'),'utf8')});
   return r.fulfill({contentType:'text/html',body:'<title>АИС '+u.pathname+'</title><a href="/orders">Заявки</a><a href="/service_jobs">Ремонты</a>'});
  });
  await ctx.route('https://gateway.example.test/**',async r=>{
   if(r.request().method()==='OPTIONS')return r.fulfill({status:204,headers:{'Access-Control-Allow-Origin':'https://ise.itech.pw','Access-Control-Allow-Methods':'POST,OPTIONS','Access-Control-Allow-Headers':'Content-Type'}});
   if(r.request().url().endsWith('/enable')&&gatewayMode==='slow'){await delay(16000);try{return await r.fulfill({contentType:'application/json',body:'{}'});}catch(e){return;}}
   return r.fulfill({headers:{'Access-Control-Allow-Origin':'https://ise.itech.pw'},contentType:'application/json',body:r.request().url().endsWith('/enable')?JSON.stringify({user:'7779',password:'test-only',token:'test-token',uri:'sip:7779@localhost',contact_uri:'sip:7779@localhost;transport=ws',wss:'wss://gateway.example.test/ws'}):'{}'});
  });
  const p=await ctx.newPage();p.on('pageerror',e=>errors.push(e.message));
  await p.goto('https://ise.itech.pw/telephony/workspace?path=/clients');
  const content=()=>p.frames().find(f=>f.parentFrame()&&!f.url().includes('/telephony'));
  const phone=()=>p.frames().find(f=>f.url().includes('/telephony?'));
  await content().click('a[href="/orders"]');await p.waitForURL(/path=%2Forders/);
  console.log('Delayed workspace script captures initial frame and first navigation');
  await p.click('#phone-toggle');await phone().click('#enable');await p.waitForFunction(()=>document.getElementById('phone-dot').dataset.state==='ready');
  await p.click('#phone-fallback');await p.waitForTimeout(2500);
  if(!(await p.locator('#workspace-notice').innerText()).includes('Сначала выключите'))throw Error('Fallback warning overwritten');
  await p.click('#phone-disable');await p.waitForFunction(()=>document.getElementById('phone-dot').dataset.state==='off');await p.waitForTimeout(3500);
  if(await p.locator('#phone-dot').getAttribute('data-state')!=='off'||await phone().locator('#error').innerText())throw Error('Delayed JsSIP stop events corrupt disabled state');
  console.log('Actual JsSIP un-REGISTER and delayed disconnect leave phone gray, not red');
  await phone().click('#enable');await p.waitForFunction(()=>document.getElementById('phone-dot').dataset.state==='ready');
  await p.click('#phone-disable');await p.waitForFunction(()=>!document.getElementById('ais-workspace-phone').contentDocument.getElementById('enable').disabled);
  await phone().click('#enable');await p.waitForTimeout(3500);
  if(await p.locator('#phone-dot').getAttribute('data-state')!=='ready')throw Error('Old UA events changed re-enabled phone');
  console.log('Re-enable before old transport closes ignores old UA callbacks');
  // Explicit permission denial must stop the phone and preserve the real reason.
  ticketMode='deny';await p.waitForFunction(()=>document.getElementById('phone-summary').textContent.includes('Сессия АИС'),{},{timeout:18000});await p.waitForTimeout(3500);
  if(!(await phone().locator('#error').innerText()).includes('Сессия АИС'))throw Error('Late UA disconnect replaced access denial');
  await p.click('#phone-close');await p.waitForTimeout(2500);if(!await p.locator('#phone-panel').isHidden())throw Error('Repeated error messages reopen closed panel');
  console.log('Explicit denial stops phone; real reason survives; unchanged error does not reopen panel');
  // A slow broker activation is still bounded and diagnoses the broker stage.
  ticketMode='ok';gatewayMode='slow';await p.click('#phone-toggle');await phone().click('#enable');
  await phone().waitForFunction(()=>document.getElementById('error').textContent.includes('15 секунд'),{},{timeout:18000});
  if(await phone().locator('#check-gateway').getAttribute('data-state')!=='error'||await phone().locator('#gateway-help').isHidden())throw Error('Broker timeout missing diagnosis');
  gatewayMode='ok';ticketMode='down';await phone().click('#enable');
  await phone().waitForFunction(()=>document.getElementById('error').textContent.length>0&&!document.getElementById('enable').disabled);
  if(!await phone().locator('#gateway-help').isHidden()||await phone().locator('#check-gateway').getAttribute('data-state')==='error')throw Error('AIS failure blamed on stale gateway');
  console.log('Broker timeout diagnoses broker; later AIS failure does not blame cached gateway');
  ticketMode='ok';
  // Route messages use the same path contract as the controller.
  for(const bad of ['/x/../telephony/workspace','/./telephony/workspace','/telephony.html?embedded=1','/%74elephony/workspace']){
   await phone().evaluate(value=>parent.postMessage({type:'ais-phone-navigate',path:value},location.origin),bad);await p.waitForTimeout(100);
   if(await content().evaluate(()=>location.pathname)!=='/orders')throw Error('Unsafe client navigation accepted');
  }
  const popup=ctx.waitForEvent('page');await p.click('#phone-fallback');const fallback=await popup;await fallback.waitForLoadState();
  await p.click('#phone-fallback');await p.waitForTimeout(500);if(ctx.pages().length!==2||!await fallback.evaluate(()=>!!window.opener))throw Error('Fallback window is not reused with opener');
  await fallback.close();
  if(errors.length)throw Error(errors.join('; '));
  console.log('Validated IPC rejects recursive paths; fallback reuses named window and retains opener');
  console.log('WORKSPACE_REVIEW_REGRESSIONS_PASSED');
 }finally{if(browser)await browser.close();}
})().catch(e=>{console.error(e.message);process.exit(1);});
