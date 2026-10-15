// Real Chrome + live gateway test. Uses an unused lease (7779), never an employee phone.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),{execFileSync}=require('child_process');
const root=process.env.AIS_TELEPHONY_PILOT_ROOT || '/Users/mac/Library/Application Support/com.itech.call-pipeline/runtime/work/webrtc-pilot';
const repo=path.resolve(__dirname,'../..');
const {chromium}=require(path.join(root,'test-tools/node_modules/playwright'));
const fixtures=process.env.AIS_PHONE_BROWSER_FIXTURES || '/tmp/ais-native-fixtures';
const secret=JSON.parse(fs.readFileSync(path.join(root,'activation-private/ais-connection.json'))).shared_secret;
const signed=()=>{const now=Math.floor(Date.now()/1000),data=Buffer.from(JSON.stringify({v:1,aud:'ais-telephony-gateway',user_id:2147483647,extension:'7779',iat:now,exp:now+60,jti:crypto.randomBytes(16).toString('hex')})).toString('base64url');return data+'.'+crypto.createHmac('sha256',secret).update(data).digest('hex');};
const pub=execFileSync('openssl',['x509','-in',path.join(root,'AIS-Office-Telephony.crt'),'-pubkey','-noout']);
const der=execFileSync('openssl',['pkey','-pubin','-outform','DER'],{input:pub});
const pin=crypto.createHash('sha256').update(der).digest('base64');
(async()=>{
 let browser,p,other;
 try{
  browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--ignore-certificate-errors-spki-list='+pin,'--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream']});
  const context=await browser.newContext({permissions:['microphone','local-network-access']});
  const errors=[];
  let delayNextTicket=false,slowTicketInFlight=false,overlappingTickets=0,startSlow;
  const slowStarted=new Promise(resolve=>{startSlow=resolve;});
  await context.route('https://ise.itech.pw/**',async route=>{
   const u=new URL(route.request().url());let file;
   if(u.pathname.startsWith('/assets/telephony/')){
    const name=['workspace.js','workspace.css','phone.js','phone.css','jssip.min.js'].find(n=>u.pathname.endsWith(n.endsWith('.js')?'.js':'.css') && u.pathname.includes(n.replace(/\.(js|css)$/, '')));
    if(!name)throw Error('Unexpected asset '+u.pathname);
    file=path.join(repo,name==='jssip.min.js'?'vendor/assets/javascripts/telephony':name.endsWith('.js')?'app/assets/javascripts/telephony':'app/assets/stylesheets/telephony',name);
    return route.fulfill({contentType:name.endsWith('.js')?'application/javascript':'text/css',body:fs.readFileSync(file)});
   }
   if(u.pathname==='/telephony/ticket'){
    const payload={ticket:signed(),extension:'7779',gateway:'https://192.168.1.109:18444'};
    if(slowTicketInFlight)overlappingTickets++;
    if(delayNextTicket){delayNextTicket=false;slowTicketInFlight=true;startSlow();await new Promise(resolve=>setTimeout(resolve,16000));slowTicketInFlight=false;}
    return route.fulfill({contentType:'application/json',body:JSON.stringify(payload)});
   }
   if(u.pathname==='/telephony/caller')return route.fulfill({contentType:'application/json',body:JSON.stringify({number:'7779',clients:[{name:'Тестовый клиент <img>',url:'/clients/1',entities:[{title:'Актуальная заявка',url:'/orders/1'}]}]})});
   if(u.pathname==='/telephony/workspace')file=path.join(fixtures,'workspace.html');
   if(u.pathname==='/telephony')file=path.join(fixtures,'phone.html');
   if(file)return route.fulfill({contentType:'text/html',body:fs.readFileSync(file,'utf8').replaceAll('7771','7779')});
   return route.fulfill({contentType:'text/html',body:'<!doctype html><title>АИС '+u.pathname+'</title><main><a href="/orders">Заявки</a><a href="/clients">Клиенты</a><form action="/service_jobs" method="post"><input name="test" value="text"><button>Сохранить</button></form></main>'});
  });
  p=await context.newPage();await p.setViewportSize({width:1440,height:900});p.on('pageerror',e=>errors.push(e.message));
  await p.goto('https://ise.itech.pw/telephony/workspace?path=/clients');
  const initialMain=p.frames().find(f=>f.parentFrame()&&f.url().includes('/clients'));await initialMain.evaluate(()=>window.parent.postMessage({type:'ais-phone-state',state:'ready',status:'Spoof'},location.origin));await p.waitForTimeout(100);if(await p.locator('#phone-dot').getAttribute('data-state')!=='off')throw Error('Untrusted frame changed phone state');
  await p.click('#phone-toggle');
  const phone=()=>p.frames().find(f=>f.url().includes('/telephony?'));
  await p.waitForFunction(()=>document.getElementById('ais-workspace-phone').contentDocument?.getElementById('enable'));
  await phone().click('#enable');
  await p.waitForFunction(()=>document.getElementById('phone-dot').dataset.state==='ready',{},{timeout:20000});
  await phone().fill('#target','779');await phone().click('#test-call');
  const stats=()=>phone().evaluate(()=>window.pilotDiagnostics());
  await phone().waitForFunction(async()=>{const s=await window.pilotDiagnostics();return s.active&&s.inbound>0&&s.remoteLevel>0;},{},{timeout:25000});
  const before=await stats(), engine=await phone().evaluate(()=>window.performance.timeOrigin);
  delayNextTicket=true;
  await Promise.race([slowStarted,new Promise((_,reject)=>setTimeout(()=>reject(Error('Renewal did not start')),20000))]);
  await phone().waitForTimeout(17000);
  if(!((await stats()).active)||overlappingTickets)throw Error('Slow AIS renewal dropped call or overlapped requests');
  console.log('16-second AIS renewal preserves real audio and does not overlap heartbeat requests');
  await p.click('#phone-close');
  await phone().evaluate(()=>window.parent.postMessage({type:'ais-phone-state',state:'call',enabled:true,call:true,waiting:2,status:'Разговор',callTitle:'Тест очереди'},location.origin));
  await p.waitForFunction(()=>!document.getElementById('phone-panel').hidden&&document.getElementById('phone-summary').textContent.includes('Ожидают: 2'));
  if(!((await stats()).active))throw Error('Queue notification interrupted current audio');
  await p.click('#phone-close');
  console.log('Queue count opens panel during a live call without interrupting audio');
  let main=p.frames().find(f=>f.parentFrame() && f.url().includes('/clients'));
  await main.click('a[href="/orders"]');
  await p.waitForURL(/path=%2Forders/);
  main=p.frames().find(f=>f.url().endsWith('/orders'));
  await main.click('button');await p.waitForURL(/path=%2Fservice_jobs/);
  const historyLength=await p.evaluate(()=>history.length);
  for(let i=0;i<2;i++){
   await p.goBack();await p.waitForFunction(()=>document.getElementById('ais-workspace-content').contentWindow.location.pathname==='/orders');
   await p.goBack();await p.waitForFunction(()=>document.getElementById('ais-workspace-content').contentWindow.location.pathname==='/clients');
   await p.goForward();await p.waitForFunction(()=>document.getElementById('ais-workspace-content').contentWindow.location.pathname==='/orders');
   await p.goForward();await p.waitForFunction(()=>document.getElementById('ais-workspace-content').contentWindow.location.pathname==='/service_jobs');
  }
  if(await p.evaluate(()=>history.length)!==historyLength)throw Error('Back/Forward created new history entries');
  await phone().waitForTimeout(2000);
  const after=await stats();
  if(await phone().evaluate(()=>window.performance.timeOrigin)!==engine||!after.active||after.inbound<=before.inbound||after.outbound<=before.outbound)throw Error('Navigation interrupted actual audio');
  console.log('Real call survives full page navigation, POST form, browser Back and collapsed panel');
  other=await context.newPage();await other.goto('https://ise.itech.pw/telephony/workspace');await other.click('#phone-toggle');
  const second=other.frames().find(f=>f.url().includes('/telephony?'));await second.click('#enable');
  await second.waitForFunction(()=>document.getElementById('error').textContent.includes('другом окне'),{},{timeout:20000});
  if(!((await stats()).active))throw Error('Second tab interrupted first call');
  console.log('Second tab lease rejected; first call preserved');
  await other.close();other=null;
  await p.click('#phone-toggle');await phone().click('#hangup');await p.click('#phone-close');
  execFileSync(path.join(root,'vm.sh'),['shell','p','sudo','asterisk','-rx','channel originate PJSIP/7779 application Echo'],{stdio:'pipe'});
  await p.waitForFunction(()=>!document.getElementById('phone-panel').hidden,{},{timeout:15000});
  await phone().waitForFunction(()=>!document.getElementById('answer').disabled);
  await phone().waitForFunction(()=>document.getElementById('caller-context').textContent.includes('Актуальная заявка'));
  await p.screenshot({path:path.join(root,'native-phone-preview.png')});
  if(await phone().locator('#caller-context img').count())throw Error('Unsafe caller HTML');
  await phone().click('#caller-context a');
  await p.waitForURL(/path=%2Forders%2F1/);
  await phone().click('#answer');await phone().waitForFunction(async()=>{const d=await pilotDiagnostics();return d.active&&d.remoteLevel>0;},{},{timeout:25000});
  console.log('Incoming panel opens, client links navigate workspace, incoming answer has actual audio');
  p.once('dialog',d=>d.dismiss());await p.click('#phone-disable');if(!(await stats()).active)throw Error('Cancel disable ended call');
  p.once('dialog',d=>d.accept());await p.click('#phone-disable');
  await p.waitForFunction(()=>document.getElementById('phone-dot').dataset.state==='off',{},{timeout:10000});await p.waitForTimeout(3500);if(await p.locator('#phone-dot').getAttribute('data-state')!=='off')throw Error('Delayed stop changed disabled state');
  await phone().evaluate(()=>{if(document.getElementById('remote').srcObject)throw Error('Remote media retained');});
  console.log('Disable confirmation keeps call on cancel, ends and unregisters on confirm');
  await context.route('https://192.168.1.109:18444/**',r=>r.abort('failed'));
  await phone().click('#enable');await p.waitForFunction(()=>document.getElementById('phone-dot').dataset.state==='error');
  if(await phone().locator('#gateway-help').isHidden())throw Error('No certificate/network diagnostic link');
  console.log('Unavailable gateway is red with TLS/network check link');
  if(errors.length)throw Error(errors.join('; '));
  console.log('NATIVE_WORKSPACE_CHROME_PASSED');
 }catch(e){if(p){for(const f of p.frames()){if(f.url().includes('/telephony?')){try{console.error('Phone diagnostic:',await f.locator('#status').innerText(),await f.locator('#error').innerText());}catch(x){}}}}throw e;}finally{
  if(p){try{const f=p.frames().find(f=>f.url().includes('/telephony?'));if(f)await f.evaluate(async()=>{document.getElementById('hangup').click();await document.getElementById('disable').onclick();});}catch(e){}}
  if(browser)await browser.close();
 }
})().catch(e=>{console.error(e.message);process.exit(1);});
