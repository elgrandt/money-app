# Dashboard "Tasas de cambio" section — design

## Goal

Add a new section to the home dashboard, between **"Movimientos por categoría"** and
**"Movimientos por día"**, titled **"Tasas de cambio"**. It shows the current exchange rates of
USD and EUR against the Argentine peso as a small table, plus the timestamp of the last rate
update:

```text
                Tasas de cambio

   [icon] USD                        $1.400
   [icon] EUR                        $1.100

   Última actualización: 20/07/2026 14:30
```

## Scope

Pure view work. **No** model, repository, migration, or DB schema change — it reuses existing
data (`UtilsService` currency mappings and the `currency_rates` row).

## Behavior

- The section **always renders** — there is no hidden/empty state. Rate values always resolve to
  at least the seed (`1`), so the table is never blank.
- **Rate values** reflect the *currently active* rates (seed `1`, cached, or live), read through
  `UtilsService.convertCurrencies`:
  - USD row: `convertCurrencies(1, Currency.USD, Currency.ARS)`
  - EUR row: `convertCurrencies(1, Currency.EUR, Currency.ARS)`
  - Formatted with `beautifyCurrency(rate, Currency.ARS)` → `es_AR`, 0 decimals, e.g. `$1.400`.
  - As everywhere else, `convertCurrencies` also fires the throttled background rate refresh.
- **Última actualización** reads `currencyRatesRepository.findLatest()?.updatedAt`:
  - When present: formatted `dd/MM/yyyy HH:mm` via `intl`'s `DateFormat` (e.g. `20/07/2026 14:30`).
  - When the row does not exist yet (first-ever launch while offline, table empty): literal
    **`Nunca`**.

## Components

### New: `lib/views/home/exchange_rates.dart` — `ExchangeRatesTable`

A `StatefulWidget`, because it loads the timestamp asynchronously and subscribes to repository
change events. Follows the established view lifecycle
([movements_list.dart:65-71](../../../lib/views/home/movements_list.dart#L65-L71)):

- Fields: `utilsService`, `databaseService`, `logger` from `GetIt`; `CurrencyRates? latestRates`
  (nullable — null both before the async load completes and when no row exists) and a
  `bool loaded` flag to distinguish "still loading" from "loaded, no row".
- `initState()` → kick off `loadLatestRates()` and `watchRatesChanges()`.
- `watchRatesChanges()` → `await databaseService.initialized`, then subscribe to
  `databaseService.currencyRatesRepository.events.on<TableUpdateEvent<CurrencyRates>>('change', …)`
  and call `loadLatestRates()` on each event. `saveLatest` emits this event **after**
  `applyRates` has already updated the in-memory mappings, so a single event refreshes both the
  timestamp and the (re-read) rate values.
- `loadLatestRates()` → `await databaseService.initialized`, `findLatest()`, then `mounted`
  guard + `setState` (set `latestRates` and `loaded = true`).
- `dispose()` → cancel the subscription.
- `build()` → a `Table` with two currency rows (icon + name on the left, ARS amount on the
  right) styled like the category table
  ([expenses_by_category.dart:134-182](../../../lib/views/statistics/expenses_by_category.dart#L134-L182)),
  followed by the "Última actualización: …" line (smaller, subdued text).

The two parts of `build()` have different sources and timing:

- **Amount rows** are read live in `build()` via `convertCurrencies` from the in-memory
  mappings, so they render immediately on first frame (seed, cached, or live) and never wait on
  the async load.
- **Timestamp line** derives from `loaded` + `latestRates`:
  - `loaded == false` (async load in flight) → placeholder `—`.
  - `loaded == true && latestRates == null` (no row yet) → `Nunca`.
  - `loaded == true && latestRates != null` → `DateFormat('dd/MM/yyyy HH:mm')` of `updatedAt`.

### Changed: `lib/views/home/dashboard.dart`

- Add `buildExchangeRates(BuildContext context)` returning a `Column` with the bold 20px title
  `"Tasas de cambio"` (matching the other section titles) + a `SizedBox(height: 20)` + the
  `ExchangeRatesTable`, keyed `Key('exchange-rates')`.
- Insert it in `build()` between the category and day sections, with the same
  `SizedBox(height:15)` + `Divider` + `SizedBox(height:15)` spacing used between the existing
  sections.

## Rendering detail

- Row currency cell: `utilsService.getCurrencyIcon(currency)` + `Text(name)` (bold, 18px) — same
  visual weight as the category table rows.
- Amount cell: `Text(beautifyCurrency(rate, Currency.ARS))` (bold, 18px, right-aligned).
- Only **USD** and **EUR** rows (ARS→ARS would be `$1`, not meaningful for a "rates vs peso"
  table).
- The "Última actualización" line: normal weight, smaller font, centered, subdued color.

## Docs to update (same change — docs-maintenance rule)

- [docs/features/currency.md](../../features/currency.md) — add `exchange_rates.dart` under
  "Views involved".
- [docs/features/statistics.md](../../features/statistics.md) — note the new "Tasas de cambio"
  dashboard section in the dashboard composition description.

## Out of scope / non-goals

- No display-currency selector (rates are always shown against ARS).
- No manual "refresh now" button (refresh stays automatic/throttled via `convertCurrencies`).
- No EUR↔USD display (the existing hardcoded `1.11` debt is untouched and unrelated).
