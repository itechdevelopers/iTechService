import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer as createHttp } from 'node:http';

function listen(server) { return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server.address().port))); }
function close(server) { return new Promise((resolve) => server.close(resolve)); }

test('MCP rejects anonymous calls and supports initialize/tools/list/tools/call', async () => {
  const ais = createHttp((req, res) => {
    if (req.url === '/clients/search?query=alice&limit=20') {
      res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify({ clients: [{ id: 1 }] }));
    } else {
      res.writeHead(404).end();
    }
  });
  const aisPort = await listen(ais);
  process.env.MCP_AIS_API_URL = `http://127.0.0.1:${aisPort}`;
  const { createHttpServer } = await import('./server.mjs');
  const mcp = createHttpServer();
  const mcpPort = await listen(mcp);
  const base = `http://127.0.0.1:${mcpPort}/mcp`;
  const anonymous = await fetch(base, { method: 'POST', body: '{}', headers: { 'content-type': 'application/json' } });
  assert.equal(anonymous.status, 401);
  const headers = { authorization: 'Bearer test-token', accept: 'application/json, text/event-stream', 'content-type': 'application/json' };
  const initialize = await fetch(base, { method: 'POST', headers, body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'test', version: '1' } } }) });
  assert.equal(initialize.status, 200);
  const listed = await fetch(base, { method: 'POST', headers, body: JSON.stringify({ jsonrpc: '2.0', id: 2, method: 'tools/list', params: {} }) });
  const list = await listed.json();
  assert.ok(list.result.tools.some((tool) => tool.name === 'search_clients'));
  const called = await fetch(base, { method: 'POST', headers, body: JSON.stringify({ jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: 'search_clients', arguments: { query: 'alice' } } }) });
  const call = await called.json();
  assert.equal(call.result.structuredContent.clients[0].id, 1);
  await close(mcp); await close(ais);
});
