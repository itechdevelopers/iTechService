// Live hold/music regression on unassigned browser extensions; no staff calls.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),assert=require('assert'),{execFileSync,spawn}=require('child_process');
const root=process.env.AIS_TELEPHONY_PILOT_ROOT||'/Users/mac/Library/Application Support/com.itech.call-pipeline/runtime/work/webrtc-pilot';
const fixtures=process.env.AIS_PHONE_BROWSER_FIXTURES||'/tmp/ais-native-fixtures';
const phoneFixture=fs.readFileSync(path.join(fixtures,'phone.html'),'utf8');
assert(phoneFixture.includes('id="hold-call"'),'Regenerate current phone fixtures with AIS_PHONE_BROWSER_FIXTURES and test/telephony/run.rb');
const repo=path.resolve(__dirname,'../..'),{chromium}=require(path.join(root,'test-tools/node_modules/playwright'));
const secret=JSON.parse(fs.readFileSync(path.join(root,'activation-private/ais-connection.json'))).shared_secret;
const ticket=extension=>{const now=Math.floor(Date.now()/1000),body=Buffer.from(JSON.stringify({v:1,aud:'ais-telephony-gateway',user_id:2147400000+Number(extension),extension,iat:now,exp:now+60,jti:crypto.randomBytes(16).toString('hex')})).toString('base64url');return body+'.'+crypto.createHmac('sha256',secret).update(body).digest('hex');};
const pub=execFileSync('openssl',['x509','-in',path.join(root,'AIS-Office-Telephony.crt'),'-pubkey','-noout']);
const pin=crypto.createHash('sha256').update(execFileSync('openssl',['pkey','-pubin','-outform','DER'],{input:pub})).digest('base64');
const vm=require('vm'),source=fs.readFileSync(path.join(repo,'app/assets/javascripts/telephony/phone.js'),'utf8'),helpers={};
vm.createContext(helpers);vm.runInContext(source.slice(source.indexOf('function displayNumber('),source.indexOf('function micError(')),helpers);
for(const [prefix,city] of [['VDK','во Владивосток'],['SAH','в Южно-Сахалинск'],['USS','в Уссурийск'],['USSF','в Уссурийск'],['HAB','в Хабаровск'],['KHD','в Хабаровск']]){
 assert.equal(helpers.originalCallerText(prefix+'79146896537'),'Исходный номер: '+prefix+'79146896537 · Звонок '+city);
 assert.equal(helpers.displayNumber(prefix+'79146896537'),'79146896537');
}
assert.equal(helpers.originalCallerText('UNKNOWN79146896537'),'Исходный номер: UNKNOWN79146896537');
assert.equal(helpers.originalCallerText('HABIT79146896537'),'Исходный номер: HABIT79146896537');
console.log('REGION_CAPTIONS_PASSED');
function holdFaultSocket(){
 const RealSocket=JsSIP.WebSocketInterface;
 JsSIP.WebSocketInterface=class extends RealSocket{
  set ondata(callback){this.callback=callback;}
  get ondata(){return data=>{const header=name=>(data.match(new RegExp('^'+name+':\\s*(.*)$','im'))||[])[1]?.trim();
   if(this.lateCseq&&data.startsWith('SIP/2.0 200')&&header('CSeq')===this.lateCseq){this.lateCseq=null;const callback=this.callback;setTimeout(()=>callback(data),1800);return;}
   this.callback(data);
  };}
  send(data){
   const header=name=>(data.match(new RegExp('^'+name+':\\s*(.*)$','im'))||[])[1]?.trim();
   if(data.startsWith('INVITE ')&&header('To')?.includes(';tag=')&&window.testHoldFault){
    if(window.testHoldFault==='late'){this.lateCseq=header('CSeq');return super.send(data);}
    const code=window.testHoldFault==='reject'?488:100;
    const reply=['SIP/2.0 '+code+(code===488?' Not Acceptable Here':' Trying'),'Via: '+header('Via'),'From: '+header('From'),'To: '+header('To'),'Call-ID: '+header('Call-ID'),'CSeq: '+header('CSeq'),'Content-Length: 0','',''].join('\r\n');
    setTimeout(()=>this.ondata(reply),20);return true;
   }
   return super.send(data);
  }
 };
}
(async()=>{let browser,consoleProcess;const pages=[],musicEvents=[],pageErrors=[];try{
 consoleProcess=spawn(path.join(root,'vm.sh'),['shell','p','sudo','asterisk','-rvvv'],{stdio:['pipe','pipe','pipe'],detached:true});
 let consoleText='';consoleProcess.stdout.on('data',chunk=>{consoleText+=chunk.toString();const lines=consoleText.split('\n');consoleText=lines.pop();for(const line of lines)if(/(?:Started|Stopped) music on hold/.test(line))musicEvents.push(line.replace(/\x1b\[[0-9;]*m/g,''));});
 browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--ignore-certificate-errors-spki-list='+pin,'--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream']});
 for(const extension of ['7779','7778']){
  const context=await browser.newContext({permissions:['microphone','local-network-access']});
  const page=await context.newPage();pages.push(page);page.on('pageerror',error=>pageErrors.push(error.message));
  await context.route('https://ise.itech.pw/**',async route=>{
   const url=new URL(route.request().url());
   if(url.pathname.startsWith('/assets/telephony/')){
    const name=['phone.js','phone.css','jssip.min.js'].find(n=>url.pathname.includes(n.replace(/\.(js|css)$/,''))&&url.pathname.endsWith(n.endsWith('.js')?'.js':'.css'));
    assert(name);const file=path.join(repo,name==='jssip.min.js'?'vendor/assets/javascripts/telephony':name.endsWith('.js')?'app/assets/javascripts/telephony':'app/assets/stylesheets/telephony',name);
    let body=fs.readFileSync(file,'utf8');if(name==='jssip.min.js')body+='\n;('+holdFaultSocket.toString()+')();';
    return route.fulfill({contentType:name.endsWith('.js')?'application/javascript':'text/css',body});
   }
   if(url.pathname==='/telephony/ticket')return route.fulfill({json:{ticket:ticket(extension),extension,gateway:'https://192.168.1.109:18444'}});
   if(url.pathname==='/telephony/caller')return route.fulfill({json:{number:url.searchParams.get('number'),clients:[]}});
   if(url.pathname==='/telephony/directory')return route.fulfill({json:{entries:[{number:'7778',label:'Тестовый получатель',group:'Тест'}, {number:'7776',label:'Тестовый перевод',group:'Тест'}, {number:'105',label:'<img src=x onerror=alert(1)>',group:'Океанский 90'}]}});
   if(url.pathname==='/telephony')return route.fulfill({contentType:'text/html',body:phoneFixture.replaceAll('7771',extension)});
   throw Error('Unexpected AIS URL '+url.pathname);
  });
  await page.goto('https://ise.itech.pw/telephony');await page.click('#enable');
  await page.waitForFunction(()=>document.getElementById('status').textContent.includes('Готов к звонкам'),{},{timeout:25000});
 }
 const [a,b]=pages;
 await a.fill('#target','7778');await a.click('#test-call');await b.waitForFunction(()=>!document.getElementById('answer').disabled,{},{timeout:20000});await b.click('#answer');
 for(const phone of pages)await phone.waitForFunction(async()=>{const d=await pilotDiagnostics();return d.active&&d.inbound>0&&d.remoteLevel>0;},{},{timeout:25000});
 await b.waitForFunction(()=>!document.getElementById('hold-call').disabled,{},{timeout:15000});
 for(let attempt=0;attempt<2;attempt++){
  const before=await a.evaluate(()=>pilotDiagnostics());await b.click('#hold-call');
  await b.waitForFunction(()=>document.getElementById('hold-call').getAttribute('aria-pressed')==='true'&&!document.getElementById('hold-call').disabled,{},{timeout:20000});
  assert.equal(await b.innerText('#hold-status'),'Клиент на удержании');
  await a.waitForFunction(async previous=>{const d=await pilotDiagnostics();return d.active&&d.inbound>previous&&d.remoteLevel>0;},before.inbound,{timeout:15000});
  assert(musicEvents.filter(line=>line.includes('Started')).length>attempt,'No Asterisk music-on-hold start');
  await b.click('#hold-call');await b.waitForFunction(()=>document.getElementById('hold-call').getAttribute('aria-pressed')==='false'&&!document.getElementById('hold-call').disabled,{},{timeout:20000});
  for(const phone of pages)await phone.waitForFunction(async()=>{const d=await pilotDiagnostics();return d.active&&d.inbound>0&&d.remoteLevel>0;},{},{timeout:20000});
  assert(musicEvents.filter(line=>line.includes('Stopped')).length>attempt,'No Asterisk music-on-hold stop');
 }
 await b.click('#hold-call');await b.waitForFunction(()=>!document.getElementById('hold-call').disabled&&document.getElementById('hold-call').getAttribute('aria-pressed')==='true');
 await a.click('#hangup');await b.waitForFunction(()=>document.getElementById('hangup').disabled);assert(await b.locator('#hold-call').isDisabled());assert.equal(await b.innerText('#hold-status'),'');
 for(const endMode of ['hold','mute']){
  await a.fill('#target','7778');await a.click('#test-call');await b.waitForFunction(()=>!document.getElementById('answer').disabled,{},{timeout:20000});await b.click('#answer');
  await b.waitForFunction(()=>!document.getElementById('hold-call').disabled,{},{timeout:20000});
  await a.waitForFunction(async()=>{const d=await pilotDiagnostics();return d.active&&d.remoteLevel>0;},{},{timeout:15000});
  if(endMode==='hold'){await b.click('#hold-call');await b.waitForFunction(()=>!document.getElementById('hold-call').disabled&&document.getElementById('hold-call').getAttribute('aria-pressed')==='true');}
  else await b.click('#mute');
  await a.click('#hangup');await b.waitForFunction(()=>document.getElementById('hangup').disabled);
 }
 // A fresh call after ending muted must have an enabled microphone too.
 await a.fill('#target','7778');await a.click('#test-call');await b.waitForFunction(()=>!document.getElementById('answer').disabled,{},{timeout:20000});await b.click('#answer');
 await a.waitForFunction(async()=>{const d=await pilotDiagnostics();return d.active&&d.remoteLevel>0;},{},{timeout:15000});await a.click('#hangup');await b.waitForFunction(()=>document.getElementById('hangup').disabled);
 const connectAgain=async()=>{await a.fill('#target','7778');await a.click('#test-call');await b.waitForFunction(()=>!document.getElementById('answer').disabled,{},{timeout:20000});await b.click('#answer');await b.waitForFunction(()=>!document.getElementById('hold-call').disabled);await a.waitForFunction(async()=>{const d=await pilotDiagnostics();return d.active&&d.remoteLevel>0;},{},{timeout:15000});};
 await connectAgain();await b.evaluate(()=>{window.testHoldFault='reject';});await b.click('#hold-call');
 await b.waitForFunction(()=>document.getElementById('hangup').disabled);assert.match(await b.innerText('#call-title'),/АТС не приняла удержание/);await a.waitForFunction(()=>document.getElementById('hangup').disabled);
 await b.evaluate(()=>{window.testHoldFault=null;});await connectAgain();await a.click('#hangup');await b.waitForFunction(()=>document.getElementById('hangup').disabled);
 await connectAgain();await b.evaluate(()=>{window.testHoldFault='trying';});await b.click('#hold-call');
 await b.waitForFunction(()=>document.getElementById('hold-status').textContent.includes('завершите звонок и перезвоните'),{},{timeout:20000});assert(await b.locator('#test-call').isDisabled());
 await b.click('#hold-call');assert.match(await b.innerText('#hold-status'),/завершите звонок и перезвоните/);
 await a.click('#hangup');await b.waitForFunction(()=>document.getElementById('hangup').disabled);await b.evaluate(()=>{window.testHoldFault=null;});
 await connectAgain();await b.evaluate(()=>{window.testHoldFault='late';});await b.click('#hold-call');assert.equal(await b.innerText('#hold-status'),'Включаем удержание…');await a.click('#hangup');await b.waitForFunction(()=>document.getElementById('hangup').disabled);
 await b.evaluate(()=>{window.testHoldFault=null;});await connectAgain();await b.waitForTimeout(2000);assert.equal(await b.getAttribute('#hold-call','aria-pressed'),'false');await a.waitForFunction(async()=>{const d=await pilotDiagnostics();return d.active&&d.remoteLevel>0;});await a.click('#hangup');await b.waitForFunction(()=>document.getElementById('hangup').disabled);
 console.log('HOLD_FAILURES_PASSED: rejected re-INVITE, endless 100 Trying, pending status, late 200 and next-call mic');
 assert.equal(pageErrors.length,0,pageErrors.join('; '));
 console.log('HOLD_MUSIC_PASSED: music start/stop confirmed by Asterisk, received RTP/audio on held caller, repeated resume with two-way audio, hangup while held');
 console.log('Music event count:',musicEvents.length);
 }finally{for(const page of pages){try{await page.evaluate(async()=>{document.getElementById('hangup').click();await document.getElementById('disable').onclick();});}catch(e){}}if(browser)await browser.close();if(consoleProcess){consoleProcess.stdin.destroy();consoleProcess.stdout.destroy();consoleProcess.stderr.destroy();try{process.kill(-consoleProcess.pid,'SIGTERM');}catch(e){}consoleProcess.unref();}}
})().catch(error=>{console.error(error.stack);process.exitCode=1;});
