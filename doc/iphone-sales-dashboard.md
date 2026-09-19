# iPhone Dashboard

Square tile inside `/weekly_markup_dashboard`, drilldown `/weekly_markup_dashboard/iphone_sales` (year, warehouse_id). Existing superadmin role required on every page action; existing protected Bearer token for POST `/api/iphone_sales_imports`.

Immutable `iphone_sales_imports` versions; SHA256 delivery_id unique, schema ice-iphone-sales-1.0, methodology iphone-sales-1.0. Signed integer quantities, contiguous complete dates and branch/day/report sums validated. Latest successful version per day wins, failed refresh preserves previous data and displays warning.

Forecast: current YTD / median historical share by same month/day in last three complete years (minimum two). Scenario range uses min/max historical shares, not a confidence interval. Remaining months use historical seasonality. Actual and forecast shown separately; partial periods marked. Backtest at 2025-09-13: 6677 vs full-year 6625 (+0.78%).

Manual checks: superadmin can open tile, drilldown and year/branch selection. Other roles denied. Re-deliver same JSON => duplicate; wrong sums rejected. A failed refresh must preserve prior quantities. Full daily CLI/method/schedule docs: connector README_IPHONE_SALES.md.
