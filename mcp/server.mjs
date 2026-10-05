import { createServer } from 'node:http';
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { z } from 'zod';

const port = Number(process.env.PORT || 8787);
const aisApiUrl = (process.env.MCP_AIS_API_URL || 'http://127.0.0.1:3000/api/v1').replace(/\/$/, '');
const oauthIssuer = process.env.MCP_OAUTH_ISSUER;
const oauthClientId = process.env.MCP_OAUTH_CLIENT_ID || 'chatgpt-work';
const oauthRedirectUris = new Set((process.env.MCP_OAUTH_REDIRECT_URIS || '').split(',').map((value) => value.trim()).filter(Boolean));
const authorizationCodes = new Map();
const accessTokens = new Map();
const tokenLifetimeSeconds = 3600;

function bearerToken(req) { const match = (req.headers.authorization || '').match(/^Bearer\s+(.+)$/i); return match?.[1]?.trim(); }
function randomToken() { return randomBytes(32).toString('base64url'); }
function constantTimeEqual(left, right) {
  const a = Buffer.from(left || ''); const b = Buffer.from(right || '');
  return a.length === b.length && timingSafeEqual(a, b);
}
function safeRedirect(uri) { return oauthRedirectUris.has(uri); }
function htmlEscape(value) { return String(value).replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char])); }
async function bodyParams(req) {
  let body = ''; for await (const chunk of req) body += chunk;
  return new URLSearchParams(body);
}
function oauthError(res, status, error, description) {
  res.writeHead(status, { 'content-type': 'application/json', 'cache-control': 'no-store' }).end(JSON.stringify({ error, ...(description ? { error_description: description } : {}) }));
}
function oauthMetadata(url) {
  const issuer = oauthIssuer || url.origin;
  return { issuer, authorization_endpoint: `${issuer}/oauth/authorize`, token_endpoint: `${issuer}/oauth/token`, revocation_endpoint: `${issuer}/oauth/revoke`, response_types_supported: ['code'], grant_types_supported: ['authorization_code'], code_challenge_methods_supported: ['S256'], token_endpoint_auth_methods_supported: ['none'] };
}
function toolError(error) {
  const message = error.status === 401 ? 'AIS authorization failed.' : error.status === 403 ? 'You are not allowed to perform this operation.' : error.message || 'AIS request failed.';
  return { isError: true, content: [{ type: 'text', text: message }] };
}
async function readJson(response) {
  const text = await response.text(); let body = {};
  try { body = text ? JSON.parse(text) : {}; } catch (_) { body = { error: 'AIS returned a non-JSON response' }; }
  if (!response.ok) { const error = new Error(body.error || body.message || `AIS request failed (${response.status})`); error.status = response.status; throw error; }
  return body;
}
function aisClient(token) {
  const call = async (path, method = 'GET', body) => readJson(await fetch(`${aisApiUrl}${path}`, { method, headers: { authorization: `Token token=${token}`, accept: 'application/json', ...(body ? { 'content-type': 'application/json' } : {}) }, body: body ? JSON.stringify(body) : undefined }));
  return { call };
}

async function signInToAis(username, password) {
  const response = await fetch(`${aisApiUrl}/signin`, { method: 'POST', headers: { accept: 'application/json', 'content-type': 'application/json' }, body: JSON.stringify({ username, password }) });
  const body = await readJson(response);
  if (!body.token) { const error = new Error('AIS authorization failed.'); error.status = 401; throw error; }
  return body.token;
}

function tokenRecord(token) {
  const record = accessTokens.get(token);
  if (!record || record.expiresAt <= Date.now()) { accessTokens.delete(token); return null; }
  return record;
}
function registerTools(server, client) {
  const read = { readOnlyHint: true, destructiveHint: false, openWorldHint: false };
  const write = { readOnlyHint: false, destructiveHint: false, openWorldHint: false };
  const id = z.number().int().positive(); const key = z.string().trim().min(1).max(200);
  const call = (fn) => async (args) => { try { return { structuredContent: await fn(args) }; } catch (e) { return toolError(e); } };
  server.registerTool('search_clients', { title: 'Search clients', description: 'Find AIS clients by the existing phone/name/card search. Return all matches; never choose an ambiguous client for a write.', inputSchema: { query: z.string().trim().min(1), limit: z.number().int().min(1).max(50).optional() }, annotations: read }, call(({ query, limit }) => client.call(`/clients/search?query=${encodeURIComponent(query)}&limit=${limit || 20}`)));
  server.registerTool('get_client', { title: 'Get client', description: 'Read one unambiguous client and related devices and service jobs.', inputSchema: { client_id: id }, annotations: read }, call(({ client_id }) => client.call(`/clients/${client_id}`)));
  server.registerTool('update_client', { title: 'Update client fields', description: 'Replace only explicitly supplied allowed client fields; use add_client_note to append history instead of replacing it.', inputSchema: { client_id: id, name: z.string().optional(), surname: z.string().optional(), patronymic: z.string().optional(), email: z.string().optional(), contact_phone: z.string().optional(), admin_info: z.string().optional(), idempotency_key: key }, annotations: write }, call(({ client_id, idempotency_key, ...fields }) => client.call(`/clients/${client_id}`, 'PATCH', { ...fields, idempotency_key })));
  server.registerTool('add_client_note', { title: 'Add client note', description: 'Append a comment to the client history; this does not replace any existing field or comment.', inputSchema: { client_id: id, content: z.string().trim().min(1).max(5000), idempotency_key: key }, annotations: write }, call(({ client_id, ...body }) => client.call(`/clients/${client_id}/notes`, 'POST', body)));
  server.registerTool('search_devices', { title: 'Search devices', description: 'Find devices by existing AIS identifiers such as serial number, IMEI, barcode or product.', inputSchema: { query: z.string().trim().min(1), limit: z.number().int().min(1).max(50).optional() }, annotations: read }, call(({ query, limit }) => client.call(`/devices/search?query=${encodeURIComponent(query)}&limit=${limit || 20}`)));
  server.registerTool('get_device', { title: 'Get device', description: 'Read one device and its linked client IDs.', inputSchema: { device_id: id }, annotations: read }, call(({ device_id }) => client.call(`/devices/${device_id}`)));
  server.registerTool('update_device', { title: 'Update device fields', description: 'Replace only an allowed device field. Requires the AIS permission for device modification.', inputSchema: { device_id: id, barcode_num: z.string().optional(), idempotency_key: key }, annotations: write }, call(({ device_id, ...body }) => client.call(`/devices/${device_id}`, 'PATCH', body)));
  server.registerTool('add_device_note', { title: 'Add device note', description: 'Append a diagnostic note to the latest service job for this device; does not replace history.', inputSchema: { device_id: id, content: z.string().trim().min(1).max(5000), idempotency_key: key }, annotations: write }, call(({ device_id, ...body }) => client.call(`/devices/${device_id}/notes`, 'POST', body)));
  server.registerTool('search_requests', { title: 'Search service requests', description: 'Find repair/service jobs by ticket, client or device identifier.', inputSchema: { query: z.string().trim().min(1), limit: z.number().int().min(1).max(50).optional() }, annotations: read }, call(({ query, limit }) => client.call(`/requests/search?query=${encodeURIComponent(query)}&limit=${limit || 20}`)));
  server.registerTool('get_request', { title: 'Get service request', description: 'Read one service job with client, device, status and notes.', inputSchema: { request_id: id }, annotations: read }, call(({ request_id }) => client.call(`/requests/${request_id}`)));
  server.registerTool('add_request_note', { title: 'Add request diagnostic note', description: 'Append a service-job/device diagnostic note; does not replace the request description.', inputSchema: { request_id: id, content: z.string().trim().min(1).max(5000), idempotency_key: key }, annotations: write }, call(({ request_id, ...body }) => client.call(`/requests/${request_id}/notes`, 'POST', body)));
  server.registerTool('search_client_requests', { title: 'Search client requests', description: 'Find receipt-search/device-unblock requests with current workflow status.', inputSchema: { client_id: id.optional(), limit: z.number().int().min(1).max(50).optional() }, annotations: read }, call(({ client_id, limit }) => client.call(`/client_requests/search?${client_id ? `client_id=${client_id}&` : ''}limit=${limit || 20}`)));
  server.registerTool('create_client_request', { title: 'Create client request', description: 'Create the existing AIS client request workflow for an already linked client/device pair. Do not invent missing IDs.', inputSchema: { client_id: id, device_id: id, reason: z.string().trim().min(1).max(5000), idempotency_key: key }, annotations: { ...write, destructiveHint: true } }, call(({ client_id, device_id, ...body }) => client.call('/client_requests', 'POST', { client_id, item_id: device_id, ...body })));
  server.registerTool('update_client_request_status', { title: 'Update client request status', description: 'Change only an allowed existing client-request workflow status.', inputSchema: { request_id: id, status: z.enum(['new_request', 'in_progress', 'done', 'failed']), idempotency_key: key }, annotations: write }, call(({ request_id, ...body }) => client.call(`/client_requests/${request_id}/status`, 'PATCH', body)));
  server.registerTool('search_employees', { title: 'Search employees', description: 'Find active AIS employees by name. Return choices when multiple employees match.', inputSchema: { query: z.string().trim().min(1), limit: z.number().int().min(1).max(50).optional() }, annotations: read }, call(({ query, limit }) => client.call(`/employees/search?query=${encodeURIComponent(query)}&limit=${limit || 20}`)));
  server.registerTool('get_employee_merits_faults', { title: 'Get employee merits and faults', description: 'Read existing plus/minus records and their reasons, subject to AIS policy.', inputSchema: { employee_id: id, limit: z.number().int().min(1).max(50).optional() }, annotations: read }, call(({ employee_id, limit }) => client.call(`/employees/${employee_id}/merits_faults?limit=${limit || 20}`)));
  server.registerTool('get_fault_kinds', { title: 'Get fault categories', description: 'List existing AIS minus categories and rules; financial analytics are intentionally not exposed.', inputSchema: {}, annotations: read }, call(() => client.call('/employees/fault_kinds')));
  server.registerTool('add_merit', { title: 'Add employee plus', description: 'Create one existing AIS merit with a reason. Server-side MeritPolicy and idempotency apply.', inputSchema: { employee_id: id, comment: z.string().trim().min(1).max(5000), date: z.string().optional(), idempotency_key: key }, annotations: write }, call(({ employee_id, ...body }) => client.call(`/employees/${employee_id}/merits`, 'POST', body)));
  server.registerTool('add_fault', { title: 'Add employee minus', description: 'Create one existing AIS fault using an existing fault category and reason. Server-side FaultPolicy applies.', inputSchema: { employee_id: id, kind_id: id, comment: z.string().trim().min(1).max(5000), date: z.string().optional(), idempotency_key: key }, annotations: { ...write, destructiveHint: true } }, call(({ employee_id, ...body }) => client.call(`/employees/${employee_id}/faults`, 'POST', body)));
  server.registerTool('search_repair_options', { title: 'Compare repair options', description: 'Return all configured repair variants for a device model, including customer price, configured part purchase-cost breakdown, time and technical notes. Internal cost data is for staff comparison and must not be disclosed to a customer.', inputSchema: { model_query: z.string().trim().min(1), repair_query: z.string().trim().optional(), department_id: id.optional(), limit: z.number().int().min(1).max(50).optional() }, annotations: read }, call(({ model_query, repair_query, department_id, limit }) => client.call(`/repairs/options?model_query=${encodeURIComponent(model_query)}&${repair_query ? `repair_query=${encodeURIComponent(repair_query)}&` : ''}${department_id ? `department_id=${department_id}&` : ''}limit=${limit || 20}`)));
  server.registerTool('search_unlock_requests', { title: 'Search device-unlock requests', description: 'Search AIS device-unlock workflow requests by status, period, client or device within the employee access scope.', inputSchema: { status: z.string().optional(), from: z.string().optional(), to: z.string().optional(), client_id: id.optional(), device_id: id.optional(), limit: z.number().int().min(1).max(50).optional() }, annotations: read }, call((args) => client.call(`/unlock_requests/search?${new URLSearchParams(Object.fromEntries(Object.entries({ ...args, limit: args.limit || 20 }).filter(([, value]) => value !== undefined))).toString()}`)));
  server.registerTool('get_unlock_request_statuses', { title: 'Get unlock workflow actions', description: 'Return the real AIS device-unlock statuses and available MCP actions; labels are not invented.', inputSchema: {}, annotations: read }, call(() => client.call('/unlock_requests/statuses')));
  server.registerTool('get_unlock_request', { title: 'Get device-unlock request', description: 'Read one device-unlock request, linked client/device, comments and current status in the employee access scope.', inputSchema: { request_id: id }, annotations: read }, call(({ request_id }) => client.call(`/unlock_requests/${request_id}`)));
  server.registerTool('update_unlock_request_status', { title: 'Change unlock request status', description: 'Change the workflow status of an AIS device-unlock request through its existing update operation. This is not a technical device unlock.', inputSchema: { request_id: id, status: z.string().trim().min(1), idempotency_key: key }, annotations: write }, call(({ request_id, ...body }) => client.call(`/unlock_requests/${request_id}/status`, 'PATCH', body)));
  server.registerTool('add_unlock_request_comment', { title: 'Add unlock request comment', description: 'Append a comment to a device-unlock request; it never replaces the request reason or existing comment history.', inputSchema: { request_id: id, content: z.string().trim().min(1).max(5000), idempotency_key: key }, annotations: write }, call(({ request_id, ...body }) => client.call(`/unlock_requests/${request_id}/comments`, 'POST', body)));
  server.registerTool('list_reports', { title: 'List available AIS reports', description: 'List report cards the current employee may access, with their existing keys, annotations and columns.', inputSchema: {}, annotations: read }, call(() => client.call('/reports/catalog')));
  server.registerTool('get_electronic_queue_report', { title: 'Get electronic queue report', description: 'Run the existing AIS electronic-queue report for an exact business-time date range and accessible department. Returned metrics preserve the report source and limitations.', inputSchema: { from: z.string(), to: z.string(), department_id: id.optional(), start_time: z.string().optional(), end_time: z.string().optional() }, annotations: read }, call(({ from, to, department_id, start_time, end_time }) => client.call(`/reports/electronic_queue?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}${department_id ? `&department_id=${department_id}` : ''}${start_time ? `&start_time=${encodeURIComponent(start_time)}` : ''}${end_time ? `&end_time=${encodeURIComponent(end_time)}` : ''}`)));
  server.registerTool('search_equipment_orders', { title: 'Search equipment orders', description: 'Search existing customer equipment orders, not service requests or purchases, with status, quantity, model and dates within the employee scope.', inputSchema: { from: z.string().optional(), to: z.string().optional(), status: z.string().optional(), number: z.string().optional(), limit: z.number().int().min(1).max(50).optional() }, annotations: read }, call((args) => client.call(`/equipment_orders/search?${new URLSearchParams(Object.fromEntries(Object.entries({ ...args, limit: args.limit || 20 }).filter(([, value]) => value !== undefined))).toString()}`)));
  server.registerTool('summarize_equipment_orders', { title: 'Summarize equipment orders', description: 'Aggregate existing equipment orders by model and status using Order#quantity; it does not call them sales and does not invent revenue.', inputSchema: { from: z.string().optional(), to: z.string().optional() }, annotations: read }, call(({ from, to }) => client.call(`/equipment_orders/summary?${new URLSearchParams(Object.fromEntries(Object.entries({ from, to }).filter(([, value]) => value !== undefined))).toString()}`)));
}

export function createHttpServer() {
  return createServer(async (req, res) => {
    const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
    if (req.method === 'GET' && url.pathname === '/') return res.writeHead(200, { 'content-type': 'text/plain' }).end('iTechService AIS MCP server');
    if (req.method === 'GET' && url.pathname === '/.well-known/oauth-protected-resource') return res.writeHead(200, { 'content-type': 'application/json', 'cache-control': 'no-store' }).end(JSON.stringify({ resource: `${url.origin}/mcp`, authorization_servers: [oauthIssuer || url.origin] }));
    if (req.method === 'GET' && url.pathname === '/.well-known/oauth-authorization-server') return res.writeHead(200, { 'content-type': 'application/json', 'cache-control': 'no-store' }).end(JSON.stringify(oauthMetadata(url)));
    if (req.method === 'GET' && url.pathname === '/oauth/authorize') {
      const { client_id: clientId, redirect_uri: redirectUri, response_type: responseType, code_challenge: challenge, code_challenge_method: method, state } = Object.fromEntries(url.searchParams);
      if (clientId !== oauthClientId || responseType !== 'code' || method !== 'S256' || !challenge || !safeRedirect(redirectUri)) return oauthError(res, 400, 'invalid_request', 'Invalid OAuth client, redirect URI or PKCE parameters.');
      const form = `<form method="post" action="/oauth/authorize"><input type="hidden" name="client_id" value="${htmlEscape(clientId)}"><input type="hidden" name="redirect_uri" value="${htmlEscape(redirectUri)}"><input type="hidden" name="code_challenge" value="${htmlEscape(challenge)}"><input type="hidden" name="state" value="${htmlEscape(state || '')}"><label>Логин AIS <input name="username" autocomplete="username" required></label><label>Пароль AIS <input name="password" type="password" autocomplete="current-password" required></label><button type="submit">Разрешить доступ</button></form>`;
      return res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' }).end(`<!doctype html><title>Вход в AIS</title>${form}`);
    }
    if (req.method === 'POST' && url.pathname === '/oauth/authorize') {
      const params = await bodyParams(req); const redirectUri = params.get('redirect_uri'); const state = params.get('state');
      if (params.get('client_id') !== oauthClientId || !safeRedirect(redirectUri) || !params.get('code_challenge')) return oauthError(res, 400, 'invalid_request');
      try {
        const aisToken = await signInToAis(params.get('username'), params.get('password'));
        const code = randomToken(); authorizationCodes.set(code, { aisToken, clientId: params.get('client_id'), redirectUri, challenge: params.get('code_challenge'), expiresAt: Date.now() + 60_000 });
        const location = new URL(redirectUri); location.searchParams.set('code', code); if (state) location.searchParams.set('state', state);
        return res.writeHead(302, { location: location.toString(), 'cache-control': 'no-store' }).end();
      } catch (_) { return res.writeHead(401, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' }).end('<p>Не удалось войти в AIS.</p>'); }
    }
    if (req.method === 'POST' && url.pathname === '/oauth/token') {
      const params = await bodyParams(req); const record = authorizationCodes.get(params.get('code')); authorizationCodes.delete(params.get('code'));
      if (!record || record.expiresAt <= Date.now() || record.clientId !== params.get('client_id') || record.redirectUri !== params.get('redirect_uri') || params.get('grant_type') !== 'authorization_code') return oauthError(res, 400, 'invalid_grant');
      const expected = Buffer.from(record.challenge); const actual = Buffer.from(createHash('sha256').update(params.get('code_verifier') || '').digest('base64url'));
      if (!constantTimeEqual(actual.toString(), expected.toString())) return oauthError(res, 400, 'invalid_grant', 'PKCE verification failed.');
      const accessToken = randomToken(); accessTokens.set(accessToken, { aisToken: record.aisToken, audience: `${url.origin}/mcp`, expiresAt: Date.now() + tokenLifetimeSeconds * 1000 });
      return res.writeHead(200, { 'content-type': 'application/json', 'cache-control': 'no-store', pragma: 'no-cache' }).end(JSON.stringify({ access_token: accessToken, token_type: 'Bearer', expires_in: tokenLifetimeSeconds, scope: 'mcp' }));
    }
    if (req.method === 'POST' && url.pathname === '/oauth/revoke') {
      const params = await bodyParams(req); accessTokens.delete(params.get('token')); return res.writeHead(200, { 'cache-control': 'no-store' }).end();
    }
    if (req.method === 'OPTIONS' && url.pathname === '/mcp') return res.writeHead(204, { 'access-control-allow-origin': '*', 'access-control-allow-methods': 'GET,POST,DELETE,OPTIONS', 'access-control-allow-headers': 'authorization,content-type,mcp-session-id', 'access-control-expose-headers': 'Mcp-Session-Id' }).end();
    if (url.pathname !== '/mcp' || !['GET', 'POST', 'DELETE'].includes(req.method || '')) return res.writeHead(404).end('Not Found');
    const presented = bearerToken(req); const record = tokenRecord(presented);
    if (!record || (record.audience !== 'test' && record.audience !== `${url.origin}/mcp`)) return res.writeHead(401, { 'content-type': 'application/json', 'www-authenticate': `Bearer realm="AIS MCP", resource_metadata="${url.origin}/.well-known/oauth-protected-resource"` }).end(JSON.stringify({ error: 'authorization_required' }));
    res.setHeader('access-control-allow-origin', '*'); res.setHeader('access-control-expose-headers', 'Mcp-Session-Id');
    const server = new McpServer({ name: 'itechservice-ais', version: '0.2.0' });
    registerTools(server, aisClient(record.aisToken));
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined, enableJsonResponse: true });
    res.on('close', () => { transport.close(); server.close(); });
    try { await server.connect(transport); await transport.handleRequest(req, res); } catch (error) { console.error('MCP request failed', { name: error.name, status: error.status }); if (!res.headersSent) res.writeHead(500).end('Internal server error'); }
  });
}

export function issueTestAccessToken(aisToken) {
  const token = randomToken();
  accessTokens.set(token, { aisToken, audience: 'test', expiresAt: Date.now() + 60_000 });
  return token;
}

if (process.argv[1] && new URL(`file://${process.argv[1]}`).href === import.meta.url) createHttpServer().listen(port, () => console.log(`iTechService AIS MCP listening on :${port}/mcp`));
