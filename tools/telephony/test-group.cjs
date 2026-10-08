const path=require('path'), fs=require('fs'), crypto=require('crypto'), {execFileSync}=require('child_process');
const pilot=process.env.AIS_TELEPHONY_PILOT_ROOT||'/Users/mac/Library/Application Support/com.itech.call-pipeline/runtime/work/webrtc-pilot';
const {chromium}=require(path.join(pilot,'test-tools/node_modules/playwright'));
const vm=path.join(pilot,'vm.sh');
const run=(...args)=>execFileSync(vm,['shell','p','sudo',...args],{encoding:'utf8'});
const control=(payload)=>execFileSync(vm,['shell','p','sudo','python3','/tmp/group-control-test.py'],{encoding:'utf8',input:JSON.stringify(payload)});
(async()=>{
 execFileSync(vm,['copy',path.join(__dirname,'sip_control.py'),'p:/tmp/sip_control_group_test.py']);
 const phones=['7778','7779'];
 const endpoint='\n;temporary-browser-group-check\n'+phones.map(e=>`[${e}]\ntype=endpoint\ncontext=pilot-only\ndisallow=all\nallow=ulaw,alaw\nwebrtc=yes\nmedia_encryption=dtls\ndtls_auto_generate_cert=yes\ndirect_media=no\nrtp_symmetric=yes\nforce_rport=yes\nrewrite_contact=yes\nauth=auth-${e}\naors=${e}\n[${e}]\ntype=aor\nmax_contacts=1\nremove_existing=yes\nmaximum_expiration=60\nminimum_expiration=30\n`).join('')+'#include group-test-auth.conf\n';
 const helper="import importlib.util,json,sys\nfrom pathlib import Path\ns=importlib.util.spec_from_file_location('ctl','/tmp/sip_control_group_test.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m);m.EXTENSIONS={'7778','7779'};m.AUTH=Path('/etc/asterisk/group-test-auth.conf');m.STATE=Path('/root/group-test-state.json');m.handle(json.load(sys.stdin));print('ok')\n";
 let dialplan=fs.readFileSync(path.join(__dirname,'gateway-dialplan.conf'),'utf8').split('[ais-browser-outbound]')[0].replace(/ais-browser/g,'ais-review-browser').replace(/from-pbx-pilot/g,'ais-review-from-pbx-pilot');
 dialplan=dialplan.replace('${FILTER(0-9.,${PJSIP_HEADER(read,X-AIS-Call-ID)})}','${CHANNEL(linkedid)}');
 run('python3','-c',"from pathlib import Path;p=Path('/etc/asterisk/pjsip.conf');assert ';temporary-browser-group-check' not in p.read_text();p.write_text(p.read_text()+"+JSON.stringify(endpoint)+");Path('/tmp/group-control-test.py').write_text("+JSON.stringify(helper)+");p=Path('/etc/asterisk/extensions.conf');p.write_text(p.read_text()+'\\n;temporary-browser-group-check\\n'+"+JSON.stringify(dialplan)+")");
 let browser;
 try{
  const credentials=phones.map(e=>({action:'enable',extension:e,password:crypto.randomBytes(32).toString('base64url'),contact_user:e+'-'+crypto.randomBytes(16).toString('hex'),until:Math.floor(Date.now()/1000)+60}));
  for(const c of credentials)control(c);
  run('asterisk','-rx','dialplan reload');
  const pc=JSON.parse(run('python3','-c',"import json,time,hmac,hashlib,base64;from pathlib import Path;u=str(int(time.time())+3600)+':group-test';s=Path('/etc/ais-pilot-phone/turn-secret').read_text().strip();print(json.dumps({'iceServers':[{'urls':'turn:localhost:3478?transport=tcp','username':u,'credential':base64.b64encode(hmac.new(s.encode(),u.encode(),hashlib.sha1).digest()).decode()}],'iceTransportPolicy':'relay'}))"));
  browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream']});
  const pages=[];
  for(const c of credentials){
   const ctx=await browser.newContext({permissions:['microphone','local-network-access']});const p=await ctx.newPage();await p.goto('https://localhost:18443/');
   await p.evaluate(c=>{window.testIncoming=0;window.testBusy=0;window.testEnded=0;window.testSession=null;window.pcConfig=c.pc;window.ua=new JsSIP.UA({sockets:[new JsSIP.WebSocketInterface('wss://localhost:18089/ws')],uri:'sip:'+c.extension+'@localhost',password:c.password,contact_uri:'sip:'+c.contact_user+'@localhost;transport=ws',register_expires:60,session_timers:false});window.registered=false;ua.on('registered',()=>window.registered=true);ua.on('newRTCSession',e=>{if(testSession){testBusy++;e.session.terminate({status_code:486});return;}testIncoming++;testSession=e.session;const s=e.session;s.on('ended',()=>{testEnded++;if(testSession===s)testSession=null;});s.on('failed',()=>{testEnded++;if(testSession===s)testSession=null;});});ua.start();},Object.assign({},c,{pc}));
   await p.waitForFunction(()=>window.registered,{},{timeout:15000});control({action:'heartbeat',extension:c.extension,until:Math.floor(Date.now()/1000)+60});pages.push(p);
  }
  run('asterisk','-rx','channel originate Local/7771@ais-review-browser-group application Echo');
  await Promise.all(pages.map(p=>p.waitForFunction(()=>window.testIncoming===1,{},{timeout:10000})));
  await pages[0].evaluate(()=>testSession.answer({mediaConstraints:{audio:true,video:false},pcConfig}));
  await pages[0].waitForFunction(()=>testSession&&testSession.isEstablished(),{},{timeout:15000});
  await pages[1].waitForFunction(()=>window.testSession===null&&testEnded===1,{},{timeout:10000});
  run('asterisk','-rx','channel originate Local/7771@ais-review-browser-group application Echo');
  await pages[1].waitForFunction(()=>window.testIncoming===2&&!!testSession,{},{timeout:10000});
  await pages[0].waitForFunction(()=>window.testBusy===1,{},{timeout:10000});
  await pages[1].evaluate(()=>testSession.terminate({status_code:486}));
  if(!await pages[0].evaluate(()=>testSession.isEstablished()))throw Error('Second incoming interrupted first conversation');
  await pages[0].evaluate(()=>testSession.terminate());
  console.log('Real Asterisk group: both browsers ring, answer cancels other, new call rings free employee while first talks; rejection preserves ongoing conversation');
 }finally{
  if(browser)await browser.close();
  for(const e of phones){try{control({action:'disable',extension:e});}catch(err){}}
  run('python3','-c',"from pathlib import Path;p=Path('/etc/asterisk/pjsip.conf');p.write_text(p.read_text().split(';temporary-browser-group-check')[0]);p=Path('/etc/asterisk/extensions.conf');p.write_text(p.read_text().split(';temporary-browser-group-check')[0]);\nfor f in ['/etc/asterisk/group-test-auth.conf','/root/group-test-state.json','/tmp/group-control-test.py','/tmp/sip_control_group_test.py']:Path(f).unlink(missing_ok=True)");
  run('asterisk','-rx','pjsip reload');run('asterisk','-rx','dialplan reload');for(const e of phones)run('asterisk','-rx','database deltree ais-telephony '+e);
 }
})().catch(e=>{console.error('Browser group test failed:',e.message.split('\n')[0]);process.exit(1);});
