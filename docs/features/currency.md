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
- Rates are persisted in a single-row `currency_rates` table
  ([currency_rates.repository.dart](../../lib/repositories/currency_rates.repository.dart)): the
  raw source values (`usdBuy`, `usdSell`, `eurBuy`, `eurSell`) plus `updatedAt`. On a successful
  fetch the row is upserted via `saveLatest`; on startup `loadCachedMappings()` reads it and
  re-derives the pairwise multipliers, so conversions are correct offline and across restarts.
- `convertCurrencies(amount, from, to)` — returns `amount` when `from == to`, otherwise applies
  the mapping ([:105-114](../../lib/services/utils.service.dart#L105-L114)).
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
