import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer as createHttp } from 'node:http';
import { createHash, randomBytes } from 'node:crypto';

function listen(server) { return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server.address().port))); }
function close(server) { return new Promise((resolve) => server.close(resolve)); }

test('MCP rejects anonymous calls and supports initialize/tools/list/tools/call', async () => {
  const ais = createHttp((req, res) => {
    if (req.url === '/signin') {
      res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify({ token: 'ais-user-token' }));
    } else if (req.url === '/clients/search?query=alice&limit=20') {
      res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify({ clients: [{ id: 1 }] }));
    } else {
      res.writeHead(404).end();
    }
  });
  const aisPort = await listen(ais);
  process.env.MCP_AIS_API_URL = `http://127.0.0.1:${aisPort}`;
  process.env.MCP_OAUTH_REDIRECT_URIS = 'https://chatgpt.example/callback';
  const { createHttpServer } = await import('./server.mjs');
  const mcp = createHttpServer();
  const mcpPort = await listen(mcp);
  const base = `http://127.0.0.1:${mcpPort}/mcp`;
  const anonymous = await fetch(base, { method: 'POST', body: '{}', headers: { 'content-type': 'application/json' } });
  assert.equal(anonymous.status, 401);
  const verifier = randomBytes(32).toString('base64url');
  const challenge = createHash('sha256').update(verifier).digest('base64url');
  const auth = await fetch(`${base}/../oauth/authorize?client_id=chatgpt-work&redirect_uri=${encodeURIComponent('https://chatgpt.example/callback')}&response_type=code&code_challenge=${challenge}&code_challenge_method=S256&state=s1`);
  assert.equal(auth.status, 200);
  const consent = await fetch(`http://127.0.0.1:${mcpPort}/oauth/authorize`, { method: 'POST', redirect: 'manual', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ client_id: 'chatgpt-work', redirect_uri: 'https://chatgpt.example/callback', code_challenge: challenge, username: 'alice', password: 'not-logged' }) });
  assert.equal(consent.status, 302);
  const code = new URL(consent.headers.get('location')).searchParams.get('code');
  const exchanged = await fetch(`http://127.0.0.1:${mcpPort}/oauth/token`, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ grant_type: 'authorization_code', client_id: 'chatgpt-work', redirect_uri: 'https://chatgpt.example/callback', code, code_verifier: verifier }) });
  assert.equal(exchanged.status, 200);
  const access = await exchanged.json();
  const headers = { authorization: `Bearer ${access.access_token}`, accept: 'application/json, text/event-stream', 'content-type': 'application/json' };
  const initialize = await fetch(base, { method: 'POST', headers, body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'test', version: '1' } } }) });
  assert.equal(initialize.status, 200);
  const listed = await fetch(base, { method: 'POST', headers, body: JSON.stringify({ jsonrpc: '2.0', id: 2, method: 'tools/list', params: {} }) });
  const list = await listed.json();
  assert.ok(list.result.tools.some((tool) => tool.name === 'search_clients'));
  const called = await fetch(base, { method: 'POST', headers, body: JSON.stringify({ jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: 'search_clients', arguments: { query: 'alice' } } }) });
  const call = await called.json();
  assert.equal(call.result.structuredContent.clients[0].id, 1);
  const revoked = await fetch(`http://127.0.0.1:${mcpPort}/oauth/revoke`, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ token: access.access_token }) });
  assert.equal(revoked.status, 200);
  const afterRevoke = await fetch(base, { method: 'POST', headers, body: JSON.stringify({ jsonrpc: '2.0', id: 4, method: 'tools/list', params: {} }) });
  assert.equal(afterRevoke.status, 401);
  await close(mcp); await close(ais);
});
