# Direction-based buy/sell exchange rates — design

## Goal

The bluelytics API returns both `value_buy` and `value_sell` for each quote, but the app only
uses `value_buy` for every conversion. Rebuild the currency mappings so each conversion uses the
rate a real casa de cambio would apply: the **sell** price when acquiring a foreign currency and
the **buy** price when disposing of it. Also derive the USD↔EUR cross rate from the real rates,
retiring the hardcoded `eurToUsd = 1.11`.

Bluelytics semantics (from the individual's perspective, using the `blue` / `blue_euro` quotes):

- `value_buy` — the price the casa de cambio *pays* you → what you **get** when you **sell** your
  foreign currency (lower).
- `value_sell` — the price the casa de cambio *charges* → what you **pay** to **buy** foreign
  currency (higher).

## Semantics

Four source values drive everything: `usdBuy`, `usdSell` (from `blue`) and `eurBuy`, `eurSell`
(from `blue_euro`).

| Conversion | Rationale | Multiplier |
| --- | --- | --- |
| ARS → USD | buy USD → pay `usdSell` | `1 / usdSell` |
| ARS → EUR | buy EUR → pay `eurSell` | `1 / eurSell` |
| USD → ARS | sell USD → get `usdBuy` | `usdBuy` |
| EUR → ARS | sell EUR → get `eurBuy` | `eurBuy` |
| USD → EUR | sell USD (`usdBuy`) then buy EUR (`eurSell`) | `usdBuy / eurSell` |
| EUR → USD | sell EUR (`eurBuy`) then buy USD (`usdSell`) | `eurBuy / usdSell` |

Sanity check with example rates (`usdBuy=1504, usdSell=1538, eurBuy=1635, eurSell=1671`):
`EUR→USD = 1635/1538 ≈ 1.063` (EUR worth more than USD ✓), `USD→EUR = 1504/1671 ≈ 0.900` (✓).

## Scope

Touches the model, repository, a new migration, the service, and the dashboard view — plus docs.
`convertCurrencies` and the mapping-lookup mechanism are **unchanged**; only the source data and
the multipliers derived from it change.

## Data model + migration

The persisted single-row cache changes from 3 values to 4.

### `lib/models/currency_rates.model.dart`

Replace `usdToArs, eurToArs, eurToUsd` with `usdBuy, usdSell, eurBuy, eurSell` (all `double`);
keep `updatedAt`. Update the constructor and `toString`.

### `lib/repositories/currency_rates.repository.dart`

- Column list: `id`, `usdBuy`, `usdSell`, `eurBuy`, `eurSell` (all `REAL`), `updatedAt` (`DATE`).
- `modelToMap` / `mapToModel` rewritten for the 4 new columns.
- `findLatest` / `saveLatest` unchanged.

### New migration `lib/migrations/rebuild_currency_rates_buy_sell.migration.dart`

`currency_rates` is a disposable single-row cache (re-fetched hourly, re-derived on startup), so
the cleanest path is to **drop and re-create** the table with the new schema rather than fight
SQLite's limited `ALTER TABLE` rename/drop support:

```dart
await databaseService.db.execute('DROP TABLE IF EXISTS currency_rates');
await databaseService.currencyRatesRepository.initializeTable();
```

Append `rebuildCurrencyRatesBuySellMigration` to `migrationDefinitions` in
[migrations_list.dart](../../../lib/migrations/migrations_list.dart) (order matters — append at
the end). `down` logs "cannot down" like the other data migrations.

**Trade-off / caveat:** on upgrade, a user who is offline at that moment loses the cached row and
falls back to the `1` seed (1:1 conversions) until the next online launch re-fetches. This is the
same caveat already documented for a first-ever offline launch, and acceptable for a cache.

## Service — `lib/services/utils.service.dart`

- `applyRates({required double usdBuy, required double usdSell, required double eurBuy, required double eurSell})`
  — builds the 6 `CurrencyMapping`s per the semantics table above.
- `loadCachedMappings()` — reads the 4 new fields from the cached row.
- `updateCurrencyMappings()`:
  - `usdBuy = body['blue']['value_buy']`, `usdSell = body['blue']['value_sell']`.
  - `eurBuy = body['blue_euro']['value_buy']`, `eurSell = body['blue_euro']['value_sell']`.
  - No `1.11` constant.
  - `applyRates(...)` then persist a `CurrencyRates` with the 4 values + `updatedAt`.
- `convertCurrencies` — **unchanged** (mapping lookup + throttled background refresh).
- Seed `currencyMappings` stays at `1` for all pairs.

## Dashboard — `lib/views/home/exchange_rates.dart`

Each currency row shows **compra/venta** read directly from `latestRates` (already loaded via
`findLatest()`), formatted with `beautifyCurrency(_, Currency.ARS)`:

```text
   [icon] USD                 $1.504/$1.538
   [icon] EUR                 $1.635/$1.671
```

- A small helper maps a `Currency` to its `(buy, sell)` pair from `CurrencyRates`
  (USD → `usdBuy`/`usdSell`, EUR → `eurBuy`/`eurSell`).
- The amount cell renders `'${beautifyCurrency(buy, ARS)}/${beautifyCurrency(sell, ARS)}'`
  (compra first, venta second), bold 18px, right-aligned — same visual weight as today.
- Because values now come from `latestRates` (nullable) rather than `convertCurrencies`, the
  amount cell needs a fallback while `latestRates == null` (before first load / no row yet):
  show `—/—` so the row is never blank. `convertCurrencies` is still what triggers
  the background refresh elsewhere; the dashboard already subscribes to the `change` event to
  re-read `latestRates`, so a successful fetch refreshes the displayed values.
- `Última actualización` line unchanged.

## Docs to update (same change — docs-maintenance rule)

- [docs/features/currency.md](../../features/currency.md) — rewrite Mechanics: 4 source values,
  buy/sell per direction, USD↔EUR derived through ARS, `applyRates` new signature, the
  `value_buy`/`value_sell` fetch; update the persisted-fields description; update the
  `exchange_rates.dart` entry to describe the compra/venta display; remove the EUR↔USD `1.11`
  edge-case bullet.
- [docs/tech-debt.md](../../tech-debt.md) — remove the "Hardcoded `eurToUsd = 1.11`" entry.
- [docs/migrations.md](../../migrations.md) — no structural change; the ordered-registry section
  references the list generically, so no edit needed unless migrations are individually
  enumerated (they are not).

## Out of scope / non-goals

- No per-direction display of every pair; the dashboard only shows USD/EUR compra/venta vs ARS.
- No `oficial` rates (the app uses `blue` only).
- No manual refresh button; refresh stays throttled via `convertCurrencies`.
- No change to how currencies are stored on accounts/movements.
