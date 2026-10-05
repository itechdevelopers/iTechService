import { createServer } from 'node:http';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { z } from 'zod';

const port = Number(process.env.PORT || 8787);
const aisApiUrl = (process.env.MCP_AIS_API_URL || 'http://127.0.0.1:3000/api/v1').replace(/\/$/, '');
const oauthIssuer = process.env.MCP_OAUTH_ISSUER;

function bearerToken(req) { const match = (req.headers.authorization || '').match(/^Bearer\s+(.+)$/i); return match?.[1]?.trim(); }
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
}

export function createHttpServer() {
  return createServer(async (req, res) => {
    const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
    if (req.method === 'GET' && url.pathname === '/') return res.writeHead(200, { 'content-type': 'text/plain' }).end('iTechService AIS MCP server');
    if (req.method === 'GET' && url.pathname === '/.well-known/oauth-protected-resource') return res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify({ resource: `${url.origin}/mcp`, ...(oauthIssuer ? { authorization_servers: [oauthIssuer] } : {}) }));
    if (req.method === 'OPTIONS' && url.pathname === '/mcp') return res.writeHead(204, { 'access-control-allow-origin': '*', 'access-control-allow-methods': 'GET,POST,DELETE,OPTIONS', 'access-control-allow-headers': 'authorization,content-type,mcp-session-id', 'access-control-expose-headers': 'Mcp-Session-Id' }).end();
    if (url.pathname !== '/mcp' || !['GET', 'POST', 'DELETE'].includes(req.method || '')) return res.writeHead(404).end('Not Found');
    const token = bearerToken(req);
    if (!token) return res.writeHead(401, { 'content-type': 'application/json', 'www-authenticate': 'Bearer realm="AIS MCP"' }).end(JSON.stringify({ error: 'authorization_required' }));
    res.setHeader('access-control-allow-origin', '*'); res.setHeader('access-control-expose-headers', 'Mcp-Session-Id');
    const server = new McpServer({ name: 'itechservice-ais', version: '0.2.0' });
    registerTools(server, aisClient(token));
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined, enableJsonResponse: true });
    res.on('close', () => { transport.close(); server.close(); });
    try { await server.connect(transport); await transport.handleRequest(req, res); } catch (error) { console.error('MCP request failed', { name: error.name, status: error.status }); if (!res.headersSent) res.writeHead(500).end('Internal server error'); }
  });
}

if (process.argv[1] && new URL(`file://${process.argv[1]}`).href === import.meta.url) createHttpServer().listen(port, () => console.log(`iTechService AIS MCP listening on :${port}/mcp`));
