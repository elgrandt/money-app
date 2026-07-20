# Offline support via persisted currency rates — design

Date: 2026-07-20
Status: Approved (design), pending implementation plan

## Problem

The app is local-first (offline SQLite, single user, no cloud), yet it has exactly one network
dependency: the bluelytics rate fetch in
[utils.service.dart](../../../lib/services/utils.service.dart)
(`updateCurrencyMappings`, `https://api.bluelytics.com.ar/v2/latest`). Backups are local; the DB
is local; there is no other `http`/socket usage. That single dependency causes two distinct
problems that prevent real offline use:

- **Problem A — availability.** [home.dart](../../../lib/views/home/home.dart)
  `initializeCurrencies()` does `await utilsService.updateCurrencyMappings()`. When offline,
  `http.get` throws, so `initializedCurrencies` never flips to `true` and the home screen renders
  `Loader()` **forever**. A fresh install with no network is stuck on a spinner. This is an
  availability bug that exists today, independent of any caching.

- **Problem B — data quality.** `currencyMappings` is a `static` list seeded to multiplier `1`.
  It holds real rates only after a *successful* fetch and resets on every app restart. So offline
  (or after a restart before any fetch), `convertCurrencies` returns amounts unchanged — the app
  silently reports **1 USD = 1 ARS**, corrupting every cross-currency total and statistic.

One secondary bug found nearby:

1. **Failed fetch blocks retry for an hour.** `lastCurrencyMappingUpdate = DateTime.now()` is set
   *before* the HTTP call, so a failed call still "counts" against the hourly throttle.

Separately, `convertCurrencies` fire-and-forgets `updateCurrencyMappings()` unawaited. This is
**intentional** (documented in [tech-debt.md](../../tech-debt.md)): conversions are called on the
hot path, so the rate is refreshed in the background without blocking. That pattern is preserved.
The only offline shortcoming is that the unawaited future currently raises an *unhandled* async
exception when the fetch fails; wrapping `updateCurrencyMappings` in try/catch (see below) makes
the existing intentional pattern safe offline without changing it to be awaited.

## Goals

- The app launches and is fully usable offline.
- Cross-currency conversions offline use the last-known rates (persisted), not 1:1.
- Fold in the secondary throttle-timestamp bug fix, and make the intentional background refresh
  safe offline.

## Non-goals

- Rate history / charts (single latest snapshot only — YAGNI).
- Persisting the refresh throttle across restarts (decided: refresh on every launch).
- Fixing the hardcoded `eurToUsd = 1.11` (pre-existing tech debt, out of scope).

## Design decisions (agreed)

- **What to store:** the raw source rates (`usdToArs`, `eurToArs`, `eurToUsd`) plus an
  `updatedAt` timestamp. The 6 pairwise mappings are re-derived on load, exactly as
  `updateCurrencyMappings` does today. Single source of truth, no redundancy.
- **Row model:** a single latest row, overwritten (upsert) on each successful fetch.
- **Throttle:** stays in-memory (refresh attempted on every launch, still throttled within a
  running session). `updatedAt` is stored as cheap metadata (enables a future "rates as of…"
  display) but is not used to gate the throttle.

## Data layer

Follows the existing model + repository + migration pattern
([data-layer.md](../../data-layer.md), [migrations.md](../../migrations.md)).

**Model** — `lib/models/currency_rates.model.dart`, extends `BaseModel`:

- `usdToArs` (double), `eurToArs` (double), `eurToUsd` (double), `updatedAt` (DateTime).

**Repository** — `lib/repositories/currency_rates.repository.dart`, extends
`BaseRepository<CurrencyRates>`:

- Columns: `id` (INTEGER PK autoincrement), `usdToArs` / `eurToArs` / `eurToUsd` (REAL),
  `updatedAt` (DATE).
- Hand-written `modelToMap` / `mapToModel` — ISO date via `toIso8601String()` /
  `DateTime.tryParse`, matching the movements repository.
- `findLatest()` → the single row or `null`.
- `saveLatest(...)` → upsert the one row (update if a row exists, else insert).

**DatabaseService** ([database.service.dart](../../../lib/services/database.service.dart)) — add
`late CurrencyRatesRepository currencyRatesRepository`, construct it in
`initializeRepositories()`, and clear it in `deleteAllData()`.

**Migration** — `lib/migrations/currency_rates_initialization.migration.dart` calling
`currencyRatesRepository.initializeTable()`, appended to `migrationDefinitions` in
[migrations_list.dart](../../../lib/migrations/migrations_list.dart).

## UtilsService changes

[utils.service.dart](../../../lib/services/utils.service.dart):

- `loadCachedMappings()` — awaits `databaseService.initialized`, reads `findLatest()`, and if a
  row exists derives the 6 `currencyMappings` from the stored source rates (same derivation as
  today). Wrapped in try/catch; failures logged, non-fatal.
- `updateCurrencyMappings()` — refactored:
  - Wrap fetch + parse in try/catch.
  - **On success:** derive mappings, `saveLatest(...)` to the DB, and advance
    `lastCurrencyMappingUpdate` (fixes secondary bug #1 — timestamp advances only on success, so a
    failed fetch stays retryable within the session).
  - **On failure:** log and return; errors never propagate. This keeps the *intentional*
    fire-and-forget call in `convertCurrencies` unchanged (still unawaited, still background) while
    making it safe offline (no unhandled exception).
- Lazily obtains `DatabaseService` via `GetIt.instance.get<DatabaseService>()` at call time and
  awaits `databaseService.initialized` before any DB access (UtilsService is constructed before
  DatabaseService in `main.dart`).

## Startup / data flow

[home.dart](../../../lib/views/home/home.dart) `initializeCurrencies`:

```dart
await utilsService.loadCachedMappings();                     // hydrate from DB (safe offline)
if (mounted) setState(() => initializedCurrencies = true);   // render immediately
await utilsService.updateCurrencyMappings();                 // background refresh, swallows errors
if (mounted) setState(() {});                                // reflect fresher rates if they changed
```

- **Online:** cached rates render instantly, then refresh to live rates and persist.
- **Offline with prior cache:** last-known rates render; refresh fails silently; UI works.
- **First-ever launch offline (no cache):** seed 1:1 mappings until the first online launch —
  unavoidable (no source ever reached), documented as a known edge.

## Error handling

- All network, parse, and DB-write failures are caught and logged; none reach the UI.
- A DB write failure on `saveLatest` is logged and non-fatal (in-memory mappings still update).

## Testing

Project has no automated tests by policy → manual verification:

- Launch in airplane mode, fresh install: home renders (seed 1:1), no infinite spinner.
- Launch online once, then airplane mode: home renders with last-known rates; cross-currency
  totals are correct (not 1:1).
- Launch online: rates refresh to live values and the single row persists across restarts.

## Docs to update (same change, per docs-maintenance rule)

- [docs/features/currency.md](../../features/currency.md) — new persistence, offline startup
  flow, edge cases.
- [docs/tech-debt.md](../../tech-debt.md) — the unawaited-`updateCurrencyMappings` entry stays
  (still intentional), but its closing note must change: `Home` no longer awaits a network fetch
  before rendering — it hydrates cached mappings from the DB and renders immediately, and
  `updateCurrencyMappings` now swallows errors so the background refresh is safe offline. Also
  note the first-launch-offline seed behavior.
