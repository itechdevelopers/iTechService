// Call references: actual outgoing/incoming SIP IDs, clipboard and server correlation.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),assert=require('assert'),{execFileSync,spawn}=require('child_process');
const root=process.env.AIS_TELEPHONY_PILOT_ROOT||'/Users/mac/Library/Application Support/com.itech.call-pipeline/runtime/work/webrtc-pilot';
const fixtures=process.env.AIS_PHONE_BROWSER_FIXTURES||'/tmp/ais-native-fixtures';
const phoneFixture=fs.readFileSync(path.join(fixtures,'phone.html'),'utf8');
assert(phoneFixture.includes('id="call-reference"'),'Regenerate current phone fixtures with AIS_PHONE_BROWSER_FIXTURES and test/telephony/run.rb');
const repo=path.resolve(__dirname,'../..'),{chromium}=require(path.join(root,'test-tools/node_modules/playwright'));
const secret=JSON.parse(fs.readFileSync(path.join(root,'activation-private/ais-connection.json'))).shared_secret;
const ticket=extension=>{const now=Math.floor(Date.now()/1000),body=Buffer.from(JSON.stringify({v:1,aud:'ais-telephony-gateway',user_id:2147400000+Number(extension),extension,iat:now,exp:now+60,jti:crypto.randomBytes(16).toString('hex')})).toString('base64url');return body+'.'+crypto.createHmac('sha256',secret).update(body).digest('hex');};
const pub=execFileSync('openssl',['x509','-in',path.join(root,'AIS-Office-Telephony.crt'),'-pubkey','-noout']);
const pin=crypto.createHash('sha256').update(execFileSync('openssl',['pkey','-pubin','-outform','DER'],{input:pub})).digest('base64');
const helpers={};require('vm').runInNewContext(fs.readFileSync(path.join(repo,'app/assets/javascripts/telephony/phone.js'),'utf8').split('function callReference(request){')[1].split('function showReference')[0].replace(/^/, 'function callReference(request){'),helpers);
assert.equal(helpers.callReference({call_id:'a-b_c@host'}),'a-b_c@host');assert.equal(helpers.callReference({call_id:'bad\nvalue'}),null);assert.equal(helpers.callReference({call_id:'x'.repeat(257)}),null);
const run=(...args)=>execFileSync(path.join(root,'vm.sh'),['shell','p','sudo',...args],{encoding:'utf8'});
const py=code=>run('python3','-c',code);
(async()=>{let browser,page,installed=false;try{
 execFileSync(path.join(root,'vm.sh'),['copy',path.join(__dirname,'gateway-dialplan.conf'),'p:/tmp/ais-reference-review-source.conf']);
 py(`from pathlib import Path
import subprocess
p=Path('/etc/asterisk/extensions.conf');assert 'ais-reference-review.conf' not in p.read_text()
s=Path('/tmp/ais-reference-review-source.conf').read_text();audit=s[s.index('[ais-browser-log-reference]'):].replace('ais-browser-log-reference','ais-reference-review-log')
dial='[ais-browser-outbound]\\nexten => 7799,1,Gosub(ais-browser-permission,s,1(7779))\\n same => n,Goto(ais-reference-review,out,1)\\n[ais-reference-review]\\nexten => out,1,Gosub(ais-reference-review-log,s,1)\\n same => n,Answer()\\n same => n,Echo()\\nexten => incoming,1,Dial(PJSIP/7779,20,b(ais-reference-review-log^s^1))\\n same => n,Hangup()\\n'
Path('/etc/asterisk/ais-reference-review.conf').write_text(dial+audit)
p.write_text(p.read_text()+'\\n#include ais-reference-review.conf\\n')
subprocess.check_call(['asterisk','-rx','dialplan reload'])`);installed=true;
 browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--ignore-certificate-errors-spki-list='+pin,'--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream']});
 const context=await browser.newContext({permissions:['microphone','local-network-access','clipboard-read','clipboard-write']});page=await context.newPage();
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await context.route('https://ise.itech.pw/**',async route=>{
  const url=new URL(route.request().url());
  if(url.pathname.startsWith('/assets/telephony/')){
   const name=['phone.js','phone.css','jssip.min.js'].find(n=>url.pathname.includes(n.replace(/\.(js|css)$/,''))&&url.pathname.endsWith(n.endsWith('.js')?'.js':'.css'));
   assert(name);const file=path.join(repo,name==='jssip.min.js'?'vendor/assets/javascripts/telephony':name.endsWith('.js')?'app/assets/javascripts/telephony':'app/assets/stylesheets/telephony',name);
   return route.fulfill({contentType:name.endsWith('.js')?'application/javascript':'text/css',body:fs.readFileSync(file,'utf8')});
  }
  if(url.pathname==='/telephony/ticket')return route.fulfill({json:{ticket:ticket('7779'),extension:'7779',gateway:'https://192.168.1.109:18444'}});
  if(url.pathname==='/telephony/caller')return route.fulfill({json:{number:url.searchParams.get('number'),clients:[]}});
  if(url.pathname==='/telephony')return route.fulfill({contentType:'text/html',body:phoneFixture.replaceAll('7771','7779')});
  throw Error('Unexpected URL '+url.pathname);
 });
 await page.goto('https://ise.itech.pw/telephony');await page.click('#enable');await page.waitForFunction(()=>document.getElementById('status').textContent.includes('Готов к звонкам'),{},{timeout:25000});
 const audio=()=>page.waitForFunction(async()=>{const d=await pilotDiagnostics();return d.active&&d.inbound>0&&d.remoteLevel>0;},{},{timeout:20000});
 const ids=[];
 for(const incoming of [false,true]){
  if(incoming)run('asterisk','-rx','channel originate Local/incoming@ais-reference-review/n application Echo');
  else{await page.fill('#target','7799');await page.click('#test-call');}
  if(incoming){await page.waitForFunction(()=>!document.getElementById('answer').disabled,{},{timeout:20000});await page.click('#answer');}
  await audio();const id=await page.getAttribute('#call-reference','data-reference');assert(id&&id.length>8);ids.push(id);
  const logs=py("from pathlib import Path;print('\\n'.join(line for line in Path('/var/log/asterisk/messages.log').read_text().splitlines() if 'AIS_CALL_REF sip=' in line)[-8000:])");
  assert(logs.includes('AIS_CALL_REF sip='+encodeURIComponent(id)+' gateway='),'UI ID does not map to Asterisk CDR identifier');
  await page.locator('#ais-phone').screenshot({path:'/tmp/ais-call-reference-preview.png'});
  await page.click('#call-reference');assert.equal(await page.evaluate(()=>navigator.clipboard.readText()),id);
  await page.click('#hangup');await page.waitForFunction(()=>document.getElementById('hangup').disabled);
  assert.equal(await page.getAttribute('#call-reference','data-reference'),id,'Call ID lost after hangup');
 }
 assert.notEqual(ids[0],ids[1]);assert.deepEqual(errors,[]);console.log('UNIQUE_IDS_OUTGOING_INCOMING_COPY_PERSIST_AND_SERVER_CDR_LINK_PASSED');
 }finally{
  if(page){try{await page.evaluate(async()=>{document.getElementById('hangup').click();await document.getElementById('disable').onclick();});}catch(e){}}
  if(browser)await browser.close();
  if(installed)py("from pathlib import Path;import subprocess;p=Path('/etc/asterisk/extensions.conf');p.write_text(p.read_text().replace('\\n#include ais-reference-review.conf\\n',''));Path('/etc/asterisk/ais-reference-review.conf').unlink(missing_ok=True);subprocess.check_call(['asterisk','-rx','dialplan reload'])");
 }
})().catch(e=>{console.error(e.stack);process.exit(1);});
