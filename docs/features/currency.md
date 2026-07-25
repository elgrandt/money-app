# Currency (cross-cutting)

## What it does

The app is multi-currency: accounts hold ARS, USD, or EUR, and any total or aggregate can be
displayed in a chosen currency. Conversion uses live Argentine "blue" rates fetched from the
bluelytics API, refreshed at most hourly. This behavior cuts across accounts, movements,
statistics, and the dashboard.

## Mechanics

All currency logic lives in `UtilsService` —
[utils.service.dart](../../lib/services/utils.service.dart):

- `Currency` enum (`ARS`, `USD`, `EUR`) is defined in
  [account.model.dart](../../lib/models/account.model.dart).
- `currencyMappings` — the current pairwise multipliers; seeded to `1` and replaced with live
  rates.
- `updateCurrencyMappings()` — throttled to once per hour; fetches
  `https://api.bluelytics.com.ar/v2/latest` and reads `blue.value_buy`/`blue.value_sell` and
  `blue_euro.value_buy`/`blue_euro.value_sell`, then hands the four values to `applyRates`.
- `applyRates({ usdBuy, usdSell, eurBuy, eurSell })` — builds the six pairwise multipliers
  direction-based: ARS→foreign uses `1/…Sell` (you sell ARS at the sell rate to acquire the
  foreign currency), foreign→ARS uses `…Buy`, and USD↔EUR is derived through ARS
  (`usdBuy/eurSell` for USD→EUR, `eurBuy/usdSell` for EUR→USD).
- Rates are persisted in the `currency_rates` table
  ([currency_rates.repository.dart](../../lib/repositories/currency_rates.repository.dart)): the
  raw source values (`usdBuy`, `usdSell`, `eurBuy`, `eurSell`) plus `createdAt` and `updatedAt`.
  This is an **append-on-change history** table: `record` compares the fetched values against
  `findLatest` and only inserts a new row when one of the four rates changed; otherwise it just
  bumps `updatedAt` on the existing latest row (dedup-on-change). So each row marks the moment a
  rate changed (`createdAt`) and when it was last seen unchanged (`updatedAt`). `findLatest` orders
  by `createdAt DESC` (not by `id`), so rows inserted out of chronological order — e.g. the
  historical rows seeded by the `backfill_currency_rates_history` migration — never shadow the
  current rate.
- On startup `loadCachedMappings()` reads `findLatest` and re-derives the current pairwise
  multipliers (via `buildMappings`), so live conversions are correct offline and across restarts.
  It also calls `loadRateHistory()`, which loads the full history (`findAllSorted`, ascending by
  `createdAt`) into the in-memory `rateHistory` list; the history is refreshed after every
  successful fetch.
- `convertCurrencies(amount, from, to)` — returns `amount` when `from == to`, otherwise applies
  the current (live) mapping ([:120-129](../../lib/services/utils.service.dart#L120-L129)). Used
  for balances and totals, which are always valued at today's rates. The new/edit movement dialog
  also uses it to choose the conversion-rate input direction: when
  `convertCurrencies(1, source, target) < 1` the target currency is stronger, so the rate is
  entered inverted as `1 ÷ X` (see [movements.md](movements.md)).
- `convertCurrenciesAt(amount, from, to, date)` — the **historical** conversion. Resolves the
  rates row applicable at `date` from `rateHistory` (the latest row whose `createdAt <= date`;
  if `date` predates all history, the earliest row; if the history is empty, defaults to 1:1 and
  returns the amount unchanged), builds that row's mappings, and applies the pairwise multiplier
  ([:131-155](../../lib/services/utils.service.dart#L131-L155)). Used wherever a *past* movement's
  amount is displayed or aggregated (movements list, statistics), so it is valued at the rate that
  was in effect on its `creationDate` rather than today's.
- `buildMappings({ usdBuy, usdSell, eurBuy, eurSell })` — derives the six pairwise multipliers
  from a set of raw rates; shared by `applyRates` (live) and `convertCurrenciesAt` (historical).
- `beautifyCurrency(number, currency)` — locale-aware (`es_AR`) formatting with the currency
  symbol; used everywhere money is displayed.
- `getCurrencyIcon` / `getCurrencySymbol` / `currencyConfigs` — per-currency icon and symbol.

Currencies are stored on `Account` as `TEXT` via `Currency.name` (see
[data-layer.md](../data-layer.md)).

## Views involved

- [currency_selector.dart](../../lib/views/generics/currency_selector.dart) — the generic
  currency picker (a `ButtonSelector` of currency icon + name), used to choose the display
  currency on the home tabs, statistics, and the new-account dialog.
- [exchange_rates.dart](../../lib/views/home/exchange_rates.dart) — the dashboard's "Tasas de
  cambio" table: a row per currency with **Compra** (`value_buy`) and **Venta** (`value_sell`)
  columns under a header row, read straight from `currencyRatesRepository.findLatest` (each cell
  falls back to `—` before the first cached row exists), plus the last-update timestamp (shows
  `Nunca` when no row exists yet). Refreshes on the repository's `change` event.

## Edge cases / debt

- **USD↔EUR is derived through ARS** from the blue rates (`usdBuy/eurSell` for USD→EUR,
  `eurBuy/usdSell` for EUR→USD) rather than from a dedicated EUR/USD source.
- `updateCurrencyMappings` swallows network/parse errors (logs them) and advances its hourly
  throttle on every attempt — before the request — so a failing endpoint is retried at most once
  per hour instead of on every call. This matters because `convertCurrencies` fires it unawaited
  on every conversion; advancing the throttle up front both rate-limits the retries and prevents a
  stampede of concurrent requests on first render. The unawaited call is intentional background
  refresh and is safe offline.
- Home renders from cached (or seed) mappings immediately and refreshes in the background, so an
  offline launch never blocks on the network.
- **First-ever launch while offline** (no cached row): mappings stay at the `1` seed until the
  first online launch, so cross-currency amounts show 1:1 until then.
- **First launch after the `rebuild_currency_rates_buy_sell` migration** (which drops the cached
  row): `loadCachedMappings()` finds no row, so mappings start at the `1` seed. The dashboard
  renders before the background fetch lands, and views computed once at first render (e.g. the
  expenses-by-category chart, which doesn't listen for rate changes) show ARS amounts unconverted
  for that session. Self-corrects on the next launch, once the fetched row is cached — accepted as
  a one-time upgrade quirk.
- If a mapping for a pair is missing, `convertCurrencies` returns the amount unchanged.
- **Historical conversion before any history exists** — if `rateHistory` is empty (e.g. a
  fresh install that has never fetched, or an offline first launch), `convertCurrenciesAt`
  falls back to 1:1 and returns the amount unchanged, just like the live `1` seed. Once the
  first row is recorded it self-corrects.
- **Movements older than the first recorded rate** — `convertCurrenciesAt` clamps to the
  earliest history row, so pre-history movements are valued at the oldest known rate rather
  than 1:1.
- **Backfilled history** — on existing databases the `backfill_currency_rates_history` migration
  seeds `currency_rates` with real past blue rates (merged from CSVs, deduplicated on change) for
  the span from the earliest movement up to the first recorded rate — or, when no rate has been
  recorded yet, up to the last rate in the embedded series — so old movements convert at their
  date's actual rate. Movements predating the CSV coverage (before 25/07/2023) still clamp to the
  earliest seeded row (see [migrations.md](../migrations.md)).
