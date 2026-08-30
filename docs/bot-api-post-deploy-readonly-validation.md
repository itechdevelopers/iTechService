# Bot API post-deploy read-only validation

These checks are intended for execution immediately after deployment. They perform only
`GET` requests. The bearer token is read from the shell environment and is never printed.

```bash
set -euo pipefail
: "${AIS_BASE_URL:?set AIS_BASE_URL, for example https://ise.itech.pw}"
: "${AIS_BOT_API_TOKEN:?set AIS_BOT_API_TOKEN in the protected shell environment}"
AUTH=(-H "Authorization: Bearer ${AIS_BOT_API_TOKEN}" -H 'Accept: application/json')
BASE="${AIS_BASE_URL%/}"
```

## Smoke checks

Unauthenticated access must be rejected (the response body is not printed):

```bash
test "$(curl -sS -o /dev/null -w '%{http_code}' "$BASE/api/bot/v1/repair_branches")" = 401
```

The new branch endpoint must return only safe metadata. The assertions fail if a forbidden
inventory or secret field appears:

```bash
BRANCHES="$(curl -fsS "${AUTH[@]}" "$BASE/api/bot/v1/repair_branches")"
echo "$BRANCHES" | jq -e '.success == true and (.items | type == "array")' >/dev/null
echo "$BRANCHES" | jq -e '.. | objects | keys_unsorted | all(. != "quantity" and . != "purchase_price" and . != "margin" and . != "supplier" and . != "password" and . != "serial" and . != "imei")' >/dev/null
echo "$BRANCHES" | jq -e '.items | all(has("id") and has("name") and has("city") and has("repair_participating"))' >/dev/null
```

## Catalog checks

The bounded catalog must be active-only and contain the new safe fields:

```bash
CATALOG="$(curl -fsS "${AUTH[@]}" "$BASE/api/bot/v1/repair_catalog?model=iPhone%2011&department_id=2&limit=100")"
echo "$CATALOG" | jq -e '.success == true and (.items | type == "array")' >/dev/null
echo "$CATALOG" | jq -e '.items | all(.active == true)' >/dev/null
echo "$CATALOG" | jq -e '.. | objects | keys_unsorted | all(. != "quantity" and . != "purchase_price" and . != "margin" and . != "supplier" and . != "employee_comments")' >/dev/null
echo "$CATALOG" | jq -e '.items | all(has("customer_info") and has("special_marks") and has("availability"))' >/dev/null

# Keep output to counts/statuses only; do not print the payload.
echo "$CATALOG" | jq '{items: (.items|length), business_statuses: ([.items[].availability.business_status] | unique)}'
```

Select a service/product pair from the already fetched response and validate the detail route.
Only numeric identifiers are printed by this local shell variable; the command output itself is
limited to status and field-presence summaries:

```bash
SERVICE_ID="$(echo "$CATALOG" | jq -r '.items[0].id // empty')"
PRODUCT_ID="$(echo "$CATALOG" | jq -r '.items[0].products[0].id // empty')"
test -n "$SERVICE_ID"
DETAIL_URL="$BASE/api/bot/v1/repair_services/$SERVICE_ID?department_id=2"
DETAIL="$(curl -fsS "${AUTH[@]}" "$DETAIL_URL")"
echo "$DETAIL" | jq -e '.success == true and (.data.id == ('"$SERVICE_ID"'))' >/dev/null
echo "$DETAIL" | jq -e '.. | objects | keys_unsorted | all(. != "quantity" and . != "purchase_price" and . != "margin" and . != "supplier" and . != "password" and . != "serial" and . != "imei")' >/dev/null

if [ -n "$PRODUCT_ID" ]; then
  # An unrelated product must not silently fall back to the first relation.
  test "$(curl -sS -o /dev/null -w '%{http_code}' "${AUTH[@]}" "$BASE/api/bot/v1/repair_services/$SERVICE_ID?department_id=2&product_id=999999999")" = 404
fi
```

## Backward compatibility checks

Existing GET list/search routes must still succeed and retain legacy `availability.status`,
while exposing additive `business_status`:

```bash
for URL in \
  "$BASE/api/bot/v1/repair_services?department_id=2&model=iPhone%2011&limit=1" \
  "$BASE/api/bot/v1/repair_services/search?department_id=2&model=iPhone%2011&service=%D0%B1%D0%B0%D1%82%D0%B0%D1%80&limit=1"; do
  BODY="$(curl -fsS "${AUTH[@]}" "$URL")"
  echo "$BODY" | jq -e '.success == true and (.items | type == "array")' >/dev/null
  echo "$BODY" | jq -e '.items | all(has("availability") and (.availability | has("status") and has("business_status")))' >/dev/null
done
```

## Read-only availability spot checks

For a known service in each participating department, inspect only normalized statuses:

```bash
for DEPARTMENT in 2 3 9; do
  BODY="$(curl -fsS "${AUTH[@]}" "$BASE/api/bot/v1/repair_services?department_id=$DEPARTMENT&model=iPhone%2011&limit=1")"
  echo "$BODY" | jq --arg d "$DEPARTMENT" '{department:$d, statuses: ([.items[].availability | {status,business_status}] | unique)}'
done
```

Do not assert permanent prices or stock values in deployment automation. Compare statuses and
prices to the current AIS response during the release window; if an expected service is absent,
stop and investigate.

## Deployment sequence (proposal only)

1. Review `git show --stat` and confirm the release contains only the Bot API extension. Verify
   no migration is present and production environment/token values are unchanged.
2. Deploy the reviewed commit `5fa213ffb` (or the subsequent reviewed correction commit) using
   the existing release mechanism. Do not run database migrations; this change has none.
3. Run the smoke, catalog, detail, backward-compatibility and status checks above from a
   protected operator shell. Save only pass/fail summaries and HTTP codes.
4. Run itech-ai-platform middleware verification against the deployed read-only endpoints:
   catalog refresh, branch participation filtering, one selected-service detail lookup and
   existing live AIS tests. Do not send client messages or perform writes.
5. If every check passes, mark the release ready for review. No production data is modified by
   this API.

## Rollback plan

If any check fails, stop rollout and keep the previous release serving traffic. Redeploy the
last known-good application release (or revert the extension commit and deploy that revert)
through the normal release mechanism. Do not run migrations or issue SQL/data changes: the
extension is schema-free. Re-run the unauthenticated/authenticated smoke checks and verify the
legacy list/search/status GET endpoints. Then inspect logs using request IDs without exposing
Authorization headers or response bodies.
