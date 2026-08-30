# Middleware migration after Bot API extension

After deployment of this read-only extension, itech-ai-platform should switch vocabulary
refresh to `GET /api/bot/v1/repair_catalog`, use `branch.repair_participating` as its branch
filter, and prefer `availability.business_status`. On selected options it may use
`customer_info` and the classified `special_marks`; unknown/internal notes remain hidden.
Then rerun catalog coverage, Golden/replay, live AIS tests and human scenarios. No client-facing
consumer should call these endpoints directly.
