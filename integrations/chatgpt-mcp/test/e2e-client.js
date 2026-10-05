// Invoked by the isolated Rails test. Never points at production.
import assert from 'node:assert/strict';
import {createApp,createBackend} from '../src/server.js';
import {Client} from '@modelcontextprotocol/sdk/client/index.js';
import {StreamableHTTPClientTransport} from '@modelcontextprotocol/sdk/client/streamableHttp.js';
const backendURL=new URL(process.env.AIS_MCP_E2E_BACKEND);
if(backendURL.hostname !== '127.0.0.1')throw new Error('Isolated backend required');
const hosts=[];
const app=createApp({publicOrigin:'https://ais.example',backend:createBackend(backendURL.origin),allowedHosts:hosts});
const server=app.listen(0,'127.0.0.1');
await new Promise(resolve=>server.on('listening',resolve));
const url=new URL(`http://127.0.0.1:${server.address().port}/mcp`);hosts.push(url.host);
const client=new Client({name:'ais-e2e',version:'1.0.0'});
try {
 await client.connect(new StreamableHTTPClientTransport(url,{requestInit:{headers:{Authorization:`Bearer ${process.env.AIS_MCP_E2E_TOKEN}`}}}));
 assert.equal((await client.listTools()).tools.length,6);
 const matches=(await client.callTool({name:'search_orders',arguments:{number:'N-1'}})).structuredContent.data.matches;
 assert.equal(matches.length,2);
 const ref={kind:'order',id:matches.find(x=>x.kind==='order').id};
 assert.equal((await client.callTool({name:'get_order',arguments:ref})).structuredContent.data.status,'current');
 assert.equal((await client.callTool({name:'get_order_statuses',arguments:ref})).structuredContent.data.transitions[0].status,'pending');
 const args={...ref,content:'Synthetic end-to-end comment',request_key:'e2e-comment-request-00001'};
 const one=(await client.callTool({name:'add_order_comment',arguments:args})).structuredContent;
 const two=(await client.callTool({name:'add_order_comment',arguments:args})).structuredContent;
 assert.equal(one.ok,true);assert.deepEqual(one,two);
 const changed=await client.callTool({name:'change_order_status',arguments:{...ref,status:'pending',expected_status:'current',request_key:'e2e-status-request-00001'}});
 assert.equal(changed.structuredContent.data.status,'pending');
 const denied=await client.callTool({name:'revenue_summary',arguments:{from:'2026-10-01',to:'2026-10-02'}});
 assert.equal(denied.structuredContent.error.code,'forbidden');
 process.stdout.write('e2e_ok\n');
} finally {await client.close();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
