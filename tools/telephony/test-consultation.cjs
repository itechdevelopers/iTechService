// Isolated live-gateway regression: three unassigned browser extensions, no staff calls.
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
(async()=>{let browser,consoleProcess;const pages=[],pageErrors=[],musicEvents=[];try{
 consoleProcess=spawn(path.join(root,'vm.sh'),['shell','p','sudo','asterisk','-rvvv'],{stdio:['pipe','pipe','pipe'],detached:true});
 let buffer='';consoleProcess.stdout.on('data',chunk=>{buffer+=chunk.toString();const lines=buffer.split('\n');buffer=lines.pop();for(const line of lines)if(/(?:Started|Stopped) music on hold/.test(line))musicEvents.push(line);});
 browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--ignore-certificate-errors-spki-list='+pin,'--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream']});
 for(const extension of ['7779','7778','7776']){
  const context=await browser.newContext({permissions:['microphone','local-network-access']});
  const page=await context.newPage();pages.push(page);page.on('pageerror',e=>pageErrors.push(e.message));
  await page.addInitScript(frequency=>{
   const original=navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
   navigator.mediaDevices.getUserMedia=async options=>{if(!options.audio)return original(options);const ctx=new AudioContext(),osc=ctx.createOscillator(),gain=ctx.createGain(),destination=ctx.createMediaStreamDestination();osc.frequency.value=frequency;gain.gain.value=.25;osc.connect(gain).connect(destination);osc.start();await ctx.resume();window.testMicrophone={ctx,osc,gain};return destination.stream;};
   window.testTone=async frequency=>{const media=document.getElementById('remote').srcObject;if(!media)return 0;const ctx=window.testToneContext||(window.testToneContext=new AudioContext());await ctx.resume();const input=ctx.createMediaStreamSource(media),analyser=ctx.createAnalyser();analyser.fftSize=4096;input.connect(analyser);await new Promise(r=>setTimeout(r,120));const data=new Float32Array(analyser.fftSize);analyser.getFloatTimeDomainData(data);input.disconnect();let sine=0,cosine=0,power=0;for(let i=0;i<data.length;i++){const angle=2*Math.PI*frequency*i/ctx.sampleRate;sine+=data[i]*Math.sin(angle);cosine+=data[i]*Math.cos(angle);power+=data[i]*data[i];}return power?2*(sine*sine+cosine*cosine)/(data.length*power):0;};
  },{'7779':250,'7778':850,'7776':1700}[extension]);
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
 const audio=async(phone,tone)=>phone.waitForFunction(async frequency=>{const d=await pilotDiagnostics();return d.active&&await testTone(frequency)>.65;},tone,{timeout:25000});
 const connectClient=async()=>{await a.fill('#target','7778');await a.click('#test-call');await b.waitForFunction(()=>!document.getElementById('answer').disabled,{},{timeout:20000});await b.click('#answer');await b.waitForFunction(()=>!document.getElementById('hold-call').disabled);await audio(a,850);await audio(b,250);};
 const consult=async()=>{await b.fill('#target','7776');await b.click('#test-call');await c.waitForFunction(()=>!document.getElementById('answer').disabled,{},{timeout:20000});await c.click('#answer');await b.waitForFunction(()=>!document.getElementById('consult-connect').disabled);await audio(b,1700);await audio(c,850);};
 await connectClient();await consult();
 await a.waitForFunction(async()=>{const d=await pilotDiagnostics();return d.active&&d.remoteLevel>0;});
 assert(await a.evaluate(()=>testTone(850))<.35,'Client hears operator consultation');
 assert(await a.evaluate(()=>testTone(1700))<.35,'Client hears colleague consultation');
 assert(await b.evaluate(()=>testTone(250))<.35,'Consultation hears held client');
 assert(musicEvents.some(line=>line.includes('Started')),'No music on hold during consultation');
 await b.click('#consult-return');await c.waitForFunction(()=>document.getElementById('hangup').disabled);await b.waitForFunction(()=>document.getElementById('consult-panel').hidden&&!document.getElementById('hold-call').disabled);
 await audio(a,850);await audio(b,250);assert(musicEvents.some(line=>line.includes('Stopped')),'Music did not stop after return');
 console.log('PRIVATE_CONSULTATION_AND_RETURN_PASSED');
 // Cancel before the colleague answers; the original call resumes automatically.
 await b.fill('#target','7776');await b.click('#test-call');await c.waitForFunction(()=>!document.getElementById('answer').disabled);await b.click('#consult-return');await c.waitForFunction(()=>document.getElementById('answer').disabled);await audio(a,850);await audio(b,250);
 // A busy colleague must not cost the client call or microphone.
 await c.fill('#target','779');await c.click('#test-call');await audio(c,1700);
 await b.fill('#target','7776');await b.click('#test-call');await b.waitForFunction(()=>document.getElementById('consult-panel').hidden&&document.getElementById('consult-result').textContent.includes('Коллега недоступен'),{},{timeout:20000});
 await audio(a,850);await audio(b,250);await c.click('#hangup');await c.waitForFunction(()=>document.getElementById('hangup').disabled);
 // Attended transfer after an answered consultation.
 await consult();b.once('dialog',dialog=>dialog.accept());await b.click('#consult-connect');await b.waitForFunction(()=>document.getElementById('hangup').disabled,{},{timeout:20000});
 await audio(a,1700);await audio(c,250);await a.click('#hangup');await c.waitForFunction(()=>document.getElementById('hangup').disabled);
 console.log('ATTENDED_TRANSFER_WITH_TWO_WAY_AUDIO_PASSED');
 // Client hangs up during consultation; both operator dialogs are cleaned up.
 await connectClient();await consult();await a.click('#hangup');await b.waitForFunction(()=>document.getElementById('hangup').disabled);await c.waitForFunction(()=>document.getElementById('hangup').disabled);
 await connectClient();await a.click('#hangup');await b.waitForFunction(()=>document.getElementById('hangup').disabled);
 // Direct transfer of an already held client (review request).
 await connectClient();await b.click('#hold-call');await b.waitForFunction(()=>document.getElementById('hold-call').getAttribute('aria-pressed')==='true'&&!document.getElementById('hold-call').disabled);
 await b.fill('#transfer-target','7776');b.once('dialog',dialog=>dialog.accept());await b.click('#transfer-call');await c.waitForFunction(()=>!document.getElementById('answer').disabled);await c.click('#answer');await b.waitForFunction(()=>document.getElementById('hangup').disabled);
 await audio(a,1700);await audio(c,250);await a.click('#hangup');await c.waitForFunction(()=>document.getElementById('hangup').disabled);
 assert.equal(pageErrors.length,0,pageErrors.join('; '));console.log('CONSULTATION_PASSED: privacy, music, return, cancel, attended and held direct transfer, client hangup and next-call microphone');
 }finally{for(const page of pages){try{await page.evaluate(async()=>{document.getElementById('hangup').click();await document.getElementById('disable').onclick();});}catch(e){}}if(browser)await browser.close();if(consoleProcess){consoleProcess.stdin.destroy();consoleProcess.stdout.destroy();consoleProcess.stderr.destroy();try{process.kill(-consoleProcess.pid,'SIGTERM');}catch(e){}consoleProcess.unref();}}
})().catch(error=>{console.error(error.stack);process.exitCode=1;});
