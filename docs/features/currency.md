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
  rates ([:53-76](../../lib/services/utils.service.dart#L53-L76)).
- `convertCurrencies(amount, from, to)` — returns `amount` when `from == to`, otherwise applies
  the mapping ([:78-87](../../lib/services/utils.service.dart#L78-L87)).
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
- `updateCurrencyMappings` is fire-and-forget in a few call sites; if it hasn't completed,
  conversions fall back to the last known (or seed) multipliers.
- If a mapping for a pair is missing, `convertCurrencies` returns the amount unchanged.
