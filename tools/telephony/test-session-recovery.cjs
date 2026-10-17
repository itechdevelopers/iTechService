// Browser recovery UI with actual JsSIP; isolate all broker/SIP traffic.
const fs=require('fs'),path=require('path'),assert=require('assert');
const pilot=process.env.AIS_TELEPHONY_PILOT_ROOT||'/Users/mac/Library/Application Support/com.itech.call-pipeline/runtime/work/webrtc-pilot';
const {chromium}=require(path.join(pilot,'test-tools/node_modules/playwright'));
const repo=path.resolve(__dirname,'../..'),fixtures=process.env.AIS_PHONE_BROWSER_FIXTURES||'/tmp/ais-native-fixtures';
const html=fs.readFileSync(path.join(fixtures,'phone.html'),'utf8');assert(html.includes('id="recovery-panel"'),'Regenerate Rails phone fixtures');
const review=fs.readFileSync(path.join(__dirname,'test-workspace-review.cjs'),'utf8');
const registrar=review.slice(review.indexOf('function registrar(){'),review.indexOf('(async()=>'))+'\nregistrar();';
(async()=>{let browser;try{
 browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream']});
 const ctx=await browser.newContext({permissions:['microphone']});let mode='conflict';const requests=[],errors=[];
 await ctx.route('https://ise.itech.pw/**',async r=>{
  const u=new URL(r.request().url());
  if(u.pathname.startsWith('/assets/telephony/')){
   const name=['phone.js','phone.css','jssip.min.js'].find(n=>u.pathname.includes(n.replace(/\.(js|css)$/,''))&&u.pathname.endsWith(n.endsWith('.js')?'.js':'.css'));assert(name);
   let body=fs.readFileSync(path.join(repo,name==='jssip.min.js'?'vendor/assets/javascripts/telephony':name.endsWith('.js')?'app/assets/javascripts/telephony':'app/assets/stylesheets/telephony',name),'utf8');
   if(name==='jssip.min.js')body+='\n'+registrar;
   return r.fulfill({contentType:name.endsWith('.js')?'application/javascript':'text/css',body});
  }
  if(u.pathname==='/telephony/ticket')return r.fulfill({json:{ticket:'isolated-test',gateway:'https://gateway.example.test',extension:'7771'}});
  if(u.pathname==='/telephony')return r.fulfill({contentType:'text/html',body:html});
  throw Error('Unexpected route '+u.pathname);
 });
 await ctx.route('https://gateway.example.test/**',async r=>{
  const headers={'Access-Control-Allow-Origin':'https://ise.itech.pw','Access-Control-Allow-Headers':'Content-Type','Access-Control-Allow-Methods':'POST,OPTIONS'};
  if(r.request().method()==='OPTIONS')return r.fulfill({status:204,headers});
  const u=new URL(r.request().url()),payload=r.request().postDataJSON();requests.push({path:u.pathname,recover:payload.recover});
  if(u.pathname==='/ais/enable'){
   if(mode==='other')return r.fulfill({status:409,headers,json:{error:'Номер занят другим сотрудником.',code:'extension_in_use'}});
   if(!payload.recover)return r.fulfill({status:409,headers,json:{error:'Телефон уже включён в другом окне.',code:'session_conflict'}});
   if(mode==='busy')return r.fulfill({status:409,headers,json:{error:'На этом номере идёт звонок.',code:'call_active'}});
   return r.fulfill({headers,json:{user:'7771',password:'test-password',token:'new-token',uri:'sip:7771@localhost',wss:'wss://gateway.example.test/ws',contact_uri:'sip:7771-test@localhost;transport=ws',pcConfig:{iceServers:[]}}});
  }
  return r.fulfill({headers,json:u.pathname==='/ais/waiting'?{waiting:[],recent:[]}:{ok:true,pcConfig:{iceServers:[]}}});
 });
 const page=await ctx.newPage();page.on('pageerror',e=>errors.push(e.message));await page.goto('https://ise.itech.pw/telephony');await page.click('#enable');await page.waitForFunction(()=>!document.getElementById('recovery-panel').hidden);assert((await page.locator('#error').textContent()).includes('другом окне'));console.log('CONFLICT_BUTTON_VISIBLE');
 mode='busy';await page.click('#recover');await page.waitForFunction(()=>document.getElementById('error').textContent.includes('идёт звонок'));assert(await page.isVisible('#recover'));console.log('BUSY_RECOVERY_REFUSED');
 mode='ok';await page.click('#recover');await page.waitForFunction(()=>document.getElementById('status').textContent.includes('Готов к звонкам'));assert(await page.isHidden('#recovery-panel'));assert(requests.filter(x=>x.path==='/ais/enable').slice(1).every(x=>x.recover===true));
 await page.locator('#ais-phone').screenshot({path:'/tmp/ais-recovery-20261017-preview.png'});
 await page.locator('#phone-settings').evaluate(el=>el.open=true);await page.click('#disable');await page.waitForFunction(()=>!document.getElementById('enable').disabled);mode='other';await page.click('#enable');await page.waitForFunction(()=>document.getElementById('error').textContent.includes('другим сотрудником'));assert(await page.isHidden('#recovery-panel'));
 assert.deepEqual(errors,[]);console.log('RECOVERY_CONFLICT_BUTTON_BUSY_REFUSAL_SUCCESS_AND_OTHER_OWNER_PASSED');
}finally{if(browser)await browser.close();}})().catch(e=>{console.error(e.stack);process.exit(1);});
