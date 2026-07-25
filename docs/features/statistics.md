# Statistics

## What it does

Two chart views summarize movements, filterable by account, movement type, and time period:

- **Expenses by category** — a pie chart plus a table; the table cell toggles between currency
  amounts and percentages.
- **Expenses by day** — a bar chart over a day range, with an optional accumulated mode.

The same charts appear on the home **dashboard**, alongside the total-patrimony figure and a
per-account totals pie.

## Key repository methods

`MovementsRepository` — [movements.repository.dart:179-239](../../lib/repositories/movements.repository.dart#L179-L239):

- `getExpensesByCategory(account, movementType, startDate, displayCurrency)` — sums amounts per
  category, converting each movement into `displayCurrency` before aggregating.
- `getExpensesByDay(account, movementType, startDate, displayCurrency)` — sums amounts per
  calendar day, converting each movement into `displayCurrency` before aggregating.

Both filter by type, optionally by account, and optionally from a start date.

## Views involved

- [statistics.dart](../../lib/views/statistics/statistics.dart) — the `/statistics` screen;
  account selector + chart-type selector, then renders the chosen chart.
- [expenses_by_category.dart](../../lib/views/statistics/expenses_by_category.dart) — pie +
  table; type and period selectors; the table supports a currency/percent view-mode toggle.
- [expenses_by_day.dart](../../lib/views/statistics/expenses_by_day.dart) — `fl_chart` bar
  chart; type and period selectors and an accumulated switch; builds bar groups and axis
  titles in `doCalculations`.
- [all_expenses.dart](../../lib/views/statistics/all_expenses.dart) — the dashboard's "latest
  movements" section (a filtered `MovementsList`).
- [dashboard.dart](../../lib/views/home/dashboard.dart) — composes total, totals pie, latest
  movements, both charts, and the "Tasas de cambio" table (between the category and day charts).
- Charts render through the generic
  [easy_pie_chart.dart](../../lib/views/generics/easy_pie_chart.dart).

## Edge cases

- **Cross-currency aggregation** — each movement is converted into the chosen `displayCurrency`
  (the selected account's, or USD when no account is selected) before summing, so mixed-currency
  data aggregates sensibly. The conversion is **date-based**: `convertCurrenciesAt` values each
  movement at the rate that was in effect on its own `creationDate` (see
  [currency.md](currency.md)), not at today's rate
  ([movements.repository.dart:193-205](../../lib/repositories/movements.repository.dart#L193-L205)).
- **Currency toggle re-queries** — the expenses-by-category table's currency/percent toggle
  re-runs `getExpensesByCategory` with the new `displayCurrency` (each movement re-converted at
  its own date) rather than re-converting the already-aggregated totals
  ([expenses_by_category.dart:50-65,171-178](../../lib/views/statistics/expenses_by_category.dart#L50-L65)).
- **Category chart movement types** — the category chart offers only income (`ADD`) and
  expense (`REMOVE`); transfers are excluded because a per-category transfer total is not
  meaningful. The day chart still offers all three types.
- **Period options** — category chart: `this-month` / `month` / `year` / all; day chart:
  `week` / `month` / `year` / all.
- **Accumulated mode** — recomputes the bar groups as a running sum and adjusts the Y range
  ([expenses_by_day.dart:69-126](../../lib/views/statistics/expenses_by_day.dart#L69-L126)).
- Charts render nothing (or an empty message) when there is no data for the selection.
