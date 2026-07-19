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

- `getExpensesByCategory(account, movementType, startDate)` — sums amounts per category,
  normalizing each movement into a common currency before aggregating.
- `getExpensesByDay(account, movementType, startDate)` — sums amounts per calendar day.

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
  movements, and both charts.
- Charts render through the generic
  [easy_pie_chart.dart](../../lib/views/generics/easy_pie_chart.dart).

## Edge cases

- **Cross-currency aggregation** — amounts are converted to a common currency (the account's,
  or USD) before summing, so mixed-currency data aggregates sensibly
  ([movements.repository.dart:192-207](../../lib/repositories/movements.repository.dart#L192-L207)).
- **Period options** — category chart: `this-month` / `month` / `year` / all; day chart:
  `week` / `month` / `year` / all.
- **Accumulated mode** — recomputes the bar groups as a running sum and adjusts the Y range
  ([expenses_by_day.dart:69-126](../../lib/views/statistics/expenses_by_day.dart#L69-L126)).
- Charts render nothing (or an empty message) when there is no data for the selection.
