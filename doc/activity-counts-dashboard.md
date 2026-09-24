# Sales receipt and issued repair counts

Two additional superadmin-only tiles on `/weekly_markup_dashboard`. Drilldowns:
`/weekly_markup_dashboard/activity_counts?metric=receipts` and
`/weekly_markup_dashboard/activity_counts?metric=issued_repairs`.
Existing markup, iPhone and order synchronization paths are preserved.

## Definitions

- Sales: one unique `Document_ЧекККМ.Ref_Key`, `Posted=true`, `DeletionMark=false`,
  `Статус=Пробит`. Archived receipts are included. Return documents are not
  subtracted from the number of sale receipts. This is neither revenue nor units.
  Store is `Склад_Key`, named from `Catalog_Склады`. All receipt warehouses are
  retained; unknown warehouses remain visible. No customer/payment/phone fields.
- Repairs: one service job's first recorded transition from a nonarchive location
  to an archive location in `history_records`. Exclude deleted history entries,
  missing job IDs, missing old locations and archive-to-archive moves. Store is the destination
  archive's department, not the job's current department. Reissued orders count
  once. Includes issued orders regardless of repair success; not ready tasks or
  planned `return_at`. Deleted history or changed archive definitions can affect
  reconstruction; this is the existing AIS issuance record, not independent proof
  of physical handover.
- Completed days in Asia/Vladivostok. Current year compares through the same
  month/day in the previous year; Feb 29 clamps to Feb 28. Completed historical
  years compare whole years. Show five previous completed years plus current;
  load a sixth previous year as the first displayed year's growth baseline.
- Missing day is unknown, never zero. Each published day is a complete network
  snapshot, so a missing branch within that day is zero. No ratio unless both
  periods are complete and baseline > 0. Catalog names use latest loaded labels.

## Storage and failure behavior

Migration only adds `activity_count_imports` and `activity_count_days` plus their
indexes/FK. Immutable source payloads retain delivery IDs and source timestamps.
Materialized daily snapshots update atomically under a per-metric advisory lock;
older/equal source timestamps cannot overwrite newer counts. Duplicate delivery
returns original import. Invalid/truncated data is rejected before publication.
A failed refresh preserves previous complete snapshots. Current YTD falls back
to its most recent loaded day and is visibly stale; internal gaps block totals.
Rails responses cache for five minutes, keyed by metric/import version/date/year/
store. Opening pages never queries 1C or scans repair history.

## Collection and delivery

Requires the existing installed GET-only `1c-odata-agent` with protected `.env`.
It is imported, not modified or copied, and contains the 1C credentials.
The AIS token is read in memory by its existing `secure_env()` helper. Do not
commit secrets, environment files, generated snapshots, or credentials.

```
python3 script/analytics/receipt_counts.py --connector /path/to/1c-odata-agent \
  --output /persistent/private/receipt-counts --from 2020-01-01 --to 2025-12-31
python3 script/analytics/receipt_counts.py --connector /path/to/1c-odata-agent \
  --output /persistent/private/receipt-counts --from 2026-01-01
python3 script/analytics/deliver_receipt_counts.py --connector /path/to/1c-odata-agent report.json
```

The collector reads fresh metadata once, uses explicit scalar fields and filters,
100-row pages, interval splitting on truncation, one stream and 250ms pauses.
Snapshots are monthly and mode 600; completed months can be resumed. Duplicate
receipt GUIDs or incomplete source intervals abort publication. A full history
load is intentionally separate from web requests and can take significant time.

After deployment install the daily wrapper in the existing connector's persistent
code location and schedule it at 09:15 Asia/Vladivostok on its always-on host:

```
python3 script/analytics/refresh_receipt_counts.py --connector /path/to/1c-odata-agent \
  --output /persistent/private/receipt-counts
```

It rereads previous/current month and delivers all undelivered completed snapshots.
Reserve an off-hours monthly run with `--full` for older corrections. Do not run
full history on every daily refresh. Scheduler installation is a deployment step;
this change does not silently install launchd jobs on a developer machine.

Repair counts run daily at 08:45 in Sidekiq's `reports` queue, registered by the
initializer because production `schedule.yml` is a shared operator-managed file.
Monthly refresh rebuilds history; ordinary runs rebuild YTD. An interrupted historical load is detected by complete daily coverage and is rebuilt on the next ordinary run. Initial load:

```
RAILS_ENV=production bundle exec rake activity_counts:refresh_repairs
```

## Validation and release

Standalone calendar tests: `ruby test/activity_counts/period_counts_test.rb`.
Template and authorization checks: `bundle exec ruby test/activity_counts/view_test.rb`.
Database tests require an isolated local PostgreSQL on 127.0.0.1:55438 with the
`ais_test` role: `ACTIVITY_TEST_PORT=55438 bundle exec ruby test/activity_counts/import_test.rb`.
The latter only touches database `activity_counts_test`, never Rails DB config.

Before release: PR/review, current master, production ancestry, clean checkout,
Capistrano safety checks. After release: initial repair refresh, load/deliver history,
install collector schedule, verify complete coverage and exact totals/YoY; verify
superadmin access and denied roles, unchanged old imports, markup/iPhone/KPI/order
features and final production revision. No database reset/seeds and no force push.

## Local verification on 2026-09-24

Calendar: 11 tests / 56 assertions. Database/import/repair reconstruction: 7 tests /
29 assertions (including simultaneous import publication). Template/policy: 2 tests /
15 assertions; rendered in headless Chrome using synthetic data. Collector: 4 tests.
Migration applied on an isolated PostgreSQL loaded with the complete existing schema;
regenerated schema differs only by new tables, FK and schema version.

Full Rails test-environment boot is currently blocked before application initialization
by the existing chromedriver-helper 2.1.1 / Selenium API mismatch (`driver_path=`).
The isolated tests above use the project's locked ActiveRecord, ActionView and Hamlit.
Do not claim a full application regression suite has passed. Production acceptance,
initial complete source backfill and scheduler installation remain release steps.
