import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

test('MCP package uses the official SDK and exposes the required tools', async () => {
  const source = await readFile(new URL('./server.mjs', import.meta.url), 'utf8');
  for (const name of ['search_clients', 'get_client', 'search_devices', 'get_device', 'search_requests', 'create_client_request', 'add_merit', 'add_fault']) {
    assert.match(source, new RegExp(`registerTool\\('${name}'`));
  }
  assert.match(source, /StreamableHTTPServerTransport/);
  assert.match(source, /Bearer/);
});

test('MCP source never forwards credentials to the browser as tool data', async () => {
  const source = await readFile(new URL('./server.mjs', import.meta.url), 'utf8');
  assert.doesNotMatch(source, /HIKVISION_PASSWORD|RTSP:\/\//i);
});
