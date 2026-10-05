import test from 'node:test';
import http from 'node:http';
import assert from 'node:assert/strict';
import { createApp, createBackend, BackendError } from '../src/server.js';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';

async function fixture(t, overrides={}) {
 const calls=[];
 const backend=async(path,token,body)=>{
  if(token==='invalid') throw new BackendError(401,'invalid_token','Expired');
  if(token==='unavailable') throw new BackendError(502,'ais_unavailable','Unavailable');
  if(path.endsWith('identity')) return {scopes:token==='reader' ? ['ais:read']:['ais:read','ais:write','ais:revenue']};
  calls.push({token,...body});
  return overrides.call ? overrides.call(body,token):{ok:true,data:{kind:body.arguments.kind,id:body.arguments.id,comment_id:12,status:body.arguments.status}};
 };
 const hosts=[];
 const app=createApp({publicOrigin:'https://ais.example',backend,allowedHosts:hosts});
 const server=app.listen(0,'127.0.0.1');
 await new Promise(resolve=>server.on('listening',resolve));
 const base=`http://127.0.0.1:${server.address().port}`;
 hosts.push(new URL(base).host);
 const fetchLocal=(path,options={})=>new Promise((resolve,reject)=>{
  const req=http.request(base+path,{method:options.method || 'GET',headers:options.headers},response=>{
   let body='';response.on('data',chunk=>body+=chunk);response.on('end',()=>resolve({status:response.statusCode,headers:new Headers(response.headers),json:async()=>JSON.parse(body)}));
  });req.on('error',reject);if(options.body)req.write(options.body);req.end();
 });
 t.after(()=>new Promise(resolve=>{server.closeAllConnections();server.close(resolve);}));
 const client=async(token='writer')=>{
  const c=new Client({name:'ais-test',version:'1.0.0'});
  const transport=new StreamableHTTPClientTransport(new URL(base+'/mcp'),{requestInit:{headers:{Authorization:`Bearer ${token}`}}});
  await c.connect(transport);
  t.after(()=>c.close());return c;
 };
 return {calls,client,fetchLocal};
}

test('OAuth protected resource discovery, initialization and six tools',async t=>{
 const f=await fixture(t);const r=await f.fetchLocal('/.well-known/oauth-protected-resource/mcp');
 assert.equal((await r.json()).resource,'https://ais.example/mcp');
 const client=await f.client();assert.equal(client.getServerVersion().name,'ais');
 const tools=(await client.listTools()).tools;assert.equal(tools.length,6);
 for(const tool of tools){assert.equal(tool.inputSchema.additionalProperties,false);assert.ok(tool.outputSchema);assert.equal(tool._meta.securitySchemes[0].type,'oauth2');assert.equal(tool.annotations.idempotentHint,true);}
 assert.equal(tools.find(x=>x.name==='search_orders').annotations.readOnlyHint,true);
 assert.equal(tools.find(x=>x.name==='change_order_status').annotations.destructiveHint,true);
});
for(const token of [undefined,'invalid']) test(`reject missing/invalid auth: ${token}`,async t=>{
 const f=await fixture(t);const r=await f.fetchLocal('/mcp',{method:'POST',headers:{'Content-Type':'application/json',...(token ? {Authorization:`Bearer ${token}`}:{})},body:'{}'});
 assert.equal(r.status,401);assert.match(r.headers.get('www-authenticate'),/resource_metadata=/);assert.equal(f.calls.length,0);
});
test('fail closed when AIS is unavailable during authentication',async t=>{const f=await fixture(t);const r=await f.fetchLocal('/mcp',{method:'POST',headers:{Authorization:'Bearer unavailable'}});assert.equal(r.status,502);});
test('host and origin guard and no unauthenticated SSE',async t=>{
 const f=await fixture(t);assert.equal((await f.fetchLocal('/health',{headers:{Host:'evil.example'}})).status,403);
 assert.equal((await f.fetchLocal('/mcp',{headers:{Origin:'https://evil.example',Authorization:'Bearer writer'}})).status,403);
 assert.equal((await f.fetchLocal('/mcp',{headers:{Authorization:'Bearer writer'}})).status,405);
});
test('write denied by OAuth scope before business call',async t=>{
 const f=await fixture(t);const c=await f.client('reader');const r=await c.callTool({name:'add_order_comment',arguments:{kind:'order',id:1,content:'Test',request_key:'request-key-00001'}});
 assert.equal(r.isError,true);assert.equal(r.structuredContent.error.code,'forbidden');assert.equal(f.calls.length,0);
});
for(const args of [{},{number:'x',phone:'79000000000'},{phone:''},{number:'x',sql:'drop'},{number:1}]) test('reject invalid search '+JSON.stringify(args),async t=>{
 const f=await fixture(t);const c=await f.client();const r=await c.callTool({name:'search_orders',arguments:args});assert.equal(r.isError,true);assert.equal(f.calls.length,0);
});
test('empty and ambiguous matches returned intact',async t=>{
 for(const matches of [[],[{kind:'order',id:1,number:'N',status:'current',department_id:1},{kind:'service_job',id:2,number:'N',status:'waiting',department_id:1}]]){
  const f=await fixture(t,{call:()=>({ok:true,data:{matches,truncated:false,instruction:'Choose ID'}})});const c=await f.client();const r=await c.callTool({name:'search_orders',arguments:{number:'N'}});assert.deepEqual(r.structuredContent.data.matches,matches);assert.equal(r.isError,false);
 }
});
test('invalid ID, arbitrary method, and unsafe request key rejected',async t=>{
 const f=await fixture(t);const c=await f.client();
 for(const call of [{name:'get_order',arguments:{kind:'order',id:0}},{name:'sql',arguments:{}},{name:'add_order_comment',arguments:{kind:'order',id:1,content:'Test',request_key:'short'}}]) assert.equal((await c.callTool(call)).isError,true);
 assert.equal(f.calls.length,0);
});
test('AIS permission and transition failures are structured, no secret leakage',async t=>{
 const f=await fixture(t,{call:()=>{throw new BackendError(403,'forbidden','Недостаточно прав АИС');}});const c=await f.client();const r=await c.callTool({name:'change_order_status',arguments:{kind:'order',id:1,status:'archive',expected_status:'current',request_key:'request-key-00002'}});assert.equal(r.structuredContent.error.code,'forbidden');
});
test('expired token during tool call returns OAuth linking challenge',async t=>{
 const f=await fixture(t,{call:()=>{throw new BackendError(401,'invalid_token','Expired');}});const c=await f.client();const r=await c.callTool({name:'get_order',arguments:{kind:'order',id:1}});assert.ok(r._meta['mcp/www_authenticate']);
});
test('credentials do not cross concurrent clients; request key forwarded unchanged',async t=>{
 const f=await fixture(t);const a=await f.client('alice');const b=await f.client('bob');
 const args={kind:'order',id:1,content:'Test',request_key:'request-key-00003'};
 await Promise.all([a.callTool({name:'add_order_comment',arguments:args}),b.callTool({name:'add_order_comment',arguments:{...args,id:2}})]);
 assert.deepEqual(f.calls.map(c=>[c.token,c.arguments.id]).sort(),[['alice',1],['bob',2]]);
 assert.ok(f.calls.every(c=>c.arguments.request_key===args.request_key));
});
test('backend URL rejects external plaintext, credentials and path prefixes',()=>{
 for(const url of ['http://evil.example','https://user:password@example.com','https://example.com/api/']) assert.throws(()=>createBackend(url));
 assert.equal(typeof createBackend('http://127.0.0.1:3000'),'function');
});
