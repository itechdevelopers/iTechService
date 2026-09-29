# Restore iPhone 14 1 SIM selection

## Review and deployment gate

Work starts on a feature branch from current `origin/master`. Open a PR into
`master` and wait for the developer's review. Address comments and obtain approval
before merging, deploying, or applying the catalog operation below. The operation
is deliberately not a migration, initializer, or request-side repair.

## Diagnosis (read-only production check, 2026-09-29)

* iPhone 14 (equipment group 470): only eSIM is offered. There are 24 legacy
  products without a SIM option and 18 explicit eSIM products. No explicit
  1 SIM products exist.
* iPhone 14 Pro (472) and Pro Max (473): 1 SIM, 2 SIM and eSIM group links remain.
  Each has 16 explicit products for each SIM variant. All 64 existing physical
  SIM combinations resolve through `Product.find_by_group_and_options`.
* The earlier September batch covered Pro/Pro Max, not the regular iPhone 14.
  This check does not establish that a deployment deleted catalog records.

The selection UI reads the group's `option_values`, while product lookup needs
a product with the selected option IDs. Adding only the dropdown option is not
sufficient. This task restores both through existing ActiveRecord associations
and `Product.create!`, including its barcode and repair-service callbacks.

## Commands (after approved merge and deployment)

Use the existing deployment environment loader; do not put secrets in commands.

```sh
RAILS_ENV=production bundle exec rake catalog:restore_iphone14_one_sim
RAILS_ENV=production APPLY=1 bundle exec rake catalog:restore_iphone14_one_sim
RAILS_ENV=production bundle exec rake catalog:restore_iphone14_one_sim
```

The first and last commands only read and report. Before applying, retain the
preview output and take the usual database backup. Stop if the preview differs
unexpectedly from the reviewed plan.

The read-only preview on 2026-09-29 proposes 18 new regular iPhone 14 products:
128GB/256GB/512GB × Blue/Purple/RED/Starlight/Midnight/Yellow, all 1 SIM, plus one
group option link. Pro and Pro Max each reuse 16 products without changes.
New articles are empty; internal codes are unique eight-digit numeric strings.
Existing IDs, articles, names, options and repair associations are not rewritten.
Unknown capacity `?` remains outside this operation, consistent with the earlier
physical-SIM batch; no new configuration is inferred from it.

Apply is transactional and locks each group; repeated runs reuse exact
combinations. Duplicate or archived target combinations and hidden base options
abort the operation rather than guessing. Only equipment groups with the exact
three names are eligible; similarly named spare-part groups are not touched.

After apply, preview must report no creations or group link additions. Verify
the 18 new combinations in `/products` and representative 1 SIM selections in
`/service_jobs/new` (IMEI/serial fields), alongside existing Pro/Pro Max 2 SIM
and eSIM options. Do not save a test service job. No production apply, merge or
deployment has been performed as part of PR preparation.

## Tests

```sh
RAILS_ENV=test bundle exec rspec spec/services/catalog/restore_iphone14_one_sim_spec.rb
```

Tests cover preview, idempotence, preservation of originals, explicit-variant
reuse, spare-part isolation, unknown capacity, and transaction rollback on
conflicts. Use a dedicated empty test database, not production.
