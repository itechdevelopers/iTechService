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
