# AIS MCP plugin

This integration exposes the existing AIS business rules to ChatGPT Work through an official MCP Streamable HTTP server. It intentionally does not expose revenue or financial analytics.

## Tools

The server provides read tools for clients, devices, service requests, client requests, repair-option comparison, device-unlock requests, report catalog/electronic-queue reporting, equipment orders, employees, merits/faults and fault categories. Write tools append notes, update explicitly allowed fields, create the existing client-request workflow, change client-request or unlock-request status, append unlock comments, and create existing employee merits/faults. Every write requires an idempotency key and is authorized again by AIS policies. Search results are returned as choices; writes use an unambiguous numeric ID.

Repair options use the existing `Product` → `RepairService` → `SparePart`/`RepairPrice` data shown by the AIS repair screens. Internal cost is explicitly labelled as current `Product#purchase_price` summed with configured quantities; it is not a discount or automatically a profit. Unlock workflow tools expose the existing enum statuses and the existing status/comment operations, but never perform a technical device unlock. Queue metrics call `ElqueueTicketsReport`; report and department access are checked server-side. Equipment-order analytics use the existing `Order` entity with `object_kind=device`, and distinguish `Order#quantity` from order count and from sales.

The Rails API uses the existing AIS `Authorization: Token token=...` identity. The MCP service implements a small OAuth 2.1 authorization-code + PKCE broker: the employee signs in on `/oauth/authorize`, the service calls the existing AIS `/api/v1/signin`, and exchanges a one-time code at `/oauth/token`. The resulting short-lived MCP token maps to that employee's AIS token in memory; every Rails call forwards that employee token and therefore re-runs AIS authentication and Pundit authorization. No administrator token is used. Configure a single ChatGPT client and its exact redirect URI; for a multi-instance deployment move the short-lived code/token store to the project's existing private shared store before scaling horizontally.

## Configuration

Set these variables in the existing protected runtime mechanism (never in git):

* `PORT` (default `8787`)
* `MCP_AIS_API_URL` (for example `https://ais.example/api/v1`)
* `MCP_OAUTH_ISSUER` (public OAuth issuer URL)
* `MCP_OAUTH_CLIENT_ID` (registered ChatGPT client ID, default `chatgpt-work`)
* `MCP_OAUTH_REDIRECT_URIS` (comma-separated exact HTTPS redirect URIs)

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
4. Configure `MCP_OAUTH_ISSUER`, `MCP_OAUTH_CLIENT_ID` and `MCP_OAUTH_REDIRECT_URIS`. Publish `/oauth/authorize`, `/oauth/token`, `/oauth/revoke` and both OAuth metadata endpoints over the same HTTPS host. The service rejects missing/expired/revoked tokens, invalid audience, invalid redirect URIs and failed PKCE.
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
