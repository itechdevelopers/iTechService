# АИС ↔ ChatGPT Work: собственный MCP-плагин

Код подготовлен для ревью и развёртывания разработчиком. Сам по себе этот PR
не запускает endpoint. Целевой URL после развёртывания: `https://ise.itech.pw/mcp`.
Production-данные, конфигурация и сервисы при разработке не менялись.

## Что реализовано

Rails 5.1.7 / Ruby 2.7.5 / PostgreSQL / Sidekiq остаются основным приложением.
Отдельный Node 24 сервис с официальным `@modelcontextprotocol/sdk` 1.32.1
обслуживает stateless Streamable HTTP. PostgreSQL хранит OAuth и идемпотентность;
Node не имеет DB-доступа, общего администратора или сохранённых пользовательских токенов.
Каждый HTTP-запрос проверяет Bearer в Rails; каждый вызов повторно проверяет
пользователя, scopes, Pundit policy/scope и правила операции. Увольнение, изменение
роли и отзыв токена действуют на следующие запросы. `User.current` теперь thread-local:
существующие callbacks/audits не могут получить исполнителя соседнего запроса.

| Инструмент | Назначение |
|---|---|
| `search_orders` | Точный номер **или** телефон; `PhoneTools.convert_phone`, поиск клиента и контактного телефона ремонта; до 20 вариантов с признаком ограничения |
| `get_order` | Текущий статус и последние 20 комментариев, без паролей устройства и лишних полей клиента |
| `get_order_statuses` | Доступные статусы/переходы, параметры архива/пауз, причины и цели тестирования |
| `add_order_comment` | Штатные `OrderNote` / `DeviceNote` с автором и аудитом |
| `change_order_status` | Разрешённый переход с `expected_status`, обязательными параметрами и ключом повтора |
| `revenue_summary` | Существующий `WeeklyMarkup::DashboardData` по импортированному регистру 1С и магазинам |

`order` — товарный заказ `Order`, `service_job` — ремонтная работа `ServiceJob`.
Это разные сущности и пространства ID. Номер/телефон не являются ID для записи.
Товарный переход повторяет последовательность кнопки `Order::NEW_STATUSES`;
архив требует `Order::ARCHIVE_REASONS`. Старые статусы без следующей кнопки
доступны для чтения, изменение выполняется в UI АИС.
Ремонтный статус отличается от клиентского `done/undone` и локации устройства.
Доступны активные ремонтные статусы, кроме `completed`, с параметрами паузы.
Перехват другого техника, вытеснение активного ремонта и завершение через выдачу
остаются в UI АИС. Параметры выводит `get_order_statuses`.
Создание ремонтного перехода/тестирования/согласования выделено в общий
`ServiceJobs::RepairStatusTransition`, используемый UI и MCP.

Товарные callbacks, история, аудит и предусмотренные 1С jobs сохранены.
Никаких инструментов SQL, терминала, произвольных методов и прямых бизнес-записей
через SQL нет. Разработка и тесты не вызывают 1С; она остаётся GET-only.
После включения интеграции штатная смена товарного статуса может поставить
существующее задание синхронизации с 1С — это явно указано в инструменте и согласии.

Выручка — расчёт dashboard по загруженному регистру за вычетом исключённых
операций по его методологии, **не** денежные поступления. Возвращаются версия
методологии/импорта, свежесть, пропущенные и незавершённые дни, данные магазинов.
День без строки магазина отмечен `absent_dates`: это не доказательство нулевых
продаж. Период включительно, до 367 дней, бизнес-часовой пояс `Asia/Vladivostok`.
Право — `WeeklyMarkupDashboardPolicy#details?` (сейчас superadmin), плюс
`ais:revenue`. Неполный импорт не выдаётся за полный результат.

## OAuth и переменные окружения

Реализован OAuth authorization code + PKCE S256 с **предварительно зарегистрированным
публичным клиентом**, `token_endpoint_auth_methods_supported: ["none"]`.
DCR, CIMD и machine-to-machine grants не рекламируются и не реализованы.
Нужны точный client ID и callback, отображаемый текущим интерфейсом создания
плагина ChatGPT. Не подставлять callback по памяти и не использовать wildcard.
Пользователь входит через существующий Devise, видит scopes и подтверждает
CSRF-защищённое согласие. Resource — ровно `https://ise.itech.pw/mcp`.
Одноразовый code живёт 5 минут; access token — час; rotating refresh — 30 дней.
В БД только SHA-256 digest, не секретные токены. Повтор использованного refresh
отзывает его семейство. Неверный resource/client/callback/PKCE отвергается.

В существующий `/var/www/itechservice/shared/.env` добавить:

```dotenv
AIS_MCP_ENABLED=0
AIS_MCP_PUBLIC_ORIGIN=https://ise.itech.pw
AIS_MCP_OAUTH_CLIENT_ID=ais-chatgpt-work
AIS_MCP_OAUTH_REDIRECT_URIS=<точный HTTPS callback из настройки ChatGPT>
```

Origin без завершающего `/`. Несколько точных callbacks разделяются запятой.
Client ID публичен, общего API/admin secret нет. Существующие Rails session,
Devise и DB secrets остаются в действующем механизме окружения; не копировать
их в плагин, Node или PR. Токены/PKCE/содержимое arguments фильтруются в Rails logs.

Создать отдельный `/var/www/itechservice/shared/mcp.env`, доступный deploy с mode 0600:

```dotenv
AIS_MCP_PUBLIC_ORIGIN=https://ise.itech.pw
AIS_MCP_BACKEND_ORIGIN=https://ise.itech.pw
AIS_MCP_PORT=3101
```

Node обращается к `/mcp/ais/*` в Rails по HTTPS. Допустим loopback HTTP, если
разработчик явно настраивает внутренний Rails listener. Внешний HTTP запрещён.
Node слушает только `127.0.0.1`; проверяет Host и Origin; лимит MCP body 32 KiB,
timeout обращения к Rails 15 секунд. Nginx должен сохранять `Authorization`.

## Точная последовательность развёртывания (только разработчик)

1. Ревью PR, обычное слияние в актуальный `master`. Следовать
   [production-releases.md](production-releases.md): свежий origin/master,
   чистый checkout, проверка production revision/ancestry, safety tasks.
   Не деплоить feature-ветку и не переключать `current` вручную.
2. Установить поддерживаемый Node 24 и npm на app-host. Проверить `node --version`
   и `npm --version` от `deploy` и в noninteractive SSH, используемом Capistrano.
   Образец unit использует `/usr/bin/node`; при другом пути исправить **ExecStart**.
3. Подготовить вышеописанные environment files. На первом релизе оставить
   `AIS_MCP_ENABLED=0` до завершения настройки callback/HTTPS.
4. Установить `integrations/chatgpt-mcp/deploy/ais-mcp.service` в
   `/etc/systemd/system/ais-mcp.service`; проверить User/Group deploy и пути.
   Выполнить `sudo systemctl daemon-reload` и
   `sudo systemctl enable ais-mcp.service`. `deploy` должен иметь штатное
   sudo-разрешение на restart этого unit, по аналогии с Sidekiq.
5. Из чистого **актуального master** выполнить:

   ```sh
   AIS_MCP_DEPLOY=1 RBENV_VERSION=2.7.5 bundle exec cap production deploy
   ```

   Опциональные Capistrano hooks устанавливают зависимости lockfile командой
   `npm ci --omit=dev --ignore-scripts --no-audit --no-fund` и делают `npm run check`
   в новом release до публикации, затем restart `ais-mcp.service` после публикации.
   Обычные Rails migrations выполняются штатным deploy. Единственная новая
   миграция — `20261005000000_create_mcp_credentials_and_writes`: две новые таблицы,
   без изменений/пересчёта заказов. Не запускать seeds/imports.
   При отсутствии `AIS_MCP_DEPLOY=1` Node hooks не выполняются. Для следующих
   релизов с включённым MCP применять этот флаг, иначе Node может остаться на старом
   release после смены current.
6. В существующий HTTPS server block аккуратно добавить
   `integrations/chatgpt-mcp/deploy/nginx.conf`, проверить `sudo nginx -t`, затем
   штатно reload nginx. Не заменять Rails/Passenger config. Только **точный** `/mcp`
   и protected-resource metadata идут в Node. `/mcp/oauth/*`, `/mcp/ais/*` и OAuth
   discovery идут в Rails; общий proxy `/mcp/*` создаст ошибочную маршрутизацию.
   Сохранить действующие TLS и лимиты доступа; не логировать Authorization/тела.
7. Указать точный callback, включить `AIS_MCP_ENABLED=1`, штатно перезапустить Rails
   через инфраструктуру приложения. Перезапустить Node, если менялся его env.
8. Настроить восстановление notification outbox раз в минуту в существующем
   операторском scheduler: из `current`, с Rails production environment,
   `RBENV_VERSION=2.7.5 bundle exec rake mcp:dispatch_outbox`.
   Нормальный путь отправляет jobs после коммита автоматически; scheduler нужен
   для восстановления после падения процесса/Redis. Внести в мониторинг pending
   `mcp_writes` и `[MCP] outbox pending`.

Уведомления имеют стандартную гарантию очереди **at least once**: при падении
между постановкой job в Redis и отметкой dispatched уведомление может повториться.
Бизнес-комментарий, статус и сессия/согласование при retry не повторяются.
`request_key` с другим payload отвергается; запись сериализуется по сотруднику
и заказу, журнал хранит пользователя, ID, время, outcome и минимальный result,
без текста комментария/телефона. Не удалять `mcp_writes` ради обслуживания БД:
это уничтожит гарантию повторов старых ключей.

## Проверка после развёртывания

```sh
curl -fsS https://ise.itech.pw/mcp/health
curl -fsS https://ise.itech.pw/.well-known/oauth-protected-resource/mcp
curl -fsS https://ise.itech.pw/.well-known/oauth-authorization-server
curl -i -X POST https://ise.itech.pw/mcp -H 'Content-Type: application/json' -d '{}'
```

Последний запрос без Bearer должен вернуть 401 и `WWW-Authenticate` с
protected-resource metadata, а не HTML login. `/mcp/health` — живость процесса,
готовность требует успешного discovery/OAuth и чтения через MCP.
Проверить unit logs, scopes, resource и PKCE S256 discovery.
Затем в ChatGPT пройти реальный login/consent и проверить initialization,
`tools/list`, пустой поиск, варианты совпадений и чтение разрешённого заказа.
Проверить другой обычной учётной записью отказ в выручке и отсутствие общего
администратора. Тестовые изменения, неверные переходы и повторы выполнять
**только на отдельном тестовом окружении с синтетическими заказами**.
Не менять production-заказы ради smoke test и не запускать 1С write-вызовы.
Тестовую проверку внешних уведомлений/1С проводить со stub/sandbox получателями.

## Локальные проверки и ограничения

Результат проверки 2026-10-05: 17 Node MCP tests и 20 Rails tests / 111 assertions,
без ошибок. Проверены initialization/list/call, OAuth/CSRF/PKCE/revocation,
реальные policies и модели, concurrent retries, ошибки/rollback записи,
выручка из синтетического импорта, outbox recovery и migration down/up.
Полный HTTP-путь SDK → Node → Rails проверен. Syntax и diff checks пройдены.

```sh
cd integrations/chatgpt-mcp
npm ci --ignore-scripts --no-audit --no-fund
npm run check
npm test
```

Rails-проверки работают только на отдельной loopback PostgreSQL с DB name
`ais_mcp_isolated_test`; helper откажется от иного DB host/name. Он загружает
schema **только в эту выделенную БД**, создаёт синтетические fixtures, очищает их
между тестами, перехватывает HTTP и использует test ActiveJob adapter.
Не подключать к существующей пользовательской/production БД.
Пример подготовки чистого disposable кластера (пути PG_BIN/порт выбрать локально):

```sh
mkdir -p work
PG_BIN=/path/to/postgresql/bin
"$PG_BIN/initdb" -D "$PWD/work/mcp-test-pg" -A trust --no-locale -E UTF8
"$PG_BIN/pg_ctl" -D "$PWD/work/mcp-test-pg" -l "$PWD/work/mcp-test-pg.log" -o '-h 127.0.0.1 -p 55439' start
"$PG_BIN/createdb" -h 127.0.0.1 -p 55439 ais_mcp_isolated_test
RAILS_ENV=test DB_HOST=127.0.0.1 DB_PORT=55439 DB_USERNAME="$(whoami)" \
 DB_NAME_TEST=ais_mcp_isolated_test AIS_MCP_TEST_PREPARE=1 \
 AIS_MCP_NODE_BIN=/absolute/path/to/node \
 bundle exec ruby test/mcp/integration_test.rb
"$PG_BIN/pg_ctl" -D "$PWD/work/mcp-test-pg" stop -m fast
```

В запуске нужен Ruby 2.7.5 и Node 24. Общая тестовая загрузка проекта по-прежнему
встречает несовместимость `chromedriver-helper` / Selenium 4. MCP helper пропускает
только этот browser-only require **в собственном тестовом процессе**; зависимости
проекта не изменены. Browser/full-suite проверки этим запуском не покрываются.
Реальный ChatGPT OAuth/TLS/nginx, production Node installation и внешний fan-out
проверяет разработчик после настройки; production не использовался для разработки.

## Откат и отзыв доступа

Первый безопасный шаг — `AIS_MCP_ENABLED=0` и штатный restart Rails; затем остановить
`ais-mcp.service` и убрать его nginx locations, проверив nginx config. АИС продолжит
работать. Сохранить таблицы OAuth/idempotency и исторические бизнес-записи.
Для отключения сотрудника:

```sh
AIS_MCP_REVOKE_USER_ID=<точный user ID> RAILS_ENV=production \
 RBENV_VERSION=2.7.5 bundle exec rake mcp:revoke_user
```

Для отката кода предпочтителен прошедший ревью revert в актуальном master и
штатный Capistrano deploy; правила rollback в production-releases.md сохраняются.
Не откатывать production БД/заказы. Down миграции проверяется только в disposable
тестовой БД; он удаляет OAuth и журнал ключей, поэтому для операционного отката
не нужен.

## Личный плагин ChatGPT Work

Актуальные официальные инструкции:
[Quickstart](https://developers.openai.com/plugins/quickstart),
[OAuth](https://developers.openai.com/plugins/build/auth),
[MCP server](https://developers.openai.com/plugins/build/mcp-server),
[Packaging](https://developers.openai.com/plugins/build/plugins).
Проверены 2026-10-05.

1. После деплоя: ChatGPT → Settings → Security and login → Developer mode.
2. ChatGPT Plugins → плюс → подключить `https://ise.itech.pw/mcp`, OAuth,
   predefined client с `AIS_MCP_OAUTH_CLIENT_ID`, public token authentication `none`.
   Передать разработчику **точный callback из интерфейса**, если он ещё не добавлен
   в allowlist. Callback не секрет; учётные данные/токены не пересылать.
3. Создать личный плагин, войти своей учётной записью АИС, проверить scopes и
   нажать «Разрешить». Никакой общей admin-учётной записи.
4. В personal Plugins установить плагин, открыть новый Work chat и выбрать `@АИС`.
   Workspace admin может ограничивать developer mode/плагины/запись; это не
   обходится серверными аннотациями.

`integrations/chatgpt-mcp/plugin/` содержит актуальные portable `plugin.json`,
`mcp.json` (Agent Plugins schema 1.0.0) и skill. Это пакет для repo/local
распространения по поддерживаемым поверхностям. Для личного плагина на web
официальный путь — подключение развёрнутого HTTPS MCP; наличие файлов в репозитории
само по себе не устанавливает плагин в ChatGPT и не регистрирует его публично.
Legacy `ai-plugin.json` не используется.

Пять примеров запросов:

- «Найди заказ по номеру N-123. Если есть несколько видов заказов, покажи варианты».
- «Найди мои заказы по телефону +7 (423) 234-56-78 и покажи текущие статусы».
- «Какие переходы разрешены для ремонта service_job ID 123 и что требуется для паузы?».
- «Добавь к товарному заказу order ID 456 внутренний комментарий: клиент уточнит цвет завтра».
- «Покажи выручку по магазинам с 1 по 30 сентября 2026 года; укажи пропуски и методологию».

Для статуса: «Переведи order ID 456 из current в pending, если АИС разрешает переход».
