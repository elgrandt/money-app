# Design: Historical exchange rates for movements

**Date:** 2026-07-25
**Status:** Approved (pending spec review)
**Branch:** `feature/movement-historical-rates`

## Problem

Every cross-currency figure in the app is computed with a single **global live rate**
(`UtilsService.currencyMappings`, derived from the latest bluelytics "blue" rate and cached in a
one-row `currency_rates` table). Conversions are therefore not temporal: a movement created two
years ago is displayed/aggregated at *today's* rate, which misrepresents what it was worth when it
happened.

**Goal:** value each movement at the exchange rate in effect **when it was created**, and use that
rate wherever the movement is shown or aggregated in another currency. Backfilling old movements
with the current rate is acceptable.

## Scope

Historical rates apply to **movement-level conversions only**:

- Movements list (`movements_list.dart`)
- Statistics aggregations — expenses by category and by day (`movements.repository.dart`)

**Out of scope (keep the live rate):** total patrimony and the per-account totals pie
(`total_viewer.dart`, `dashboard.dart`). These convert *current account balances*, which are
"as of now" figures with no single creation date, so the live rate is the correct choice.
`movement_details.dialog.dart` displays amounts in the movements' native account currencies (no FX
conversion) and is unaffected.

## Approach: date-based lookup against a rate history (no per-movement FK)

Rather than storing a rate snapshot (or a foreign key) on each movement, a movement's rate is
**derived** from its `creationDate` against a historical rate table. This was chosen over a
per-movement FK/snapshot because:

- No change to the `movements` table or `Movement` model.
- Nothing to set on `create`; editing a movement's date automatically re-values it correctly.
- The rate table stays compact via dedup-on-change (see below).

Trade-off accepted: conversions are derived, not frozen per movement — extending or correcting the
history retroactively shifts past display values. This is fine for a single-user personal-finance
app and is precisely what makes date edits "just work."

## Data model & schema

`currency_rates` becomes an **append-on-change history table**:

- Add a `createdAt` DATE column: when this distinct set of four rates first appeared.
- Keep `updatedAt`: the last time the same four rates were observed still in effect (also drives the
  dashboard "última actualización" text).
- Row semantics: *these four rates held from `createdAt` until the next row's `createdAt`.*

Add `createdAt` to:

- `CurrencyRatesRepository.currencyRatesColumns` (fresh-DB definition).
- The `CurrencyRates` model (`createdAt` field, constructor, `toString`).

**No change** to the `movements` table or the `Movement` model.

## Recording rates (dedup-on-change)

Replace `CurrencyRatesRepository.saveLatest` (single-row upsert) with `record(CurrencyRates rates)`:

1. Load the latest row (`findLatest`).
2. If it exists **and all four values (`usdBuy`, `usdSell`, `eurBuy`, `eurSell`) are equal** → update
   its `updatedAt = now`.
3. Otherwise → **insert** a new row with `createdAt = now`, `updatedAt = now`.

A new row is created only when a value actually changes, keeping the table small. `findLatest()` is
unchanged, so `exchange_rates.dart` and `loadCachedMappings()` keep working as-is.

## Conversion layer (`UtilsService`)

- Extract a pure builder from the current `applyRates` body:
  `List<CurrencyMapping> buildMappings({required double usdBuy, required double usdSell, required
  double eurBuy, required double eurSell})`. `applyRates` becomes
  `currencyMappings = buildMappings(...)`.
- Keep `currencyMappings` + `convertCurrencies(amount, from, to)` as the **live** path (balances /
  totals) — behavior unchanged, still fires the throttled `updateCurrencyMappings()`.
- Add an in-memory `List<CurrencyRates> rateHistory`, sorted by `createdAt` ascending. Loaded in
  `loadCachedMappings()` and refreshed after each `record(...)`.
- Add **`convertCurrenciesAt(double amount, Currency from, Currency to, DateTime date)`**:
  1. `from == to` → return `amount`.
  2. Resolve the applicable row: the latest row with `createdAt <= date`; if none, the **earliest**
     row; if `rateHistory` is empty, fall back to **default (1:1) mappings**.
  3. Build mappings from the resolved row (`buildMappings`) and convert.

  `convertCurrenciesAt` does **not** trigger a network fetch (the live path already refreshes on init
  and on balance conversions), avoiding a request stampede while iterating many movements in
  statistics.

## Read/display call-site changes

Switch these movement-level conversions from `convertCurrencies(...)` to
`convertCurrenciesAt(..., movement.creationDate)`:

- `movements_list.dart` — `MovementListItem.amount` getter.
- `movements.repository.dart` — `getExpensesByCategory` and `getExpensesByDay`.

### Statistics: eliminate the double conversion

Today `getExpensesByCategory`/`getExpensesByDay` convert each movement to a base currency, and
`expenses_by_category.dart`'s table toggle re-expresses the **aggregate** via the live rate. With
historical rates that second leg would re-introduce temporality loss at the aggregate level.

Fix (fully-correct, chosen approach):

- Give `getExpensesByCategory`/`getExpensesByDay` a `Currency displayCurrency` parameter and convert
  **each movement directly into that currency at its own `creationDate`**, summing per category / per
  day.
- In `expenses_by_category.dart`, the currency-toggle re-runs the query with the newly selected
  currency (a fast local re-query) instead of converting the loaded aggregate. `PERCENT` mode
  computes ratios from the currently-loaded aggregation (ratios are consistent within a single
  aggregation), so it needs no conversion.
- `expenses_by_day.dart` has no currency toggle; the repo converting each movement historically into
  the account currency (or USD when no account is selected) is the complete fix there.

### Unchanged (live rate, by design)

- `total_viewer.dart` (single-account and total-patrimony sums).
- `dashboard.dart` `buildTotalsChart` (per-account totals pie).
- `movement_details.dialog.dart` (native-currency amounts, no FX).

## Migration

New `lib/migrations/add_created_at_to_currency_rates.migration.dart`, appended to
`migrationDefinitions` in `migrations_list.dart`:

- `ALTER TABLE currency_rates ADD createdAt ...` guarded by the established duplicate-column
  idempotency pattern.
- Backfill the existing single row's `createdAt` from its `updatedAt`.
- Effect on existing data: existing movements predate that `createdAt`, so they resolve via the
  "earliest row" rule to the current/last-known rate — the accepted "old values use current rate"
  behavior. No historical rates are fetched from the network.

## Edge cases

- **Sparse history / offline gaps:** a movement created during a gap resolves to the last-known rate
  before it — the best available; accepted.
- **Empty history (fresh install, offline before first fetch):** `convertCurrenciesAt` falls back to
  1:1 defaults, matching today's seed behavior. Self-corrects once the first fetch records a row.
- **Derived, not frozen:** correcting/extending the history retroactively adjusts past display
  values — intended (single-user app; enables correct date edits).
- **Transfers:** the manually-entered `conversionRate` still governs the source→target crediting and
  the received-amount display; `convertCurrenciesAt` only governs re-expressing a movement's amount
  in a *different* display currency.

## Docs to update (same change, per docs-maintenance rule)

- `docs/features/currency.md` — history table, dedup-on-change, `convertCurrenciesAt`,
  `rateHistory`, resolution rule.
- `docs/features/statistics.md` — per-movement historical conversion and the re-query toggle.
- `docs/features/movements.md` — note that display/aggregation conversions are date-based.
- `docs/migrations.md` — the new migration entry (via the recipe).
