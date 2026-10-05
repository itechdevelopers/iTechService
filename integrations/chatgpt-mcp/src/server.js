import express from 'express';
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { ListToolsRequestSchema, CallToolRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { definitions, toolResult } from './tools.js';

export class BackendError extends Error {
  constructor(status, code, message) { super(message); this.status=status; this.code=code; }
}
export function createBackend(origin) {
  const url = new URL(origin);
  if (url.protocol !== 'https:' && !(url.protocol === 'http:' && ['127.0.0.1','localhost','[::1]'].includes(url.hostname))) throw new Error('Backend must use HTTPS or loopback HTTP');
  if (url.username || url.password || url.search || url.hash || url.pathname !== '/') throw new Error('Backend must be an origin');
  return async (path, token, body) => {
    let response;
    try {
      response = await fetch(new URL(path,url),{method:body ? 'POST':'GET',headers:{Authorization:`Bearer ${token}`,...(body ? {'Content-Type':'application/json'}:{})},body:body ? JSON.stringify(body):undefined,redirect:'error',signal:AbortSignal.timeout(15000)});
    } catch { throw new BackendError(502,'ais_unavailable','АИС недоступна. Повторите запись с прежним request_key.'); }
    let payload;
    try { payload = await response.json(); } catch { throw new BackendError(502,'ais_unavailable','АИС вернула некорректный ответ'); }
    if (!response.ok) throw new BackendError(response.status, payload.error?.code || (response.status === 401 ? 'invalid_token':'ais_error'), payload.error?.message || 'Доступ к АИС отклонён');
    return payload;
  };
}
export function createApp({publicOrigin, backend, allowedHosts}) {
  const origin = new URL(publicOrigin);
  if (origin.protocol !== 'https:' || origin.pathname !== '/' || origin.search || origin.hash || origin.username || origin.password) throw new Error('Public origin must use HTTPS');
  const resource = `${origin.origin}/mcp`;
  const metadataURL = `${origin.origin}/.well-known/oauth-protected-resource/mcp`;
  const app=express();
  app.disable('x-powered-by');
  const hosts = allowedHosts || [origin.host];
  app.use((req,res,next) => {
    if (!hosts.includes(req.headers.host)) return res.status(403).json({error:'invalid_host'});
    if (req.headers.origin && req.headers.origin !== origin.origin) return res.status(403).json({error:'invalid_origin'});
    res.set('Cache-Control','no-store'); next();
  });
  app.get('/health',(_req,res)=>res.json({ok:true}));
  app.get(['/.well-known/oauth-protected-resource/mcp','/.well-known/oauth-protected-resource'],(_req,res)=>res.json({resource,authorization_servers:[origin.origin],scopes_supported:['ais:read','ais:write','ais:revenue'],bearer_methods_supported:['header']}));
  function challenge(res, status=401) {
    return res.status(status).set('WWW-Authenticate',`Bearer resource_metadata="${metadataURL}", error="invalid_token", scope="ais:read"`).json({error:'invalid_token'});
  }
  app.all('/mcp', async (req,res,next) => {
    const token = req.headers.authorization?.match(/^Bearer ([A-Za-z0-9_-]{1,512})$/)?.[1];
    if (!token) return challenge(res);
    try {
      const identity = await backend('/mcp/ais/identity',token);
      if (!Array.isArray(identity.scopes) || !identity.scopes.includes('ais:read')) return res.status(403).json({error:'insufficient_scope'});
      req.aisToken=token; req.aisScopes=identity.scopes; next();
    } catch (error) {
      if (error.status === 401) return challenge(res);
      return res.status(error.status === 403 ? 403:502).json({error:error.status === 403 ? 'forbidden':'ais_unavailable'});
    }
  });
  app.use('/mcp',express.json({limit:'32kb'}));
  app.post('/mcp', async (req,res) => {
    // Stateless transport: no in-memory user/session state can cross credentials.
    const server = new Server({name:'ais',version:'1.0.0'},{capabilities:{tools:{}}});
    server.setRequestHandler(ListToolsRequestSchema,async()=>({tools:definitions.map(d=>d.public)}));
    server.setRequestHandler(CallToolRequestSchema,async request => {
      const def=definitions.find(d=>d.name===request.params.name);
      if (!def) return toolResult({ok:false,error:{code:'unknown_tool',message:'Неизвестный инструмент'}});
      const parsed=def.schema.safeParse(request.params.arguments || {});
      if (!parsed.success) return toolResult({ok:false,error:{code:'invalid_arguments',message:'Проверьте входную схему инструмента'}});
      if (!req.aisScopes.includes(def.scope)) return toolResult({ok:false,error:{code:'forbidden',message:'Недостаточно разрешений OAuth'}});
      try { return toolResult(await backend('/mcp/ais/call',req.aisToken,{tool:def.name,arguments:parsed.data})); }
      catch (error) {
        const result=toolResult({ok:false,error:{code:error.code || 'ais_error',message:error instanceof BackendError ? error.message:'Ошибка АИС; повторите запись с тем же request_key'}});
        if (error.status === 401) result._meta={'mcp/www_authenticate':[`Bearer resource_metadata="${metadataURL}", scope="ais:read"`]};
        return result;
      }
    });
    const transport=new StreamableHTTPServerTransport({sessionIdGenerator:undefined,enableJsonResponse:true});
    res.on('close',()=>{ void transport.close(); void server.close(); });
    try { await server.connect(transport); await transport.handleRequest(req,res,req.body); }
    catch { if (!res.headersSent) res.status(500).json({error:'mcp_error'}); }
  });
  app.all('/mcp',(_req,res)=>res.status(405).set('Allow','POST').end());
  app.use((error,_req,res,_next)=>res.status(error.type === 'entity.too.large' ? 413:400).json({error:'invalid_request'}));
  return app;
}
