import { createApp, createBackend } from './server.js';
const publicOrigin=process.env.AIS_MCP_PUBLIC_ORIGIN;
const backendOrigin=process.env.AIS_MCP_BACKEND_ORIGIN;
if (!publicOrigin || !backendOrigin) throw new Error('AIS_MCP_PUBLIC_ORIGIN and AIS_MCP_BACKEND_ORIGIN are required');
const port=Number(process.env.AIS_MCP_PORT || 3101);
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid AIS_MCP_PORT');
const app=createApp({publicOrigin,backend:createBackend(backendOrigin)});
const server=app.listen(port,'127.0.0.1',()=>console.info('AIS MCP listening on loopback'));
for (const signal of ['SIGTERM','SIGINT']) process.on(signal,()=>server.close(()=>process.exit(0)));
