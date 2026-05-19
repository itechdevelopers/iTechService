# PLAYBOOK.md — Project-specific patterns for iTechService

Patterns and recipes specific to this codebase. Reference: see also [CLAUDE.md](CLAUDE.md) (workflow rules) and [CONTEXT.md](CONTEXT.md) (architecture).

---

## Data migrations (для справочников и backfill)

В проекте подключён gem `data_migrate` (`gem 'data_migrate', '~> 7.0.2'` в Gemfile) и Capistrano-расширение `capistrano/data_migrate` (в Capfile). Это значит: **на каждом `cap production deploy` автоматически прогоняется `data:migrate`** наряду со `schema db:migrate`. Никаких ручных шагов на проде.

**Когда использовать data-миграцию вместо seedbank/seeds:**
- Засеиваем справочные данные, без которых код упадёт (FK / lookup'ы, на которые ссылаются callbacks).
- Backfill полей по существующим записям.
- Любая операция, которую **обязательно** надо выполнить на проде ровно один раз.

**Когда использовать seedbank (`db/seeds/*.seeds.rb`):**
- Тестовые данные для dev-среды.
- Опциональный сидинг, который тимлид запускает руками когда нужно.

### Как создать data-миграцию

```bash
bin/rails generate data_migration <CamelCaseName>
# создаст: db/data/YYYYMMDDHHMMSS_<snake_case_name>.rb
```

Тело — обычный Rails-миграционный класс с `up`/`down`:

```ruby
class SeedSomething < ActiveRecord::Migration[5.1]
  def up
    [...].each { |attrs| Model.find_or_create_by!(...) }  # ← идемпотентно!
  end

  def down
    Model.where(...).delete_all  # либо raise IrreversibleMigration
  end
end
```

**Правила:**
1. **Всегда `find_or_create_by!`** (не `create!`) — миграцию могут перезапустить, и она должна быть идемпотентна.
2. **Версия Rails в class declaration обязательна** (`< ActiveRecord::Migration[5.1]`). Без неё на Rails 5+ — runtime error «Directly inheriting from ActiveRecord::Migration is not supported».
3. **Schema-миграция должна предшествовать data-миграции** по timestamp'у (data-миграция использует таблицы/колонки, которые создала schema).

### Как запускать локально

```bash
bin/rails db:migrate          # schema-миграции
bin/rails data:migrate        # data-миграции
# одной строкой:
bin/rails db:migrate:with_data
```

Откат: `bin/rails data:rollback STEP=1`. Точечно: `bin/rails data:migrate:up VERSION=<ts>`.

### На продакшене

`cap production deploy` автоматически прогоняет обе. **Ручных шагов не нужно.** В отчёте деплоя ищи строки `== <timestamp> <ClassName>: migrated`.

### Что коммитить в feature-ветке

- `db/migrate/<ts>_*.rb` — schema-миграция.
- `db/data/<ts>_*.rb` — data-миграция.
- `db/schema.rb` — обновлённый дамп схемы (Rails сам перезапишет).
- `db/data_schema.rb` — маркер версии последней data-миграции (одна строка `DataMigrate::Data.define(version: <ts>)`). Без него на другой машине `data:migrate` подумает что наша миграция ещё не применена.

### Известные грабли

- **Старая миграция без `[версии]` блокирует все pending data-миграции.** Если `data:migrate` падает с `Directly inheriting from ActiveRecord::Migration is not supported` — найди и почини виновный файл (добавь `[4.2]` или подходящую версию). До этого **новые** data-миграции не запустятся, в т.ч. на проде.
- В проекте до 2026 года была всего одна data-миграция (с 2021), и она была написана без указания версии Rails. Починена в ветке `137-repair-statuses` (2026-05-06): тело удалено как устаревшее, версия `[4.2]` проставлена.

---

## UI testing с Playwright MCP

Playwright MCP позволяет автоматически проверять UI-фичи без участия пользователя — навигация, клики, скриншоты, инспекция DOM.

### Перед запуском

1. **Поднять dev-сервер:** `bin/rails server -p 3000 -e development` (фоном через `run_in_background: true`). Дождаться отклика: `until curl -sS -o /dev/null --max-time 2 http://localhost:3000; do sleep 2; done`.
2. **Получить тестового юзера** у пользователя — username + password. **Никогда не угадывать** пароли реальных юзеров. Логин в Devise: поле `user[username]`, не `email`.
3. Если боишься испортить dev-БД — спросить разрешения или предложить создать временного test-юзера.

### Известные нюансы

- **`hover` теряется между tool-вызовами.** Если в DOM есть cascading submenu через CSS `:hover` — Playwright делает hover, потом следующий tool-call (screenshot, click) → mouse уходит → submenu прячется. Решение: проверять submenu сразу через `browser_evaluate({ display, visibility })` пока hover активен; для click на скрытый под-пункт — использовать `browser_evaluate` с прямым `link.click()` (Rails-UJS зарегистрирован на ссылке).
- **Bootstrap 2.x dropdown** открывается на `click` по triggering element с `data-toggle="dropdown"`. Класс `.btn-group` получает `.open` когда раскрыт.
- **Strict mode locator violation** при идентичных селекторах в разных местах — использовать ID-обёртку (`#repair_status_widget_header .foo`).

### Cleanup в конце (обязательно)

```bash
# 1. Закрыть браузер
mcp__playwright__browser_close

# 2. Остановить dev-сервер (browser_close его НЕ убивает)
ps aux | grep -E "puma|rails server" | grep -v grep
kill <PID>
# проверить:
curl -sS -o /dev/null --max-time 2 http://localhost:3000  # должно вернуть error

# 3. Удалить артефакты (скриншоты, дампы) из корня репо
rm -f cycle*.png page-*.png screenshot-*.png

# 4. Если меняли данные через UI — спросить пользователя что делать с БД
```

См. также memory `feedback_session_cleanup.md` — общее правило про cleanup после внешних ресурсов.

---

## `Setting` model — чтение и запись из кода

`Setting` — это EAV-таблица: одна строка на ключ, значение хранится в колонке `value` (text), тип значения — в `value_type`. Допустимы только примитивные типы: `boolean`, `integer`, `string`, `text`, `json` (см. `Setting::VALUE_TYPES` в [app/models/setting.rb](app/models/setting.rb)). **Типа `date` нет** — даты кладём как ISO-строку (`Date.current.to_s` → `"2026-05-19"`) с типом `'string'`.

### Регистрация нового параметра

1. Добавить ключ в `Setting::TYPES` хеш в [app/models/setting.rb](app/models/setting.rb):
   ```ruby
   TYPES = {
     ...
     my_new_flag: 'boolean',          # или 'integer', 'string', 'text', 'json'
   }.freeze
   ```
2. Добавить русский лейбл в [config/locales/views/settings.ru.yml](config/locales/views/settings.ru.yml) под ключом `settings.my_new_flag` — иначе на странице `/settings` будет английский `humanize`-fallback.
3. Никаких миграций не нужно — записи создаются лениво.

### Чтение

```ruby
Setting.my_new_flag           # method_missing → typecast по TYPES (Bool/Int/String/Hash)
Setting.my_new_flag?          # для boolean — алиас, тоже работает
Setting.get_value(:my_new_flag)  # сырая строка без typecast — полезно для дат и edge-cases
```

`method_missing` смотрит сначала на department-scoped запись (`Department.current`), затем на глобальную (`department_id: nil`). Для системных флагов всегда используем глобальную.

### Запись из кода (нет class-level setter'а!)

`Setting.my_new_flag = ...` **не работает** — есть только getter через `method_missing`, setter не определён. Канонический способ записи — копируем паттерн из [find_my_device_checks_controller.rb:54-58](app/controllers/find_my_device_checks_controller.rb#L54-L58):

```ruby
setting = Setting.find_or_initialize_by(name: 'my_new_flag', department_id: nil)
setting.value = '1'                          # bool: '1'/'0'; int/string: to_s; json: .to_json
setting.value_type = 'boolean'               # обязательно при первом создании
setting.presentation = I18n.t('settings.my_new_flag')  # иначе before_validation подставит humanize
setting.save!
```

**Гарантии:**
- `find_or_initialize_by` идемпотентен — повторный вызов обновит существующую запись.
- `before_validation` в `Setting` ([app/models/setting.rb:55-58](app/models/setting.rb#L55-L58)) подставит `value_type` и `presentation` из дефолтов, если оставить пустыми, — но лучше задавать явно, потому что при rename ключа в `TYPES` дефолт сломается.
- Для глобальных настроек обязательно `department_id: nil` — иначе создастся scope'нутая запись в текущем департаменте, и другие департаменты её не увидят.

### Сброс параметра

```ruby
Setting.find_by(name: 'my_new_flag')&.destroy
```

После destroy `Setting.my_new_flag` вернёт typecast'нутую `nil`/пустоту (`false` для boolean, `0` для integer, `""` для string, `{}` для json).

### Известные грабли

- **Setting не годится для частых записей.** Это AR-модель с `before_validation`-колбэком и callback'ами вроде `apply_warranty_overstay_thresholds` — каждая запись = транзакция. Для счётчиков/HEARTBEAT'ов используй `Rails.cache` или отдельную таблицу.
- **`Date.today` vs `Date.current`.** В коде, который пишет даты в Setting (например, `transcription_silence_last_notified_on`), всегда `Date.current` — он уважает `Time.zone` из [config/application.rb](config/application.rb), `Date.today` берёт системное время сервера. На сервере в UTC утром во Владивостоке это разные числа.
