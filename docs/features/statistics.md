# Statistics

## What it does

Three chart views summarize movements, filterable by account, movement type, and time period:

- **Expenses by category** — a pie chart plus a table; the table cell toggles between currency
  amounts and percentages.
- **Expenses by day** — a bar chart over a day range, with an optional accumulated mode.
- **Historical expenses by category** — a daily line chart with one line per category, currency
  and period selectors (`3 meses` / `6 meses` / `1 año` / `Custom`), and a category list that
  enables/disables each line. Expenses only.

The same charts appear on the home **dashboard**, alongside the total-patrimony figure and a
per-account totals pie.

## Key repository methods

`MovementsRepository` — [movements.repository.dart:186-274](../../lib/repositories/movements.repository.dart#L186-L274):

- `getExpensesByCategory(account, movementType, startDate, endDate, displayCurrency)` — sums
  amounts per category, converting each movement into `displayCurrency` before aggregating.
- `getExpensesByDay(account, movementType, startDate, displayCurrency)` — sums amounts per
  calendar day, converting each movement into `displayCurrency` before aggregating.
- `getExpensesByCategoryByDay(account, startDate, endDate, displayCurrency)` — expenses
  (`REMOVE`) grouped first by category and then by local calendar day; returns
  a `CategoryDailyExpenses` (`category`, `dailyTotals`, `total`) per category with a fixed-length list (one entry per day from
  `startDate` to `endDate`, zeros on days without spending). The upper bound is exclusive on the
  next midnight and the dates are bound with `toIso8601String()` to match the stored format.

`getExpensesByDay` filtra por tipo, opcionalmente por cuenta y opcionalmente desde una fecha de
inicio; `getExpensesByCategory` además acepta una fecha de fin (`endDate`) para acotar el rango
por arriba.

## Views involved

- [statistics.dart](../../lib/views/statistics/statistics.dart) — the `/statistics` screen;
  account selector + chart-type selector, then renders the chosen chart.
- [expenses_by_category.dart](../../lib/views/statistics/expenses_by_category.dart) — pie +
  table; type and period selectors; the table supports a currency/percent view-mode toggle. El
  nombre de cada categoría es tocable y abre `CategoryMovementsDialog`
  ([movements.md](movements.md)) con el rango del período (`selectedPeriodStartDate` / `selectedPeriodEndDate`; sin fin usa
  `DateTime.now()`, sin inicio usa la época), el tipo y la cuenta seleccionados.
- [expenses_by_day.dart](../../lib/views/statistics/expenses_by_day.dart) — `fl_chart` bar
  chart; type and period selectors and an accumulated switch; builds bar groups and axis
  titles in `doCalculations`.
- [historical_expenses_by_category.dart](../../lib/views/statistics/historical_expenses_by_category.dart) —
  `fl_chart` line chart; `CurrencySelector` + period selector (`Custom` abre
  `DateRangeSelectorDialog`). Tocar o arrastrar sobre el gráfico marca un día con una línea
  vertical (sin tooltip) y la lista de categorías muestra el monto de ese día; tocar una
  categoría la habilita/deshabilita (tachada cuando está deshabilitada), con botones
  `Habilitar todas` / `Deshabilitar todas`.
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
  ([movements.repository.dart:202-214](../../lib/repositories/movements.repository.dart#L202-L214)).
- **Currency toggle re-queries** — the expenses-by-category table's currency/percent toggle
  re-runs `getExpensesByCategory` with the new `displayCurrency` (each movement re-converted at
  its own date) rather than re-converting the already-aggregated totals
  ([expenses_by_category.dart:50-65,171-178](../../lib/views/statistics/expenses_by_category.dart#L50-L65)).
- **Category chart movement types** — the category chart offers only income (`ADD`) and
  expense (`REMOVE`); transfers are excluded because a per-category transfer total is not
  meaningful. The day chart still offers all three types.
- **Period options** — category chart: `this-month` / `last-month` / `month` / `custom` (el
  botón `custom` abre `DateRangeSelectorDialog` y guarda el rango elegido en `customRange`); day
  chart: `week` / `month` / `year` / all.
- **Accumulated mode** — recomputes the bar groups as a running sum and adjusts the Y range
  ([expenses_by_day.dart:69-126](../../lib/views/statistics/expenses_by_day.dart#L69-L126)).
- **Historical chart day granularity** — data is daily; the X axis only labels the first day of
  each month (`MM/yy`). A movement belongs to its *local* calendar day (no `toUtc()`);
  `UtilsService.dayIndex` counts days through UTC dates so a DST change cannot shift the index.
- **Historical chart period options** — `3 meses` / `6 meses` / `1 año` / `Custom`, always ending
  today (or the custom range's end).
- **Historical chart colors and selection** — colors use `Random(134)` over categories sorted by
  period total (same algorithm as the category table) and do not change when categories are
  toggled. `disabledCategories` and the period survive currency/period/account changes; changing
  the account resets only the currency to the account's. All categories start enabled.
- **Date filter format mismatch (existing)** — `getExpensesByCategory` / `getExpensesByDay` bind
  `toString()` dates against `toIso8601String()` data, excluding movements on the end date; see
  [tech-debt.md](../tech-debt.md). The historical query avoids it.
- Charts render nothing (or an empty message) when there is no data for the selection.
