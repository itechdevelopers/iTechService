# AIS MCP plugin

This integration exposes the existing AIS business rules to ChatGPT Work through an official MCP Streamable HTTP server. It intentionally does not expose revenue or financial analytics.

## Tools

The server provides read tools for clients, devices, service requests, client requests, repair-option comparison, device-unlock requests, report catalog/electronic-queue reporting, equipment orders, employees, merits/faults and fault categories. Write tools append notes, update explicitly allowed fields, create the existing client-request workflow, change client-request or unlock-request status, append unlock comments, and create existing employee merits/faults. Every write requires an idempotency key and is authorized again by AIS policies. Search results are returned as choices; writes use an unambiguous numeric ID.

Repair options use the existing `Product` → `RepairService` → `SparePart`/`RepairPrice` data shown by the AIS repair screens. Internal cost is explicitly labelled as current `Product#purchase_price` summed with configured quantities; it is not a discount or automatically a profit. Unlock workflow tools expose the existing enum statuses and the existing status/comment operations, but never perform a technical device unlock. Queue metrics call `ElqueueTicketsReport`; report and department access are checked server-side. Equipment-order analytics use the existing `Order` entity with `object_kind=device`, and distinguish `Order#quantity` from order count and from sales.

The Rails API authorizes each employee using a separate, expiring MCP credential. `/api/v1/mcp_sessions` verifies the existing AIS password before issuing it; it does not call the legacy `/signin` endpoint or rotate `User#authentication_token`. Rails stores only the SHA-256 digest in `mcp_api_tokens`. Each connection has its own one-hour token. Fired employees, expired credentials and credentials with `revoked_at` set are rejected. The MCP broker checks `/mcp_sessions/current` before discovery and every MCP request; an AIS 401 prompts OAuth reconnection, including when a token becomes invalid during a tool call. `/oauth/revoke` revokes the corresponding Rails credential as well as the broker token.

OAuth authorization codes and bearer-to-AIS mappings remain in the Node process memory. A restart invalidates current connections and requires reconnection; run one process. Multiple processes require a private shared code/token store before deployment. Revocation in Rails is persistent and survives restarts. Do not use a load-balanced multi-process setup with the current broker.

## Configuration

Set these variables in the existing protected runtime mechanism (never in git):

* `PORT` (default `8787`)
* `MCP_AIS_API_URL` (for example `https://ais.example/api/v1`)
* `MCP_PUBLIC_URL` (exact public HTTPS MCP URL, for example `https://ais-mcp.example/mcp`; required behind HTTPS proxy)
* `MCP_OAUTH_ISSUER` (public OAuth issuer URL; defaults to the origin of `MCP_PUBLIC_URL`)
* `MCP_OAUTH_CLIENT_ID` (registered ChatGPT client ID, default `chatgpt-work`)
* `MCP_OAUTH_REDIRECT_URIS` (comma-separated exact HTTPS redirect URIs)

The Rails application continues to use its existing database, token authentication and policy configuration. Both migrations are required: `20261005000000_create_mcp_idempotency_keys.rb` and `20261007000000_create_mcp_api_tokens.rb`. No legacy API token is modified by them.

## Local checks

```bash
cd mcp
npm ci
npm test
node --check server.mjs
```

Test the MCP endpoint with MCP Inspector or an MCP client. `POST /mcp` must return `401` without a bearer token; with a valid user token, `initialize`, `tools/list`, and `tools/call` are supported. The Rails business endpoints are mounted under `/api/v1` behind the existing API authentication.

## Deployment handoff

1. Run the Rails migration in the normal Capistrano workflow; no production data is needed by the migration.
2. Deploy the Rails revision and the `mcp/` service using the existing process manager.
3. Put the service behind HTTPS at `/mcp`; proxy `Authorization`, `Content-Type`, and `Mcp-Session-Id` headers.
4. Configure `MCP_PUBLIC_URL`, `MCP_OAUTH_ISSUER`, `MCP_OAUTH_CLIENT_ID` and `MCP_OAUTH_REDIRECT_URIS`. Publish `/oauth/authorize`, `/oauth/token`, `/oauth/revoke` and both OAuth metadata endpoints over the same HTTPS host. The service rejects missing/expired/revoked tokens, invalid audience, invalid redirect URIs and failed PKCE.
5. Verify unauthenticated rejection, `tools/list`, a read call, a forbidden write, and an idempotent repeated write in a test environment.

Existing OAuth connections created by the earlier broker must reconnect once after this upgrade.

Rollback: stop the MCP service and revert the Rails revision; leave existing AIS data untouched. Revoke a user's access by revoking/rotating the existing AIS token or disabling the AIS account through the normal admin process.

## ChatGPT Work connection

The developer supplies the final HTTPS URL (for example `https://ais.example/mcp`) and the OAuth issuer/consent URL. In ChatGPT Work, add a custom MCP connector, enter that URL, complete OAuth login as the employee, and repeat the flow for each additional employee. Each connection uses that employee's AIS permissions and can be revoked independently.

## Example requests

* “Найди клиента по телефону … и добавь заметку: предпочитает Telegram.”
* “Найди устройство по серийному номеру … и добавь диагностическую заметку …”.
* “Покажи заявку №… и добавь результат диагностики …”.
* “Создай запрос этому клиенту на это устройство с описанием …”.
* “Поставь сотруднику … плюс/минус за …” — the model must first select an unambiguous employee and existing fault category.

## Себестоимость по штрихкоду (1С)

`get_product_cost_by_barcode` отвечает на «Какая себестоимость товара со штрихкодом …?».
Передавайте `barcode` **строкой**, например `"0012345678905"`. Инструмент только читает;
в Rails это `GET /api/v1/products/cost_by_barcode`. Права проверяются при каждом вызове
через существующий `ProductPolicy#view_purchase_price?` (сейчас только superadmin),
до запуска клиента 1С. Общая учётка OData не предоставляет прав сотруднику.

Точный источник поиска — `InformationRegister_ШтрихкодыНоменклатуры`, точное равенство
поля `Штрихкод` с экранированием литерала и URL-кодированием существующим клиентом.
Возвращаются связанные `Номенклатура_Key`, `Характеристика_Key`, `Упаковка_Key`.
Несколько совпадений дают `selection_required` и варианты с ID/названиями; повторный
вызов принимает `product_id`, `characteristic_id`, `package_id`. Не выбирать первый вариант.
Это источник товарных штрихкодов; составные логистические упаковки из отдельного
`Catalog_ШтрихкодыУпаковокТоваров` в этой первой функции не разрешаются.

Используется уже установленное правило балансовой оценки запасов:
**`AccumulationRegister_СебестоимостьТоваров/Balance`: `СтоимостьBalance / КоличествоBalance`**.
Это средняя стоимость единицы **внутри каждой полной группы учёта**, а не цена закупки,
цена продажи или прогноз себестоимости будущего списания. Отдельные ресурсы
`ДопРасходыBalance` не прибавляются: прежняя проверенная оценка запасов использует
именно `СтоимостьBalance`. Валюта этого источника в исследованной базе — RUB.
Для упаковки результат умножается на `Числитель / Знаменатель` из
`Catalog_УпаковкиЕдиницыИзмерения`. Возвращаются упаковка, базовая единица и коэффициент.
Неизвестная единица/коэффициент даёт `unit_unavailable`, сумма не вычисляется.

`Catalog_КлючиАналитикиУчетаНоменклатуры` ищется только для найденного товара и
характеристики. `Balance` вызывается только для найденных ключей аналитики.
`Dimensions` не задаётся: публикация возвращает все родные группы; длинный аргумент
`Dimensions` нарушает её URL segment limit. Сохраняются организация, место хранения
с типом ссылки, серия, назначение, партия с типом, раздел учёта, вид запасов,
аналитика партий/финансового учёта и вид деятельности НДС. Эти группы не смешиваются.
Дополнительные фильтры: `organization_id`, `warehouse_id`, `party_id`, `as_of`.
`party_id` выбирает возвращённый ID партии; для совпадающих ID разных типов остаётся
разбивка по типам. Склад не подразумевается текущим филиалом. Право сейчас только у
superadmin; прежде чем расширять policy, отдельно определить допустимый scope 1С.

`as_of` — местное время базы `Asia/Vladivostok`, ISO `YYYY-MM-DDTHH:MM:SS`;
по умолчанию момент начала операции, будущие даты запрещены. `read_at` — время
чтения. `data_origin=direct_1c_odata`: это прямое чтение, не синхронизированная копия.
Локальный `metadata.xml` — только проверенная схема, не кэш стоимости.
Ответ содержит источник, определение и ограничения: балансовый остаток может
отличаться от физического; стоимость может измениться при расчёте/закрытии периода;
сам факт закрытия периода не подтверждается. Пустой регистр, отсутствующий ресурс,
нулевой/отрицательный остаток, отрицательная/нечисловая сумма дают отсутствующую
стоимость, а не ноль. Настоящий нулевой ресурс при положительном количестве допустим.

Чтение ограничено: максимум 20 совпадений и 20 ключей аналитики, менее 100 групп
на ключ. Достижение лимита/nextLink отвергается как неполный результат, не выдаётся
частичная стоимость. В этом случае уточнить склад/организацию. Каталог целиком не
читается. Ошибки соединения/1С/схемы и timeout дают безопасный 502 без тел ответов,
адресов и секретов. Весь процесс ограничен 45 секундами и 1 МБ вывода. Никакого
инструмента произвольных OData-запросов не добавлено.

### Настройка при развёртывании

Используется **существующий** GET-only `1c-odata-agent/odata.py`, его защищённый `.env`
и проверенный `local/metadata.xml`. Rails запускает фиксированную бизнес-операцию
`script/mcp/product_cost.py` как дочерний процесс; нового сервиса/порта не требуется.
В существующем защищённом окружении Rails задать:

```dotenv
AIS_MCP_ODATA_CONNECTOR=/absolute/path/to/installed/1c-odata-agent
AIS_MCP_PYTHON=/absolute/path/to/python3
```

Нужен Python >= 3.9 с данными часового пояса. Пользователь процесса Rails должен
иметь право читать клиент/схему и `.env`; требования существующего клиента: `.env`
принадлежит этому пользователю, mode 0600, не symlink. Секреты не копировать в Node,
плагин или git. Существующий OData endpoint/хранение секретов не меняются. До rollout
проверить доступность клиента на Rails-хосте, его версию и соответствие проверенной
схемы публикации; не заменять его HTTP-клиентом заказа `OneCBaseClient`.

Новых миграций для этой функции нет. Штатные migration/OAuth/proxy шаги исходного PR
сохраняются. На staging проверить employee login, отказ обычному сотруднику и чтение
superadmin, пакет/характеристику, ошибки/таймаут; затем сверить со штатным отчётом 1С
на одинаковую дату и группы учёта. Production в рамках этой задачи не изменялся,
деплой не выполнялся.

### Проверки 2026-10-06

- 15 Python tests: успешный расчёт, ведущие нули, экранирование, запрет numeric barcode,
  неоднозначность, неизвестный выбор, not_found, упаковка/характеристика, отсутствие
  стоимости, нулевое количество, пустой остаток, ошибка 1С, неполная выборка,
  параметры склада/организации/партии, будущая дата/неверный UUID.
- 7 Rails tests / 16 assertions на отдельной disposable loopback БД: реальный policy
  отказ до клиента, superadmin, сохранение строки, 502/422, anonymous 401; реальный Rails→Python subprocess с fixture-коннектором, успешный
  ответ и неверный тип штрихкода.
- 3 Node tests: существующий MCP HTTP/OAuth flow расширен проверками нового tool,
  чтения, строковой схемы, forwarding пользовательского токена, 403/502 и numeric rejection.
- Ruby/Node syntax и `git diff --check`.
- Контрольная read-only операция на существующей публикации 1С: штрихкод
  `2044501144052`, товар `1f7096de-ec76-11ec-b2c9-3cecef20832b` «Шалаш Для Кота Бордовый»:
  на `2026-10-06T15:26:06` получено `СтоимостьBalance=1500`, `КоличествоBalance=1`,
  **1500 RUB/шт**, организация `3164f27a-83b8-11e7-a2b1-ec3586495f21`, склад
  `1ea7b079-5687-11ed-b2c9-3cecef20832b`. Одна контрольная операция состояла из 7 GET;
  при отладке ограничения URL были повторные GET, никаких writes.
- Сверка с экраном/штатным отчётом 1С **не выполнена**: UI не подключён. Она остаётся
  разработчику. Пакет/характеристика проверены fixtures, не отдельными production товарами.

```sh
python3 -m unittest discover -s script/mcp -p 'test_*.py'
cd mcp && npm test
```

Rails: только отдельная loopback БД `ais_mcp_cost_test`, `RAILS_ENV=test`,
`DB_HOST=127.0.0.1`, `DB_PORT=<disposable-port>`, `DB_USERNAME=<local-user>`,
`DB_NAME_TEST=ais_mcp_cost_test`, `AIS_MCP_COST_TEST_PREPARE=1`, Ruby 2.7.5:
`bundle exec ruby test/mcp/product_cost_test.rb`. Helper загружает schema только в эту
БД и блокирует внешний HTTP; browser helper пропускается только в этом процессе
из-за существующей несовместимости Selenium. Обычную/production БД не использовать.

## API behavior and review corrections

- Merit/Fault creation uses Trailblazer 2.0 positional runtime options, checks policy failure separately (403), and defaults an omitted date to the employee-local current date. Contract errors return 422.
- Service-request search unions separate ticket, device and client subqueries inside the employee policy scope, including archived jobs; the result limit applies after deduplication.
- Merits/faults can be read by the employee themselves or any administrator, matching profile tabs. Client-request reads use the existing index/show policies. Report discovery uses ReportPolicy, including individual report access.
- Repair purchase prices and total cost are null with `cost_visibility=hidden_by_permissions` unless ProductPolicy permits them. A missing permitted price also yields a null total, not an invented zero.
- Write results and reserved idempotency keys share one transaction. A PostgreSQL transaction advisory lock serializes the same employee/operation/key across processes. Changed payloads return 409; Grape validation/policy aborts roll back the reservation and business writes. Appended diagnostic notes enqueue the existing subscriber notification once on a successful retry sequence.
- Search clients returns summaries; get_client includes bounded devices/jobs without job notes (use get_request for notes). Unlock-request search omits comments; get_unlock_request returns up to 50 newest comments.
- Date filters accept real ISO dates/timestamps, reject impossible dates/reversed ranges with 422 and use the employee time zone. Times with offsets preserve that offset. The request restores the previous Rails thread time zone even on failure.
- The Node entrypoint resolves symlinks, so Capistrano `current/mcp/server.mjs` starts normally. Metadata, OAuth audience and authentication challenges use the configured public URL, without trusting forwarded headers.

Manual acceptance (test/staging only): sign in twice through `/mcp_sessions`, ensure both tokens work and the legacy token is unchanged; try an incorrect password and ensure no credential changes; revoke one token and check the other still works. Repeat notes with the same idempotency key both sequentially and concurrently; verify one record and one notification job. Verify 403 for denied merit/fault creation and 201 for authorized creation without date. Search by ticket alone, serial/IMEI alone and client alone. Compare own/other employee read permissions, technician client-request access, restricted repair cost fields, individual report access and invalid date filters. Verify HTTPS metadata/challenges using `MCP_PUBLIC_URL`, and startup through a symlink.

Request RSpec currently needs an explicit test-only compatibility shim for the existing chromedriver-helper/Selenium blocker. The workaround does not fix normal RSpec startup and is not used at runtime. Record the exact command and shim files when reporting test results.
