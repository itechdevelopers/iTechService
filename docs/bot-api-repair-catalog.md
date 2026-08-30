# Bot API repair catalog contract

All routes below require the existing `Authorization: Bearer ...` service token and are
read-only.

`GET /api/bot/v1/repair_catalog?department_id=&product_id=&model=&limit=100`
returns bounded RepairService objects. `department_id` is optional for vocabulary refresh;
when present the object includes branch, price and availability. The response includes only
official service/product names, plain-text `customer_info`, and `special_marks` as
`[{text, source: "repair_service"}]`. No quantity, store, purchase price, margin or internal
comments are returned.

`GET /api/bot/v1/repair_services/:id?department_id=` returns one selected service using the
same safe representation. Existing list/search fields remain backward compatible; their
availability object now has additive `business_status` alongside legacy `status`.

An explicit `product_id` on the detail route must be related to the selected RepairService;
otherwise the API returns `NOT_FOUND` and never silently substitutes another product.

`GET /api/bot/v1/repair_branches` returns active real departments with only `id`, `name`,
`city` and `repair_participating`. The endpoint uses the authoritative
`Department.real.participating_in_repair_services` scope. `Department.main_branches` has a
different customer assignment meaning and must not be used for repair bot filtering. Repair
price/search routes use the same centralized participation scope.

Business status is derived from the existing AIS `RepairService#remnants_s` method: `many` →
`sufficient`, `low` → `low_requires_confirmation`, `none` → `unavailable`; missing store or
ambiguous data remains `unknown`, and services without spare parts are `not_required`.
Department participation comes from `Department#participates_in_repair_services?`.

The catalog query uses the authoritative `Product.devices` scope
(`ProductCategory.kind = equipment`) and a generic parsed model boundary, so `iPhone 11`
excludes Pro/Pro Max while storage, colour and SIM suffixes remain applicable variants. The
ambiguous `RepairService#products` relation is not exposed as a device list; responses use
compact `applicable_devices` metadata only for products classified by that scope.
