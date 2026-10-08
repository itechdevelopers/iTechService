const path=require('path'), fs=require('fs'), crypto=require('crypto'), {execFileSync}=require('child_process');
const pilot=process.env.AIS_TELEPHONY_PILOT_ROOT||'/Users/mac/Library/Application Support/com.itech.call-pipeline/runtime/work/webrtc-pilot';
const {chromium}=require(path.join(pilot,'test-tools/node_modules/playwright'));
const vm=path.join(pilot,'vm.sh');
const run=(...args)=>execFileSync(vm,['shell','p','sudo',...args],{encoding:'utf8'});
const control=(payload)=>execFileSync(vm,['shell','p','sudo','python3','/tmp/lease-control-test.py'],{encoding:'utf8',input:JSON.stringify(payload)});
(async()=>{
 execFileSync(vm,['copy',path.join(__dirname,'sip_control.py'),'p:/tmp/sip_control_review.py']);
 const endpoint='\n;temporary-lease-check\n[7798]\ntype=endpoint\ncontext=pilot-only\ndisallow=all\nallow=ulaw,alaw\nwebrtc=yes\nmedia_encryption=dtls\ndtls_auto_generate_cert=yes\ndirect_media=no\nrtp_symmetric=yes\nforce_rport=yes\nrewrite_contact=yes\nauth=auth-7798\naors=7798\n[7798]\ntype=aor\nmax_contacts=1\nremove_existing=yes\nmaximum_expiration=60\nminimum_expiration=30\n#include lease-test-auth.conf\n';
 const helper="import importlib.util,json,sys\nfrom pathlib import Path\ns=importlib.util.spec_from_file_location('ctl','/tmp/sip_control_review.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m);m.EXTENSIONS={'7798'};m.AUTH=Path('/etc/asterisk/lease-test-auth.conf');m.STATE=Path('/root/lease-test-state.json');m.handle(json.load(sys.stdin));print('ok')\n";
 run('python3','-c',"from pathlib import Path;p=Path('/etc/asterisk/pjsip.conf');assert ';temporary-lease-check' not in p.read_text();p.write_text(p.read_text()+"+JSON.stringify(endpoint)+");Path('/tmp/lease-control-test.py').write_text("+JSON.stringify(helper)+")");
 let browser;
 const make=()=>({action:'enable',extension:'7798',password:crypto.randomBytes(32).toString('base64url'),contact_user:'7798-'+crypto.randomBytes(16).toString('hex'),until:Math.floor(Date.now()/1000)+60});
 try{
  const first=make();control(first);
  browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
  const ctx=await browser.newContext({permissions:['local-network-access']});const p=await ctx.newPage();await p.goto('https://localhost:18443/');
  async function register(credentials){await p.evaluate(c=>{if(window.leaseUA)window.leaseUA.stop();window.leaseRegistered=false;window.leaseFailed=false;window.leaseUA=new JsSIP.UA({sockets:[new JsSIP.WebSocketInterface('wss://localhost:18089/ws')],uri:'sip:7798@localhost',password:c.password,contact_uri:'sip:'+c.contact_user+'@localhost;transport=ws',register_expires:60,session_timers:false});leaseUA.on('registered',()=>window.leaseRegistered=true);leaseUA.on('registrationFailed',()=>window.leaseFailed=true);leaseUA.start();},credentials);}
  await register(first);await p.waitForFunction(()=>window.leaseRegistered,{},{timeout:15000});
  const inactive=run('asterisk','-rx','database get ais-telephony 7798/active');if(!inactive.includes('Value: 0'))throw Error('New lease must remain inactive before verified contact');
  control({action:'heartbeat',extension:'7798',until:Math.floor(Date.now()/1000)+60});
  if(run('asterisk','-rx','database get ais-telephony 7798/active').includes('Value: 0'))throw Error('Matching contact not activated');
  await p.evaluate(()=>leaseUA.stop());control({action:'disable',extension:'7798'});
  await register(first);await p.waitForFunction(()=>window.leaseFailed,{},{timeout:15000});
  const second=make();control(second);await register(second);await p.waitForFunction(()=>window.leaseRegistered,{},{timeout:15000});
  control({action:'heartbeat',extension:'7798',until:Math.floor(Date.now()/1000)+60});
  console.log('Real Asterisk: lease password registers, matching contact activates ringing, old password rejected after revoke, new password registers');
 }finally{
  if(browser)await browser.close();
  try{control({action:'disable',extension:'7798'});}catch(e){}
  run('python3','-c',"from pathlib import Path;p=Path('/etc/asterisk/pjsip.conf');p.write_text(p.read_text().split(';temporary-lease-check')[0]);\nfor f in ['/etc/asterisk/lease-test-auth.conf','/root/lease-test-state.json','/tmp/lease-control-test.py','/tmp/sip_control_review.py']:Path(f).unlink(missing_ok=True)");
  run('asterisk','-rx','pjsip reload');run('asterisk','-rx','database deltree ais-telephony 7798');
 }
})().catch(e=>{console.error('SIP lease test failed:',e.message.split('\n')[0]);process.exit(1);});
