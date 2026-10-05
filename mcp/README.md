# AIS MCP plugin

This integration exposes the existing AIS business rules to ChatGPT Work through an official MCP Streamable HTTP server. It intentionally does not expose revenue or financial analytics.

## Tools

The server provides read tools for clients, devices, service requests, client requests, employees, merits/faults and fault categories. Write tools append client/device/request notes, update explicitly allowed fields, create the existing client-request workflow, change its workflow status, and create existing employee merits/faults. Every write requires an idempotency key and is authorized again by AIS policies. Search results are returned as choices; writes use an unambiguous numeric ID.

The Rails API uses the existing AIS `Authorization: Token token=...` identity. The MCP edge receives a user bearer token and forwards it only server-to-server. In production, place an OAuth 2.1 authorization server/gateway in front of `/mcp`; do not use a shared administrator token.

## Configuration

Set these variables in the existing protected runtime mechanism (never in git):

* `PORT` (default `8787`)
* `MCP_AIS_API_URL` (for example `https://ais.example/api/v1`)
* `MCP_OAUTH_ISSUER` (public OAuth issuer URL)

The Rails application continues to use its existing database, token authentication and policy configuration. The idempotency migration `20261005000000_create_mcp_idempotency_keys.rb` is required.

## Local checks

```bash
cd mcp
npm ci
npm test
node --check server.mjs
```

Test the MCP endpoint with MCP Inspector or an MCP client. `POST /mcp` must return `401` without a bearer token; with a valid user token, `initialize`, `tools/list`, and `tools/call` are supported. The Rails API is mounted at `/api/v1/mcp` behind the existing API authentication.

## Deployment handoff

1. Run the Rails migration in the normal Capistrano workflow; no production data is needed by the migration.
2. Deploy the Rails revision and the `mcp/` service using the existing process manager.
3. Put the service behind HTTPS at `/mcp`; proxy `Authorization`, `Content-Type`, and `Mcp-Session-Id` headers.
4. Configure OAuth 2.1 authorization-code flow with PKCE and a registered redirect URI for ChatGPT Work. The gateway must mint a bearer token that identifies the AIS user; the service must reject missing/expired/revoked tokens.
5. Verify unauthenticated rejection, `tools/list`, a read call, a forbidden write, and an idempotent repeated write in a test environment.

Rollback: stop the MCP service and revert the Rails revision; leave existing AIS data untouched. Revoke a user's access by revoking/rotating the existing AIS token or disabling the AIS account through the normal admin process.

## ChatGPT Work connection

The developer supplies the final HTTPS URL (for example `https://ais.example/mcp`) and the OAuth issuer/consent URL. In ChatGPT Work, add a custom MCP connector, enter that URL, complete OAuth login as the employee, and repeat the flow for each additional employee. Each connection uses that employee's AIS permissions and can be revoked independently.

## Example requests

* “Найди клиента по телефону … и добавь заметку: предпочитает Telegram.”
* “Найди устройство по серийному номеру … и добавь диагностическую заметку …”.
* “Покажи заявку №… и добавь результат диагностики …”.
* “Создай запрос этому клиенту на это устройство с описанием …”.
* “Поставь сотруднику … плюс/минус за …” — the model must first select an unambiguous employee and existing fault category.
