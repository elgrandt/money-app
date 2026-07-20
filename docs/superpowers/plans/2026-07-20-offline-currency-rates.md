# Offline Currency Rates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app fully usable offline by persisting last-known currency rates in the DB and never letting a failed rate fetch block the home screen.

**Architecture:** Add a single-row `currency_rates` table (model + repository + migration, following the existing pattern). `UtilsService` hydrates its in-memory `currencyMappings` from that row on startup and persists fresh rates on every successful fetch. Home loads cached mappings and renders immediately, then refreshes in the background.

**Tech Stack:** Dart / Flutter, `sqflite`, `get_it`, `http`, `logger`.

## Global Constraints

- **No automated tests.** This project has **no** test suite by policy (CLAUDE.md). Do **not** create tests or run `flutter test`. Verify every task with `flutter analyze` (must report no new issues) plus the manual steps given in the task.
- **Language:** code and logs in English; UI strings in Spanish (`es_AR`). This feature adds no new UI strings.
- **Imports at top of file** — never inline/fully-qualified references.
- **Enums stored as `TEXT` via `.name`**, dates stored as ISO strings in a `DATE` column via `toIso8601String()` / `DateTime.parse` (matches [movements.repository.dart](../../../lib/repositories/movements.repository.dart)).
- **Coding style:** no leading blank line inside blocks; spaced `${ }` interpolation; minimal comments. See [coding-style.md](../../coding-style.md).
- **Git:** work on branch `feature/offline-currency-rates` (already created). Never commit to `master`.
- **Docs-maintenance rule:** docs are updated in this same branch (Task 4).
- **Bluelytics derivation (verbatim, keep identical to current code):** `usdToArs = body['blue']['value_buy']`, `eurToArs = body['blue_euro']['value_buy']`, `eurToUsd = 1.11` (hardcoded — pre-existing debt, do not change).

---

### Task 1: Persist currency rates (model, repository, migration, registration)

Adds the `currency_rates` table and its data-access layer, following the exact model + repository + migration pattern used by accounts/categories.

**Files:**
- Create: `lib/models/currency_rates.model.dart`
- Create: `lib/repositories/currency_rates.repository.dart`
- Create: `lib/migrations/currency_rates_initialization.migration.dart`
- Modify: `lib/services/database.service.dart`
- Modify: `lib/migrations/migrations_list.dart`

**Interfaces:**
- Consumes: `BaseModel` ([base.model.dart](../../../lib/models/base.model.dart)), `BaseRepository<Model>` and the column DSL ([base.repository.dart](../../../lib/repositories/base.repository.dart)), `MigrationDefinition` ([migration_definition.dart](../../../lib/migrations/migration_definition.dart)).
- Produces:
  - `class CurrencyRates extends BaseModel` with `double usdToArs`, `double eurToArs`, `double eurToUsd`, `DateTime updatedAt`, and named ctor `CurrencyRates({ required usdToArs, required eurToArs, required eurToUsd, required updatedAt, super.id })`.
  - `class CurrencyRatesRepository extends BaseRepository<CurrencyRates>` with `Future<CurrencyRates?> findLatest()` and `Future<void> saveLatest(CurrencyRates rates)`.
  - `DatabaseService.currencyRatesRepository` (a `late CurrencyRatesRepository`).
  - `currencyRatesInitializationMigration` (a `MigrationDefinition`, name `'currency_rates_initialization'`).

- [ ] **Step 1: Create the model**

Create `lib/models/currency_rates.model.dart`:

```dart
import 'package:money/models/base.model.dart';

class CurrencyRates extends BaseModel {
  double usdToArs;
  double eurToArs;
  double eurToUsd;
  DateTime updatedAt;

  CurrencyRates({ required this.usdToArs, required this.eurToArs, required this.eurToUsd, required this.updatedAt, super.id });

  @override
  String toString() {
    return 'usdToArs=$usdToArs eurToArs=$eurToArs eurToUsd=$eurToUsd (updatedAt=$updatedAt)';
  }
}
```

- [ ] **Step 2: Create the repository**

Create `lib/repositories/currency_rates.repository.dart`:

```dart
import 'package:money/models/currency_rates.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:sqflite/sqflite.dart';

class CurrencyRatesRepository extends BaseRepository<CurrencyRates> {
  static List<DatabaseColumnDefinition> currencyRatesColumns = [
    DatabaseColumnDefinition('id', DatabaseColumnType.INTEGER, primaryKey: PrimaryKeyDefinition(autoincrement: true)),
    DatabaseColumnDefinition('usdToArs', DatabaseColumnType.REAL),
    DatabaseColumnDefinition('eurToArs', DatabaseColumnType.REAL),
    DatabaseColumnDefinition('eurToUsd', DatabaseColumnType.REAL),
    DatabaseColumnDefinition('updatedAt', DatabaseColumnType.DATE),
  ];

  CurrencyRatesRepository(Database db): super(db, 'currency_rates', CurrencyRatesRepository.currencyRatesColumns);

  @override
  Map<String, Object?> modelToMap(CurrencyRates model) {
    var map = <String, Object?>{};
    if (model.id != null) {
      map['id'] = model.id;
    }
    map['usdToArs'] = model.usdToArs;
    map['eurToArs'] = model.eurToArs;
    map['eurToUsd'] = model.eurToUsd;
    map['updatedAt'] = model.updatedAt.toIso8601String();
    return map;
  }

  @override
  CurrencyRates mapToModel(Map<String, Object?> map) {
    return CurrencyRates(
      usdToArs: map['usdToArs'] as double,
      eurToArs: map['eurToArs'] as double,
      eurToUsd: map['eurToUsd'] as double,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      id: map['id'] as int?,
    );
  }

  Future<CurrencyRates?> findLatest() async {
    var results = await find(orderBy: 'id DESC', limit: 1);
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<void> saveLatest(CurrencyRates rates) async {
    var existing = await findLatest();
    if (existing != null) {
      rates.id = existing.id;
      await update(rates);
    } else {
      await insert(rates);
    }
  }
}
```

- [ ] **Step 3: Register the repository in DatabaseService**

In `lib/services/database.service.dart`:

Add the import near the other repository imports:

```dart
import 'package:money/repositories/currency_rates.repository.dart';
```

Add the field after `categoriesRepository` (replace the `// Add new repositories here` marker in the fields block):

```dart
  late CategoriesRepository categoriesRepository;
  late CurrencyRatesRepository currencyRatesRepository;
  // Add new repositories here
```

Construct it in `initializeRepositories()` after `categoriesRepository`:

```dart
    categoriesRepository = CategoriesRepository(db);
    currencyRatesRepository = CurrencyRatesRepository(db);
    // Add new repositories here
```

Clear it in `deleteAllData()`:

```dart
    await categoriesRepository.deleteAll();
    await currencyRatesRepository.deleteAll();
    // Add new repositories here
```

- [ ] **Step 4: Create the migration**

Create `lib/migrations/currency_rates_initialization.migration.dart`:

```dart
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/migrations/migration_definition.dart';
import 'package:money/services/database.service.dart';

var logger = GetIt.instance.get<Logger>();

var currencyRatesInitializationMigration = MigrationDefinition(
  'currency_rates_initialization',
  () async {
    var databaseService = GetIt.instance.get<DatabaseService>();
    await databaseService.currencyRatesRepository.initializeTable();
  }, () async {
    logger.e('Cannot down this migration');
  }
);
```

- [ ] **Step 5: Register the migration (append to the end of the list)**

In `lib/migrations/migrations_list.dart` add the import:

```dart
import 'package:money/migrations/currency_rates_initialization.migration.dart';
```

Append to the **end** of `migrationDefinitions` (must be last so it runs as a new migration on existing installs):

```dart
  addDeletedFieldToAccountMigration,
  currencyRatesInitializationMigration,
];
```

- [ ] **Step 6: Verify static analysis**

Run: `flutter analyze`
Expected: completes with **no new** errors or warnings referencing the new files.

- [ ] **Step 7: Verify the table is created at runtime**

Run: `flutter run` on a device/emulator. In the logs confirm a line `Running migration currency_rates_initialization` (first run only) and `Finished database initialization`, with no migration error. The app should reach the home screen normally.

- [ ] **Step 8: Commit**

```bash
git add lib/models/currency_rates.model.dart lib/repositories/currency_rates.repository.dart lib/migrations/currency_rates_initialization.migration.dart lib/services/database.service.dart lib/migrations/migrations_list.dart
git commit -m "feat: add currency_rates table and repository

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Hydrate and persist rates in UtilsService

Refactor `UtilsService` to derive mappings in one place, load them from the cache, and persist fresh rates on every successful fetch. Fixes the throttle-timestamp bug and makes the fetch swallow errors so the intentional background refresh is safe offline.

**Files:**
- Modify: `lib/services/utils.service.dart`

**Interfaces:**
- Consumes: `CurrencyRates`, `CurrencyRatesRepository.findLatest()` / `.saveLatest(...)`, `DatabaseService.currencyRatesRepository`, `DatabaseService.initialized` (from Task 1).
- Produces:
  - `Future<void> UtilsService.loadCachedMappings()` — hydrates `currencyMappings` from the cached row if present; safe (never throws).
  - `Future<void> UtilsService.updateCurrencyMappings()` — unchanged signature; now persists on success, advances the throttle only on success, and never throws.

- [ ] **Step 1: Add imports**

In `lib/services/utils.service.dart` add near the existing imports (keep alphabetical-ish grouping with the other `package:money` imports):

```dart
import 'package:money/models/currency_rates.model.dart';
import 'package:money/services/database.service.dart';
```

- [ ] **Step 2: Add a lazy DatabaseService getter and a shared rate-derivation helper**

Inside `class UtilsService`, add a lazy getter (UtilsService is constructed before DatabaseService in `main.dart`, so it must be resolved at call time, not in the constructor):

```dart
  DatabaseService get _databaseService => GetIt.instance.get<DatabaseService>();
```

Add the private helper that derives and assigns the 6 pairwise mappings (this is the exact derivation currently inlined in `updateCurrencyMappings`):

```dart
  void applyRates({ required double usdToArs, required double eurToArs, required double eurToUsd }) {
    currencyMappings = [
      CurrencyMapping(from: Currency.ARS, to: Currency.EUR, multiplier: 1 / eurToArs),
      CurrencyMapping(from: Currency.ARS, to: Currency.USD, multiplier: 1 / usdToArs),
      CurrencyMapping(from: Currency.USD, to: Currency.ARS, multiplier: usdToArs),
      CurrencyMapping(from: Currency.USD, to: Currency.EUR, multiplier: 1 / eurToUsd),
      CurrencyMapping(from: Currency.EUR, to: Currency.ARS, multiplier: eurToArs),
      CurrencyMapping(from: Currency.EUR, to: Currency.USD, multiplier: eurToUsd),
    ];
  }
```

- [ ] **Step 3: Add `loadCachedMappings`**

Add this method to `UtilsService`:

```dart
  Future<void> loadCachedMappings() async {
    try {
      await _databaseService.initialized;
      var cached = await _databaseService.currencyRatesRepository.findLatest();
      if (cached != null) {
        applyRates(usdToArs: cached.usdToArs, eurToArs: cached.eurToArs, eurToUsd: cached.eurToUsd);
        logger.d('Loaded cached currency mappings: $cached');
      }
    } catch (error, stackTrace) {
      logger.e('Error loading cached currency mappings', error: error, stackTrace: stackTrace);
    }
  }
```

- [ ] **Step 4: Rewrite `updateCurrencyMappings`**

Replace the existing `updateCurrencyMappings` method entirely with:

```dart
  Future<void> updateCurrencyMappings() async {
    // Update currency mappings every hour
    var diff = DateTime.now().millisecondsSinceEpoch - lastCurrencyMappingUpdate.millisecondsSinceEpoch;
    if (diff < 1000 * 60 * 60) return; // 1 hour
    logger.d('Updating currency mappings');
    try {
      var url = Uri.parse('https://api.bluelytics.com.ar/v2/latest');
      var response = await http.get(url);
      var json = response.body;
      var body = jsonDecode(json);
      double usdToArs = body['blue']['value_buy'];
      double eurToArs = body['blue_euro']['value_buy'];
      double eurToUsd = 1.11;
      applyRates(usdToArs: usdToArs, eurToArs: eurToArs, eurToUsd: eurToUsd);
      lastCurrencyMappingUpdate = DateTime.now();
      await _databaseService.currencyRatesRepository.saveLatest(CurrencyRates(
        usdToArs: usdToArs,
        eurToArs: eurToArs,
        eurToUsd: eurToUsd,
        updatedAt: DateTime.now(),
      ));
    } catch (error, stackTrace) {
      logger.e('Error updating currency mappings', error: error, stackTrace: stackTrace);
    }
  }
```

Note the two behavior changes vs. the old code: `lastCurrencyMappingUpdate` now advances **after** a successful fetch (not before), and all errors are caught and logged rather than thrown. Leave `convertCurrencies`'s unawaited `updateCurrencyMappings()` call exactly as-is — it is intentional and now safe.

- [ ] **Step 5: Verify static analysis**

Run: `flutter analyze`
Expected: no new errors/warnings. In particular, no "unused import" for the two added imports and no unawaited-future warnings.

- [ ] **Step 6: Verify persistence at runtime (online)**

Run: `flutter run` with network available. Open the app, view a total in a non-account currency (forces a conversion). In the logs confirm `Updating currency mappings` with no error. Fully close and relaunch the app **with network off** (airplane mode): the logs should show `Loaded cached currency mappings: ...` and cross-currency totals should be non-1:1 (real last-known rates).

- [ ] **Step 7: Commit**

```bash
git add lib/services/utils.service.dart
git commit -m "feat: hydrate and persist currency rates for offline use

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Make home startup resilient offline

Home hydrates cached mappings and renders immediately, then refreshes in the background — so a failed fetch never leaves the screen stuck on the loader.

**Files:**
- Modify: `lib/views/home/home.dart:52-58` (`initializeCurrencies`)

**Interfaces:**
- Consumes: `UtilsService.loadCachedMappings()` and `UtilsService.updateCurrencyMappings()` (from Task 2).
- Produces: no new public interface.

- [ ] **Step 1: Rewrite `initializeCurrencies`**

Replace the existing method in `lib/views/home/home.dart`:

```dart
  Future<void> initializeCurrencies() async {
    await utilsService.loadCachedMappings();
    if (!mounted) return;
    setState(() {
      initializedCurrencies = true;
    });
    await utilsService.updateCurrencyMappings();
    if (!mounted) return;
    setState(() {});
  }
```

- [ ] **Step 2: Verify static analysis**

Run: `flutter analyze`
Expected: no new errors/warnings.

- [ ] **Step 3: Verify offline launch (the core acceptance test)**

- Fresh install with network **off** (uninstall first, or clear app data, then airplane mode): launch the app. It must reach the welcome/home screen — **no infinite spinner**. (Conversions will be 1:1 since no rates were ever cached; this is the documented first-launch edge.)
- Launch once **online** to cache rates, then relaunch **offline**: home renders with last-known rates; cross-currency totals are correct (not 1:1).
- Launch **online**: home renders immediately, then rates refresh to live values (logs show `Updating currency mappings`).

- [ ] **Step 4: Commit**

```bash
git add lib/views/home/home.dart
git commit -m "fix: render home from cached rates so offline launch works

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Update documentation

Bring the currency and tech-debt docs in sync with the new persistence and offline behavior (docs-maintenance rule).

**Files:**
- Modify: `docs/features/currency.md`
- Modify: `docs/tech-debt.md`

**Interfaces:** none (documentation only).

- [ ] **Step 1: Update `docs/features/currency.md`**

In the **Mechanics** section, after the `updateCurrencyMappings()` bullet, add:

```markdown
- Rates are persisted in a single-row `currency_rates` table
  ([currency_rates.repository.dart](../../lib/repositories/currency_rates.repository.dart)): the
  raw source values (`usdToArs`, `eurToArs`, `eurToUsd`) plus `updatedAt`. On a successful fetch
  the row is upserted via `saveLatest`; on startup `loadCachedMappings()` reads it and re-derives
  the pairwise multipliers, so conversions are correct offline and across restarts.
```

In the **Edge cases / debt** section, replace the `updateCurrencyMappings is fire-and-forget` bullet with:

```markdown
- `updateCurrencyMappings` swallows network/parse errors (logs them) and advances its hourly
  throttle only on success, so a failed fetch stays retryable within the session. Its unawaited
  call from `convertCurrencies` is intentional background refresh and is safe offline.
- Home renders from cached (or seed) mappings immediately and refreshes in the background, so an
  offline launch never blocks on the network.
- **First-ever launch while offline** (no cached row): mappings stay at the `1` seed until the
  first online launch, so cross-currency amounts show 1:1 until then.
```

- [ ] **Step 2: Update `docs/tech-debt.md`**

Replace the closing sentence of the `convertCurrencies triggers an unawaited updateCurrencyMappings()` entry (the part that reads "First-load conversions in `Home` are covered because `initializeCurrencies()` awaits the update before rendering.") with:

```markdown
  `Home` no longer awaits the network fetch before rendering — `initializeCurrencies()` hydrates
  cached mappings from the DB and renders immediately, and `updateCurrencyMappings` swallows
  errors, so the background refresh is safe offline.
```

- [ ] **Step 3: Verify links and analysis**

Run: `flutter analyze`
Expected: no errors (docs-only change; analysis should be unaffected). Manually confirm the new relative doc link path `../../lib/repositories/currency_rates.repository.dart` resolves.

- [ ] **Step 4: Commit**

```bash
git add docs/features/currency.md docs/tech-debt.md
git commit -m "docs: document offline currency-rate persistence

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Notes for the implementer

- There is **no** `build_runner`/codegen step — models are hand-written.
- The `currency_rates` migration must be the **last** entry in `migrationDefinitions`; migrations run by name and only unseen ones execute, so appending it makes existing installs create the table on next launch.
- Do not change the hardcoded `eurToUsd = 1.11` — it is tracked separately as tech debt and is out of scope.
