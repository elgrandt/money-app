# Movement Historical Exchange Rates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Value each movement at the exchange rate in effect when it was created (derived from its `creationDate` against a rate history), instead of always converting at today's live rate.

**Architecture:** `currency_rates` becomes an append-on-change history table (a new row only when a rate value changes; otherwise `updatedAt` is bumped). Movement-level conversions resolve the applicable history row by date and build the pairwise multipliers from it. Account balances / totals keep using the live global rate. No change to the `movements` table.

**Tech Stack:** Dart / Flutter, `sqflite`, `get_it`. Spec: [docs/superpowers/specs/2026-07-25-movement-historical-exchange-rates-design.md](../specs/2026-07-25-movement-historical-exchange-rates-design.md).

## Global Constraints

- **No automated tests** — the project has no tests by policy. Every task verifies with `flutter analyze` (expect no new issues) plus manual checks where noted; there are no "write failing test" steps.
- **Use `flutter`/`mvn`-free tooling** — this is a Flutter project; run `flutter analyze` and `flutter run`.
- **Language:** English code identifiers and log messages; Spanish (`es_AR`) UI strings. Do not translate existing UI copy.
- **No codegen** — models are hand-written; edit `modelToMap`/`mapToModel` by hand.
- **Enums stored as `TEXT` via `.name`; dates stored as ISO-8601 strings** (`DatabaseColumnType.DATE`).
- **Git:** work on branch `feature/movement-historical-rates` (already created). Never commit to `master`. Add the co-author trailer on every commit:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- **Docs-maintenance rule:** feature docs are updated in Task 8, part of this same change.

---

### Task 1: `CurrencyRates` gets a `createdAt` field

Adds the `createdAt` column to the model, the fresh-DB column list, and the map conversions. Keeps everything compiling by updating the one existing `CurrencyRates(...)` construction site.

**Files:**
- Modify: `lib/models/currency_rates.model.dart`
- Modify: `lib/repositories/currency_rates.repository.dart:6-13` (column list), `:18-29` (`modelToMap`), `:31-41` (`mapToModel`)
- Modify: `lib/services/utils.service.dart:94-100` (existing `CurrencyRates(...)` construction)

**Interfaces:**
- Produces: `CurrencyRates` now has `DateTime createdAt` (required constructor param, positioned before `updatedAt`). Column `createdAt` of type `DATE`.

- [ ] **Step 1: Add `createdAt` to the model**

Replace the whole body of `lib/models/currency_rates.model.dart` with:

```dart
import 'package:money/models/base.model.dart';

class CurrencyRates extends BaseModel {
  double usdBuy;
  double usdSell;
  double eurBuy;
  double eurSell;
  DateTime createdAt;
  DateTime updatedAt;

  CurrencyRates({ required this.usdBuy, required this.usdSell, required this.eurBuy, required this.eurSell, required this.createdAt, required this.updatedAt, super.id });

  @override
  String toString() {
    return 'usdBuy=$usdBuy usdSell=$usdSell eurBuy=$eurBuy eurSell=$eurSell (createdAt=$createdAt updatedAt=$updatedAt)';
  }
}
```

- [ ] **Step 2: Add the `createdAt` column definition**

In `lib/repositories/currency_rates.repository.dart`, add the `createdAt` column to `currencyRatesColumns`, immediately before the `updatedAt` line:

```dart
    DatabaseColumnDefinition('eurSell', DatabaseColumnType.REAL),
    DatabaseColumnDefinition('createdAt', DatabaseColumnType.DATE),
    DatabaseColumnDefinition('updatedAt', DatabaseColumnType.DATE),
```

- [ ] **Step 3: Write `createdAt` in `modelToMap`**

In the same file, add the `createdAt` line to `modelToMap`, before the `updatedAt` line:

```dart
    map['eurSell'] = model.eurSell;
    map['createdAt'] = model.createdAt.toIso8601String();
    map['updatedAt'] = model.updatedAt.toIso8601String();
    return map;
```

- [ ] **Step 4: Read `createdAt` in `mapToModel` (null-safe)**

Replace the `mapToModel` return with (falls back to `updatedAt` if `createdAt` is null, which can only happen on the pre-migration row before Task 2 backfills it):

```dart
  @override
  CurrencyRates mapToModel(Map<String, Object?> map) {
    return CurrencyRates(
      usdBuy: map['usdBuy'] as double,
      usdSell: map['usdSell'] as double,
      eurBuy: map['eurBuy'] as double,
      eurSell: map['eurSell'] as double,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : DateTime.parse(map['updatedAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      id: map['id'] as int?,
    );
  }
```

- [ ] **Step 5: Keep the existing construction site compiling**

In `lib/services/utils.service.dart`, the `saveLatest(CurrencyRates(...))` call now needs `createdAt`. Update it (this is refined in Task 3):

```dart
      await _databaseService.currencyRatesRepository.saveLatest(CurrencyRates(
        usdBuy: usdBuy,
        usdSell: usdSell,
        eurBuy: eurBuy,
        eurSell: eurSell,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
```

- [ ] **Step 6: Analyze**

Run: `flutter analyze`
Expected: `No issues found!` (or no issues in the three edited files).

- [ ] **Step 7: Commit**

```bash
git add lib/models/currency_rates.model.dart lib/repositories/currency_rates.repository.dart lib/services/utils.service.dart
git commit -m "$(cat <<'EOF'
Add createdAt to CurrencyRates model and schema

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Migration — add `createdAt` to `currency_rates`

Evolves existing databases: adds the column (idempotent) and backfills the existing single row's `createdAt` from its `updatedAt`, so old movements resolve to the current/last-known rate via the "earliest row" rule.

**Files:**
- Create: `lib/migrations/add_created_at_to_currency_rates.migration.dart`
- Modify: `lib/migrations/migrations_list.dart`

**Interfaces:**
- Produces: top-level `addCreatedAtToCurrencyRatesMigration`, appended last in `migrationDefinitions`.

- [ ] **Step 1: Create the migration file**

Create `lib/migrations/add_created_at_to_currency_rates.migration.dart` with (mirrors the idempotency pattern in `add_deleted_field_to_account.migration.dart`):

```dart
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/migrations/migration_definition.dart';
import 'package:money/services/database.service.dart';
import 'package:sqflite/sqflite.dart';

var logger = GetIt.instance.get<Logger>();

var addCreatedAtToCurrencyRatesMigration = MigrationDefinition(
  'add_created_at_to_currency_rates',
  () async {
    var databaseService = GetIt.instance.get<DatabaseService>();
    try {
      await databaseService.db.execute('ALTER TABLE currency_rates ADD createdAt DATE');
    } catch (error) {
      if (error is DatabaseException && error.isDuplicateColumnError()) {
        logger.w('createdAt column already exists');
      } else {
        rethrow;
      }
    }
    await databaseService.db.execute('UPDATE currency_rates SET createdAt = updatedAt WHERE createdAt IS NULL');
  }, () async {
    logger.e('Cannot down this migration');
  }
);
```

- [ ] **Step 2: Register the migration (append last)**

In `lib/migrations/migrations_list.dart`, add the import (keep alphabetical-ish with the others):

```dart
import 'package:money/migrations/add_created_at_to_currency_rates.migration.dart';
```

and append it as the **last** entry of `migrationDefinitions`:

```dart
  currencyRatesInitializationMigration,
  rebuildCurrencyRatesBuySellMigration,
  addCreatedAtToCurrencyRatesMigration,
];
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Manual verification (migration runs)**

Run: `flutter run` (against an existing DB with a cached rate row).
Expected: app starts without migration errors; logs show the migration running (or `createdAt column already exists` on a fresh schema). Stop the app afterward.

- [ ] **Step 5: Commit**

```bash
git add lib/migrations/add_created_at_to_currency_rates.migration.dart lib/migrations/migrations_list.dart
git commit -m "$(cat <<'EOF'
Add migration for currency_rates.createdAt

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Dedup-on-change recording

Replaces the single-row upsert with append-on-change: insert a new row only when a value changed; otherwise bump `updatedAt`.

**Files:**
- Modify: `lib/repositories/currency_rates.repository.dart:49-57` (replace `saveLatest` with `record`)
- Modify: `lib/services/utils.service.dart:94-100` (call `record`)

**Interfaces:**
- Consumes: `CurrencyRates` from Task 1.
- Produces: `Future<void> record(CurrencyRates rates)` on `CurrencyRatesRepository`. `saveLatest` is removed.

- [ ] **Step 1: Replace `saveLatest` with `record`**

In `lib/repositories/currency_rates.repository.dart`, replace the `saveLatest` method with:

```dart
  Future<void> record(CurrencyRates rates) async {
    var latest = await findLatest();
    if (latest != null &&
        latest.usdBuy == rates.usdBuy &&
        latest.usdSell == rates.usdSell &&
        latest.eurBuy == rates.eurBuy &&
        latest.eurSell == rates.eurSell) {
      latest.updatedAt = rates.updatedAt;
      await update(latest);
    } else {
      await insert(rates);
    }
  }
```

- [ ] **Step 2: Call `record` from `updateCurrencyMappings`**

In `lib/services/utils.service.dart`, change the `saveLatest(` call to `record(`:

```dart
      await _databaseService.currencyRatesRepository.record(CurrencyRates(
        usdBuy: usdBuy,
        usdSell: usdSell,
        eurBuy: eurBuy,
        eurSell: eurSell,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: `No issues found!` (confirms no remaining `saveLatest` references).

- [ ] **Step 4: Commit**

```bash
git add lib/repositories/currency_rates.repository.dart lib/services/utils.service.dart
git commit -m "$(cat <<'EOF'
Record currency rates append-on-change

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Date-aware conversion in `UtilsService`

Extracts a pure mapping builder, keeps an in-memory sorted rate history, and adds `convertCurrenciesAt(...)` that resolves the applicable row by date.

**Files:**
- Modify: `lib/repositories/currency_rates.repository.dart` (add `findAllSorted`)
- Modify: `lib/services/utils.service.dart` (`applyRates` refactor, `rateHistory`, `loadRateHistory`, `convertCurrenciesAt`, `_resolveRatesAt`, refresh wiring)

**Interfaces:**
- Consumes: `record` (Task 3), `CurrencyRates` (Task 1).
- Produces:
  - `Future<List<CurrencyRates>> findAllSorted()` on `CurrencyRatesRepository` (ascending by `createdAt`).
  - `List<CurrencyMapping> buildMappings({required double usdBuy, required double usdSell, required double eurBuy, required double eurSell})`.
  - `List<CurrencyRates> rateHistory`.
  - `Future<void> loadRateHistory()`.
  - `double convertCurrenciesAt(double amount, Currency from, Currency to, DateTime date)`.

- [ ] **Step 1: Add `findAllSorted` to the repository**

In `lib/repositories/currency_rates.repository.dart`, add after `findLatest`:

```dart
  Future<List<CurrencyRates>> findAllSorted() async {
    return find(orderBy: 'createdAt ASC');
  }
```

- [ ] **Step 2: Extract `buildMappings` and simplify `applyRates`**

In `lib/services/utils.service.dart`, replace the `applyRates` method with these two:

```dart
  List<CurrencyMapping> buildMappings({ required double usdBuy, required double usdSell, required double eurBuy, required double eurSell }) {
    return [
      CurrencyMapping(from: Currency.ARS, to: Currency.EUR, multiplier: 1 / eurSell),
      CurrencyMapping(from: Currency.ARS, to: Currency.USD, multiplier: 1 / usdSell),
      CurrencyMapping(from: Currency.USD, to: Currency.ARS, multiplier: usdBuy),
      CurrencyMapping(from: Currency.USD, to: Currency.EUR, multiplier: usdBuy / eurSell),
      CurrencyMapping(from: Currency.EUR, to: Currency.ARS, multiplier: eurBuy),
      CurrencyMapping(from: Currency.EUR, to: Currency.USD, multiplier: eurBuy / usdSell),
    ];
  }

  void applyRates({ required double usdBuy, required double usdSell, required double eurBuy, required double eurSell }) {
    currencyMappings = buildMappings(usdBuy: usdBuy, usdSell: usdSell, eurBuy: eurBuy, eurSell: eurSell);
  }
```

- [ ] **Step 3: Add the in-memory history field**

In `lib/services/utils.service.dart`, add an instance field next to `lastCurrencyMappingUpdate`:

```dart
  var lastCurrencyMappingUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  var rateHistory = <CurrencyRates>[];
```

- [ ] **Step 4: Add `loadRateHistory` and load it in `loadCachedMappings`**

Add the method:

```dart
  Future<void> loadRateHistory() async {
    await _databaseService.initialized;
    rateHistory = await _databaseService.currencyRatesRepository.findAllSorted();
  }
```

Then, inside `loadCachedMappings`, after the `if (cached != null) { ... }` block (still inside the `try`), add:

```dart
      await loadRateHistory();
```

- [ ] **Step 5: Refresh history after a successful fetch**

In `updateCurrencyMappings`, immediately after the `record(...)` call, add:

```dart
      await loadRateHistory();
```

- [ ] **Step 6: Add `convertCurrenciesAt` and `_resolveRatesAt`**

Add after `convertCurrencies`:

```dart
  double convertCurrenciesAt(double amount, Currency from, Currency to, DateTime date) {
    if (from == to) return amount;
    var rates = _resolveRatesAt(date);
    if (rates == null) return amount;
    var mappings = buildMappings(usdBuy: rates.usdBuy, usdSell: rates.usdSell, eurBuy: rates.eurBuy, eurSell: rates.eurSell);
    for (var mapping in mappings) {
      if (mapping.from == from && mapping.to == to) {
        return amount * mapping.multiplier;
      }
    }
    return amount;
  }

  CurrencyRates? _resolveRatesAt(DateTime date) {
    if (rateHistory.isEmpty) return null;
    CurrencyRates? resolved;
    for (var rates in rateHistory) {
      if (!rates.createdAt.isAfter(date)) {
        resolved = rates;
      } else {
        break;
      }
    }
    return resolved ?? rateHistory.first;
  }
```

- [ ] **Step 7: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/repositories/currency_rates.repository.dart lib/services/utils.service.dart
git commit -m "$(cat <<'EOF'
Add date-aware currency conversion with in-memory rate history

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Statistics use per-movement historical rates

Repository aggregations convert each movement into the requested display currency at its own `creationDate`; the category table's currency toggle re-queries instead of re-converting the aggregate.

**Files:**
- Modify: `lib/repositories/movements.repository.dart:177-206` (`getExpensesByCategory`), `:208-237` (`getExpensesByDay`)
- Modify: `lib/views/statistics/expenses_by_category.dart`
- Modify: `lib/views/statistics/expenses_by_day.dart:58`

**Interfaces:**
- Consumes: `convertCurrenciesAt` (Task 4).
- Produces: `getExpensesByCategory(Account? account, MovementType? movementType, DateTime? startDate, Currency displayCurrency)` and `getExpensesByDay(Account? account, MovementType? movementType, DateTime? startDate, Currency displayCurrency)`.

- [ ] **Step 1: Add `displayCurrency` to `getExpensesByCategory`**

In `lib/repositories/movements.repository.dart`, change the signature and the conversion line:

```dart
  Future<List<Map<String, Object?>>> getExpensesByCategory(Account? account, MovementType? movementType, DateTime? startDate, Currency displayCurrency) async {
```

and replace the ADD/REMOVE conversion inside the `fold`:

```dart
      if (movement.type == MovementType.ADD || movement.type == MovementType.REMOVE) {
        var movementAccount = movement.type == MovementType.ADD ? movement.target : movement.source;
        amount = utilsService.convertCurrenciesAt(movement.amount, movementAccount!.currency, displayCurrency, movement.creationDate!);
      } else {
        amount = movement.type == MovementType.TRANSFER ? movement.amount : movement.amount * movement.conversionRate!;
      }
```

- [ ] **Step 2: Add `displayCurrency` to `getExpensesByDay`**

Change the signature and the conversion line:

```dart
  Future<List<Map<String, Object?>>> getExpensesByDay(Account? account, MovementType? movementType, DateTime? startDate, Currency displayCurrency) async {
```

and replace the ADD/REMOVE conversion inside the `fold`:

```dart
      if (movement.type == MovementType.ADD || movement.type == MovementType.REMOVE) {
        var movementAccount = movement.type == MovementType.ADD ? movement.target : movement.source;
        amount = utilsService.convertCurrenciesAt(movement.amount, movementAccount!.currency, displayCurrency, movement.creationDate!);
      } else {
        amount = movement.type == MovementType.TRANSFER ? movement.amount : movement.amount * movement.conversionRate!;
      }
```

- [ ] **Step 3: Add a `displayCurrency` getter to the category chart**

In `lib/views/statistics/expenses_by_category.dart`, add this getter to `_ExpensesByCategoryChartState` (e.g. after the `viewModes` field):

```dart
  Currency get displayCurrency {
    return Currency.values.firstWhere((c) => c.toString() == viewMode, orElse: () => widget.account?.currency ?? Currency.USD);
  }
```

- [ ] **Step 4: Pass `displayCurrency` when querying**

In the same file, update the `getExpensesByCategory` call inside the state's `getExpensesByCategory()` method:

```dart
    var result = await databaseService.movementsRepository.getExpensesByCategory(widget.account, selectedMovementType, startDate, displayCurrency);
```

- [ ] **Step 5: Re-query on the currency toggle**

Replace the `GestureDetector`'s `onTap` in `buildTableRow` with (re-runs the query for the newly selected currency):

```dart
          onTap: () {
            setState(() {
              var currentIndex = viewModes.indexOf(viewMode);
              viewMode = viewModes[(currentIndex + 1) % viewModes.length];
            });
            getExpensesByCategory();
          },
```

- [ ] **Step 6: Stop re-converting the aggregate in the table**

The totals are already in the display currency, so drop the `convertCurrencies` call in `buildTableRow`. Replace the `else` branch:

```dart
    } else {
      var currency = Currency.values.firstWhere((currency) => currency.toString() == viewMode, orElse: () => widget.account?.currency ?? Currency.USD);
      text = utilsService.beautifyCurrency(total, currency);
    }
```

- [ ] **Step 7: Pass `displayCurrency` from the day chart**

In `lib/views/statistics/expenses_by_day.dart`, update the `getExpensesByDay` call:

```dart
    var result = await databaseService.movementsRepository.getExpensesByDay(widget.account, selectedMovementType, startDate, widget.account?.currency ?? Currency.USD);
```

- [ ] **Step 8: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 9: Manual verification**

Run: `flutter run`. On the statistics screen:
- Expenses-by-category table: toggling the currency cell cycles ARS → USD → EUR → PERCENT and the amounts update (a brief re-query).
- A movement created on a date with a different historical rate shows a different converted amount than it would at today's rate (if history has more than one row).
Stop the app afterward.

- [ ] **Step 10: Commit**

```bash
git add lib/repositories/movements.repository.dart lib/views/statistics/expenses_by_category.dart lib/views/statistics/expenses_by_day.dart
git commit -m "$(cat <<'EOF'
Convert statistics per movement at historical rates

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Movements list uses the historical rate

**Files:**
- Modify: `lib/views/home/movements_list.dart:129-141` (`amount` getter)

**Interfaces:**
- Consumes: `convertCurrenciesAt` (Task 4).

- [ ] **Step 1: Convert at the movement's creation date**

In `lib/views/home/movements_list.dart`, change the last line of the `amount` getter from `convertCurrencies` to:

```dart
    var utilsService = GetIt.instance.get<UtilsService>();
    return utilsService.convertCurrenciesAt(amountOnTarget, currencyFrom, currency, movement.creationDate ?? DateTime.now());
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Manual verification**

Run: `flutter run`. On an account tab whose display currency differs from a movement's currency, the listed amount reflects the movement's date-rate (differs from today's rate when history has multiple rows). Stop the app afterward.

- [ ] **Step 4: Commit**

```bash
git add lib/views/home/movements_list.dart
git commit -m "$(cat <<'EOF'
Convert movement list amounts at historical rates

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Refresh rates when the movement dialog opens

Fire a throttled, unawaited `updateCurrencyMappings()` on dialog open so the freshest rate is recorded by the time the user saves.

**Files:**
- Modify: `lib/views/movements/new_movement.dialog.dart:60-67` (`initState`)

**Interfaces:**
- Consumes: `updateCurrencyMappings` (existing, throttled).

- [ ] **Step 1: Trigger the throttled refresh in `initState`**

In `lib/views/movements/new_movement.dialog.dart`, add the unawaited call at the end of `initState`:

```dart
  @override
  void initState() {
    super.initState();
    creationDate = DateTime.now();
    getCategories();
    watchCategories();
    getAccounts();
    utilsService.updateCurrencyMappings();
  }
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: `No issues found!` (an unawaited `Future` on a fire-and-forget refresh is acceptable here; if `flutter analyze` flags `unawaited_futures`, wrap with `unawaited(...)` from `dart:async` and add the import).

- [ ] **Step 3: Manual verification**

Run: `flutter run`, open the new-movement dialog. Logs show `Updating currency mappings` at most once per hour (throttled). Stop the app afterward.

- [ ] **Step 4: Commit**

```bash
git add lib/views/movements/new_movement.dialog.dart
git commit -m "$(cat <<'EOF'
Refresh currency rates when opening the movement dialog

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Documentation

Update the feature docs in the same change (docs-maintenance rule).

**Files:**
- Modify: `docs/features/currency.md`
- Modify: `docs/features/statistics.md`
- Modify: `docs/features/movements.md`
- Modify: `docs/migrations.md`

- [ ] **Step 1: Update `docs/features/currency.md`**

In the "Mechanics" section, document that `currency_rates` is now an append-on-change **history** table (`createdAt` + `updatedAt`; a new row only when a value changes, else `updatedAt` is bumped via `record`), that `UtilsService` keeps an in-memory `rateHistory` (loaded in `loadCachedMappings`, refreshed after each fetch), and that `convertCurrenciesAt(amount, from, to, date)` resolves the applicable row (latest `createdAt <= date`; else earliest; else 1:1 defaults). Note that `convertCurrencies` (live) remains for balances/totals. Update the "Edge cases / debt" notes accordingly.

- [ ] **Step 2: Update `docs/features/statistics.md`**

In "Cross-currency aggregation", document that each movement is converted into the chosen `displayCurrency` at its own `creationDate`, and that the expenses-by-category currency toggle re-queries per display currency (no aggregate re-conversion). Note `getExpensesByCategory`/`getExpensesByDay` now take a `displayCurrency` argument.

- [ ] **Step 3: Update `docs/features/movements.md`**

Note that display/aggregation conversions of a movement's amount are date-based (via `convertCurrenciesAt`), and that opening the new/edit movement dialog triggers a throttled background rate refresh.

- [ ] **Step 4: Update `docs/migrations.md`**

Add `add_created_at_to_currency_rates` to the narrative as the latest migration (column add + backfill of `createdAt` from `updatedAt`), following the existing recipe/idempotency description.

- [ ] **Step 5: Verify links/build**

Run: `flutter analyze`
Expected: `No issues found!` (docs-only change; confirms nothing else regressed).

- [ ] **Step 6: Commit**

```bash
git add docs/features/currency.md docs/features/statistics.md docs/features/movements.md docs/migrations.md
git commit -m "$(cat <<'EOF'
Document movement historical exchange rates

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```
