// Isolated live-gateway regression: three unassigned browser extensions, no staff calls.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),assert=require('assert'),{execFileSync}=require('child_process');
const root=process.env.AIS_TELEPHONY_PILOT_ROOT||'/Users/mac/Library/Application Support/com.itech.call-pipeline/runtime/work/webrtc-pilot';
const fixtures=process.env.AIS_PHONE_BROWSER_FIXTURES||'/tmp/ais-native-fixtures';
const phoneFixture=fs.readFileSync(path.join(fixtures,'phone.html'),'utf8');
assert(phoneFixture.includes('id="hold-call"'),'Regenerate current phone fixtures with AIS_PHONE_BROWSER_FIXTURES and test/telephony/run.rb');
const repo=path.resolve(__dirname,'../..'),{chromium}=require(path.join(root,'test-tools/node_modules/playwright'));
const secret=JSON.parse(fs.readFileSync(path.join(root,'activation-private/ais-connection.json'))).shared_secret;
const ticket=extension=>{const now=Math.floor(Date.now()/1000),body=Buffer.from(JSON.stringify({v:1,aud:'ais-telephony-gateway',user_id:2147400000+Number(extension),extension,iat:now,exp:now+60,jti:crypto.randomBytes(16).toString('hex')})).toString('base64url');return body+'.'+crypto.createHmac('sha256',secret).update(body).digest('hex');};
const pub=execFileSync('openssl',['x509','-in',path.join(root,'AIS-Office-Telephony.crt'),'-pubkey','-noout']);
const pin=crypto.createHash('sha256').update(execFileSync('openssl',['pkey','-pubin','-outform','DER'],{input:pub})).digest('base64');
(async()=>{let browser;const pages=[];try{
 browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--ignore-certificate-errors-spki-list='+pin,'--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream']});
 for(const extension of ['7779','7778','7776']){
  const context=await browser.newContext({permissions:['microphone','local-network-access']});
  const page=await context.newPage();pages.push(page);
  await context.route('https://ise.itech.pw/**',async route=>{
   const url=new URL(route.request().url());
   if(url.pathname.startsWith('/assets/telephony/')){
    const name=['phone.js','phone.css','jssip.min.js'].find(n=>url.pathname.includes(n.replace(/\.(js|css)$/,''))&&url.pathname.endsWith(n.endsWith('.js')?'.js':'.css'));
    assert(name);const file=path.join(repo,name==='jssip.min.js'?'vendor/assets/javascripts/telephony':name.endsWith('.js')?'app/assets/javascripts/telephony':'app/assets/stylesheets/telephony',name);
    return route.fulfill({contentType:name.endsWith('.js')?'application/javascript':'text/css',body:fs.readFileSync(file)});
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
 const [a,b,c]=pages;
 await a.click('#directory-open');await a.fill('#directory-search','получатель');await a.click('#directory-list button');assert.equal(await a.inputValue('#target'),'7778');
 await a.click('#test-call');await b.waitForFunction(()=>!document.getElementById('answer').disabled,{},{timeout:20000});
 assert.match(await b.innerText('#original-caller'),/Исходный номер: 7779/);
 await b.click('#answer');await b.waitForFunction(()=>!document.getElementById('transfer-call').disabled,{},{timeout:20000});
 await a.waitForFunction(async()=>{const d=await pilotDiagnostics();return d.active&&d.inbound>0&&d.remoteLevel>0;},{},{timeout:25000});
 await b.fill('#transfer-target','https://example.test');await b.click('#transfer-call');assert.match(await b.innerText('#transfer-status'),/внутренний номер/);assert((await b.evaluate(()=>pilotDiagnostics())).active);
 await b.click('#transfer-directory');await b.fill('#directory-search','перевод');await b.click('#directory-list button');assert.equal(await b.inputValue('#transfer-target'),'7776');
 b.once('dialog',dialog=>dialog.dismiss());await b.click('#transfer-call');assert((await b.evaluate(()=>pilotDiagnostics())).active);
 b.once('dialog',dialog=>dialog.accept());await b.click('#transfer-call');
 await c.waitForFunction(()=>!document.getElementById('answer').disabled,{},{timeout:20000});await c.click('#answer');
 await b.waitForFunction(()=>document.getElementById('hangup').disabled,{},{timeout:15000});
 const baseline=await a.evaluate(()=>pilotDiagnostics());
 await a.waitForFunction(async previous=>{const d=await pilotDiagnostics();return d.active&&d.inbound>previous&&d.remoteLevel>0;},baseline.inbound,{timeout:25000}).catch(async error=>{console.error('Transfer audio diagnostics:',await a.evaluate(()=>pilotDiagnostics()),await b.innerText('#call-title'),await c.evaluate(()=>pilotDiagnostics()));throw error;});
 await c.waitForFunction(async()=>{const d=await pilotDiagnostics();return d.active&&d.inbound>0&&d.remoteLevel>0;},{},{timeout:15000});
 await a.click('#hangup');await c.waitForFunction(()=>document.getElementById('hangup').disabled);
 await a.fill('#target','7778');await a.click('#test-call');await b.waitForFunction(()=>!document.getElementById('answer').disabled,{},{timeout:20000});await b.click('#answer');
 await a.waitForFunction(()=>!document.getElementById('transfer-call').disabled,{},{timeout:20000});
 await a.fill('#transfer-target','7776');a.once('dialog',dialog=>dialog.accept());await a.click('#transfer-call');
 await c.waitForFunction(()=>!document.getElementById('answer').disabled,{},{timeout:20000});await c.click('#answer');
 await a.waitForFunction(()=>document.getElementById('hangup').disabled,{},{timeout:15000});
 for(const receiver of [b,c])await receiver.waitForFunction(async()=>{const d=await pilotDiagnostics();return d.active&&d.inbound>0&&d.remoteLevel>0;},{},{timeout:25000});
 await b.click('#hangup');await c.waitForFunction(()=>document.getElementById('hangup').disabled);
 await a.click('#directory-open');await a.fill('#directory-search','105');assert.equal(await a.locator('#directory-list img').count(),0);
 console.log('DIRECTORY_TRANSFER_PASSED: directory selection, raw caller, unsafe input, cancel, incoming/outgoing transfers and two-way audio');
 }finally{for(const page of pages){try{await page.evaluate(async()=>{document.getElementById('hangup').click();await document.getElementById('disable').onclick();});}catch(e){}}if(browser)await browser.close();}
})().catch(error=>{console.error(error.stack);process.exit(1);});
