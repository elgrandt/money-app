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
  `https://api.bluelytics.com.ar/v2/latest` and derives ARS↔USD and ARS↔EUR from the blue
  rates ([:79-103](../../lib/services/utils.service.dart#L79-L103)).
- Rates are persisted in a single-row `currency_rates` table
  ([currency_rates.repository.dart](../../lib/repositories/currency_rates.repository.dart)): the
  raw source values (`usdToArs`, `eurToArs`, `eurToUsd`) plus `updatedAt`. On a successful fetch
  the row is upserted via `saveLatest`; on startup `loadCachedMappings()` reads it and re-derives
  the pairwise multipliers, so conversions are correct offline and across restarts.
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

## Edge cases / debt

- **EUR↔USD is hardcoded** at `1.11` because no EUR→USD source was wired up; see the entry in
  [tech-debt.md](../tech-debt.md).
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
- If a mapping for a pair is missing, `convertCurrencies` returns the amount unchanged.
