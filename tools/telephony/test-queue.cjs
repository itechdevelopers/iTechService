// Live hold/music regression on unassigned browser extensions; no staff calls.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),assert=require('assert'),{execFileSync,spawn}=require('child_process');
const root=process.env.AIS_TELEPHONY_PILOT_ROOT||'/Users/mac/Library/Application Support/com.itech.call-pipeline/runtime/work/webrtc-pilot';
const fixtures=process.env.AIS_PHONE_BROWSER_FIXTURES||'/tmp/ais-native-fixtures';
const phoneFixture=fs.readFileSync(path.join(fixtures,'phone.html'),'utf8');
assert(phoneFixture.includes('id="waiting-panel"'),'Regenerate current phone fixtures with AIS_PHONE_BROWSER_FIXTURES and test/telephony/run.rb');
const repo=path.resolve(__dirname,'../..'),{chromium}=require(path.join(root,'test-tools/node_modules/playwright'));
const secret=JSON.parse(fs.readFileSync(path.join(root,'activation-private/ais-connection.json'))).shared_secret;
const ticket=extension=>{const now=Math.floor(Date.now()/1000),body=Buffer.from(JSON.stringify({v:1,aud:'ais-telephony-gateway',user_id:2147400000+Number(extension),extension,iat:now,exp:now+60,jti:crypto.randomBytes(16).toString('hex')})).toString('base64url');return body+'.'+crypto.createHmac('sha256',secret).update(body).digest('hex');};
const pub=execFileSync('openssl',['x509','-in',path.join(root,'AIS-Office-Telephony.crt'),'-pubkey','-noout']);
const pin=crypto.createHash('sha256').update(execFileSync('openssl',['pkey','-pubin','-outform','DER'],{input:pub})).digest('base64');
const run=(...args)=>execFileSync(path.join(root,'vm.sh'),['shell','p','sudo',...args],{encoding:'utf8'});
const review='/tmp/ais-queue-review';
const snapshot=extension=>JSON.parse(run('python3',review+'/queue-review.py','snapshot',extension));
(async()=>{let browser,installed=false;const pages=[],errors=[];try{
 const uid=execFileSync(path.join(root,'vm.sh'),['shell','p','id','-u'],{encoding:'utf8'}).trim();assert(/^\d+$/.test(uid));
 run('mkdir','-p',review);run('chown',uid,review);
 for(const file of ['queue_state.py','gateway-queues.conf','gateway-dialplan.conf','collector.py','queue-review.py'])execFileSync(path.join(root,'vm.sh'),['copy',path.join(__dirname,file),'p:'+review+'/'+file]);
 run('python3',review+'/queue-review.py','install');installed=true;
 browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--ignore-certificate-errors-spki-list='+pin,'--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream']});
 for(const extension of ['7779','7778']){
  const context=await browser.newContext({permissions:['microphone','local-network-access']});
  const page=await context.newPage();pages.push(page);page.on('pageerror',error=>errors.push(error.message));
  await context.route('https://192.168.1.109:18444/ais/waiting',route=>route.fulfill({headers:{'Access-Control-Allow-Origin':'https://ise.itech.pw','Access-Control-Allow-Headers':'Content-Type','Access-Control-Allow-Methods':'POST, OPTIONS','Access-Control-Allow-Private-Network':'true'},json:route.request().method()==='OPTIONS'?{}:snapshot(extension)}));
  await context.route('https://ise.itech.pw/**',async route=>{
   const url=new URL(route.request().url());
   if(url.pathname.startsWith('/assets/telephony/')){
    const name=['phone.js','phone.css','jssip.min.js'].find(n=>url.pathname.includes(n.replace(/\.(js|css)$/,''))&&url.pathname.endsWith(n.endsWith('.js')?'.js':'.css'));
    assert(name);const file=path.join(repo,name==='jssip.min.js'?'vendor/assets/javascripts/telephony':name.endsWith('.js')?'app/assets/javascripts/telephony':'app/assets/stylesheets/telephony',name);
    return route.fulfill({contentType:name.endsWith('.js')?'application/javascript':'text/css',body:fs.readFileSync(file,'utf8')});
   }
   if(url.pathname==='/telephony/ticket')return route.fulfill({json:{ticket:ticket(extension),extension,gateway:'https://192.168.1.109:18444'}});
   if(url.pathname==='/telephony/caller')return route.fulfill({json:{number:url.searchParams.get('number'),clients:[{name:'Тестовый клиент <img>',url:'/clients/1',entities:[]}]}});
   if(url.pathname==='/telephony/directory')return route.fulfill({json:{entries:[]}});
   if(url.pathname==='/telephony')return route.fulfill({contentType:'text/html',body:phoneFixture.replaceAll('7771',extension)});
   throw Error('Unexpected AIS URL '+url.pathname);
  });
  await page.goto('https://ise.itech.pw/telephony');await page.click('#enable');
  await page.waitForFunction(()=>document.getElementById('status').textContent.includes('Готов к звонкам'),{},{timeout:25000});
 }
 const [caller,agent]=pages;
 const audio=page=>page.waitForFunction(async()=>{const d=await pilotDiagnostics();return d.active&&d.inbound>0&&d.remoteLevel>0;},{},{timeout:25000});
 await agent.fill('#target','779');await agent.click('#test-call');await audio(agent);
 await caller.fill('#target','7799');await caller.click('#test-call');
 await agent.waitForFunction(()=>document.getElementById('waiting-list').textContent.includes('7779'),{},{timeout:20000});
 await audio(caller);assert(await caller.isDisabled('#hold-call'),'Queue answered before a member');
 console.log('QUEUED_CALLER_HEARS_EARLY_MEDIA_WITHOUT_ANSWER');
 assert(await agent.isDisabled('#answer'),'Busy agent was offered a second SIP dialogue');
 assert((await agent.innerText('#call-title')).includes('779'),'Current call was replaced');
 await audio(agent);assert.equal(snapshot('7778').waiting.length,1);
 assert.equal(snapshot('7779').waiting.length,0,'Personal queue leaked to another employee');
 console.log('BUSY_CALL_PRESERVED_AND_WAITING_VISIBLE');
 const callId=snapshot('7778').waiting.find(item=>item.number==='7779').id.split(':').pop();
 // A second synthetic caller is entirely local to the gateway, no staff phone.
 run('asterisk','-rx','channel originate Local/9797@ais-queue-review/n application Echo');
 await agent.waitForFunction(()=>document.querySelectorAll('#waiting-list .waiting-card').length===2,{},{timeout:15000});
 assert.deepEqual(snapshot('7778').waiting.map(item=>item.position),[1,2]);
 console.log('TWO_WAITING_FIFO');
 await agent.click('#hangup');
 await agent.waitForFunction(()=>!document.getElementById('answer').disabled,{},{timeout:25000});
 assert((await agent.innerText('#call-title')).includes('7779'),'Oldest caller was not delivered first');
 await agent.click('#answer');await audio(caller);await audio(agent);
 await agent.waitForFunction(()=>document.querySelectorAll('#waiting-list .waiting-card').length===1,{},{timeout:15000});
 await agent.waitForFunction(()=>document.getElementById('waiting-recent').textContent.includes('Принят в браузере'),{},{timeout:15000});
 assert.deepEqual(JSON.parse(run('python3',review+'/queue-review.py','identityproof')),{caller:true,agent:true});
 console.log('FREE_AGENT_RECEIVES_OLDEST_AND_TWO_WAY_AUDIO');
 run('python3',review+'/queue-review.py','cancel');
 await agent.waitForFunction(()=>document.querySelectorAll('#waiting-list .waiting-card').length===0,{},{timeout:15000});
 await agent.waitForFunction(()=>document.getElementById('waiting-recent').textContent.includes('Покинул очередь'),{},{timeout:15000});
 await agent.locator('#waiting-panel summary').click();
 assert((await agent.innerText('#waiting-recent')).includes('Покинул очередь'));
 assert(await agent.locator('#waiting-recent img').count()===0);
 console.log('CANCELLED_CALL_RETAINED_WITHOUT_FALSE_MISSED');
 await caller.click('#hangup');await agent.waitForFunction(()=>document.getElementById('hangup').disabled);
 assert.equal(JSON.parse(run('python3',review+'/queue-review.py','answerproof',callId)),'7778','CDR lost actual answering employee');
 console.log('QUEUE_TRANSFER_IDENTITY_AND_CDR_ANSWERER_PRESERVED');
 await caller.fill('#target','7798');await caller.click('#test-call');
 await agent.waitForFunction(()=>!document.getElementById('answer').disabled,{},{timeout:25000});await agent.click('#answer');await audio(caller);await audio(agent);
 console.log('SHARED_QUEUE_FREE_AGENT_AUDIO');
 await caller.click('#hangup');await agent.waitForFunction(()=>document.getElementById('hangup').disabled);
 assert.deepEqual(errors,[]);console.log('LIVE_QUEUE_CHROME_PASSED');
 }finally{
  for(const page of pages){try{await page.evaluate(async()=>{document.getElementById('hangup').click();await document.getElementById('disable').onclick();});}catch(e){}}
  if(browser)await browser.close();if(installed)run('python3',review+'/queue-review.py','remove');
 }
})().catch(e=>{console.error(e.stack);process.exit(1);});
