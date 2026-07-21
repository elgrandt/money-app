# Direction-based buy/sell exchange rates — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the app's currency engine from a single `value_buy` rate to direction-based buy/sell rates (sell when acquiring foreign currency, buy when disposing), and derive USD↔EUR through ARS.

**Architecture:** The persisted single-row `currency_rates` cache changes from 3 values (`usdToArs`, `eurToArs`, `eurToUsd`) to 4 (`usdBuy`, `usdSell`, `eurBuy`, `eurSell`). `UtilsService.applyRates` rebuilds the 6 pairwise multipliers from those 4 values; `convertCurrencies` and the mapping-lookup mechanism are unchanged. A drop-and-recreate migration swaps the schema. The dashboard shows compra/venta per currency read straight from the cached row.

**Tech Stack:** Flutter / Dart 3 (`>=3.2.2`), `sqflite`, `get_it`, `http`, `intl`.

## Global Constraints

- **No tests** — the project has no test suite by policy. Each task is verified with `flutter analyze` (must report no new issues) plus a final manual run; there are **no** `flutter test` steps and no test files.
- **Language:** code + logs in English, UI strings in Spanish (`es_AR`).
- **Imports at top of file** — never inline/fully-qualified references.
- **Enums stored as `TEXT` via `.name`** (unchanged here; no new enum).
- **Git:** work on branch `feature/sell-exchange-rates` (already created). Never commit to `master`. Commit after each task.
- **Bluelytics source quotes:** use `blue` (USD) and `blue_euro` (EUR) only — not `oficial`.
- **Semantics (verbatim):** ARS→USD `= 1/usdSell`; ARS→EUR `= 1/eurSell`; USD→ARS `= usdBuy`; EUR→ARS `= eurBuy`; USD→EUR `= usdBuy/eurSell`; EUR→USD `= eurBuy/usdSell`.

---

## File Structure

- `lib/models/currency_rates.model.dart` — **modify**: 4 rate fields instead of 3.
- `lib/repositories/currency_rates.repository.dart` — **modify**: columns + map methods.
- `lib/migrations/rebuild_currency_rates_buy_sell.migration.dart` — **create**: drop + recreate table.
- `lib/migrations/migrations_list.dart` — **modify**: register the migration.
- `lib/services/utils.service.dart` — **modify**: `applyRates`, `loadCachedMappings`, `updateCurrencyMappings`.
- `lib/views/home/exchange_rates.dart` — **modify**: compra/venta display.
- `docs/features/currency.md`, `docs/tech-debt.md` — **modify**: docs sync.

Tasks 1 is the compile-coupled data+service core (model, repo, migration, service must change together to stay `analyze`-clean, since the service references the model's field names). Task 2 is the view. Task 3 is docs.

---

### Task 1: Data layer + currency service (buy/sell core)

**Files:**
- Modify: `lib/models/currency_rates.model.dart`
- Modify: `lib/repositories/currency_rates.repository.dart`
- Create: `lib/migrations/rebuild_currency_rates_buy_sell.migration.dart`
- Modify: `lib/migrations/migrations_list.dart`
- Modify: `lib/services/utils.service.dart`

**Interfaces:**
- Consumes: `CurrencyMapping`, `Currency` (ARS/USD/EUR), `BaseModel`, `BaseRepository`, `DatabaseColumnDefinition`, `initializeTable()`, `MigrationDefinition`.
- Produces:
  - `CurrencyRates({ required double usdBuy, required double usdSell, required double eurBuy, required double eurSell, required DateTime updatedAt, int? id })` with public fields `usdBuy, usdSell, eurBuy, eurSell, updatedAt`.
  - `UtilsService.applyRates({ required double usdBuy, required double usdSell, required double eurBuy, required double eurSell })`.
  - Table `currency_rates` columns: `id, usdBuy, usdSell, eurBuy, eurSell, updatedAt`.

- [ ] **Step 1: Rewrite the model**

Replace the entire body of `lib/models/currency_rates.model.dart` with:

```dart
import 'package:money/models/base.model.dart';

class CurrencyRates extends BaseModel {
  double usdBuy;
  double usdSell;
  double eurBuy;
  double eurSell;
  DateTime updatedAt;

  CurrencyRates({ required this.usdBuy, required this.usdSell, required this.eurBuy, required this.eurSell, required this.updatedAt, super.id });

  @override
  String toString() {
    return 'usdBuy=$usdBuy usdSell=$usdSell eurBuy=$eurBuy eurSell=$eurSell (updatedAt=$updatedAt)';
  }
}
```

- [ ] **Step 2: Update the repository columns and map methods**

In `lib/repositories/currency_rates.repository.dart`, replace the `currencyRatesColumns` list, `modelToMap`, and `mapToModel` so the file reads:

```dart
import 'package:money/models/currency_rates.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:sqflite/sqflite.dart';

class CurrencyRatesRepository extends BaseRepository<CurrencyRates> {
  static List<DatabaseColumnDefinition> currencyRatesColumns = [
    DatabaseColumnDefinition('id', DatabaseColumnType.INTEGER, primaryKey: PrimaryKeyDefinition(autoincrement: true)),
    DatabaseColumnDefinition('usdBuy', DatabaseColumnType.REAL),
    DatabaseColumnDefinition('usdSell', DatabaseColumnType.REAL),
    DatabaseColumnDefinition('eurBuy', DatabaseColumnType.REAL),
    DatabaseColumnDefinition('eurSell', DatabaseColumnType.REAL),
    DatabaseColumnDefinition('updatedAt', DatabaseColumnType.DATE),
  ];

  CurrencyRatesRepository(Database db): super(db, 'currency_rates', CurrencyRatesRepository.currencyRatesColumns);

  @override
  Map<String, Object?> modelToMap(CurrencyRates model) {
    var map = <String, Object?>{};
    if (model.id != null) {
      map['id'] = model.id;
    }
    map['usdBuy'] = model.usdBuy;
    map['usdSell'] = model.usdSell;
    map['eurBuy'] = model.eurBuy;
    map['eurSell'] = model.eurSell;
    map['updatedAt'] = model.updatedAt.toIso8601String();
    return map;
  }

  @override
  CurrencyRates mapToModel(Map<String, Object?> map) {
    return CurrencyRates(
      usdBuy: map['usdBuy'] as double,
      usdSell: map['usdSell'] as double,
      eurBuy: map['eurBuy'] as double,
      eurSell: map['eurSell'] as double,
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

- [ ] **Step 3: Create the migration**

Create `lib/migrations/rebuild_currency_rates_buy_sell.migration.dart`:

```dart
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/migrations/migration_definition.dart';
import 'package:money/services/database.service.dart';

var logger = GetIt.instance.get<Logger>();

var rebuildCurrencyRatesBuySellMigration = MigrationDefinition(
  'rebuild_currency_rates_buy_sell',
  () async {
    var databaseService = GetIt.instance.get<DatabaseService>();
    await databaseService.db.execute('DROP TABLE IF EXISTS currency_rates');
    await databaseService.currencyRatesRepository.initializeTable();
  }, () async {
    logger.e('Cannot down this migration');
  }
);
```

- [ ] **Step 4: Register the migration (append at end — order matters)**

In `lib/migrations/migrations_list.dart`, add the import (alphabetical with the others) and append the definition to the end of `migrationDefinitions`:

```dart
import 'package:money/migrations/accounts_initialization.migration.dart';
import 'package:money/migrations/add_deleted_field_to_account.migration.dart';
import 'package:money/migrations/add_sort_index_field_to_account.migration.dart';
import 'package:money/migrations/add_showTotal_field_to_account.migration.dart';
import 'package:money/migrations/categories_initialization.migration.dart';
import 'package:money/migrations/currency_rates_initialization.migration.dart';
import 'package:money/migrations/example.migration.dart';
import 'package:money/migrations/migration_definition.dart';
import 'package:money/migrations/movements_initialization.migration.dart';
import 'package:money/migrations/rebuild_currency_rates_buy_sell.migration.dart';

List<MigrationDefinition> migrationDefinitions = [
  exampleMigration,
  accountsInitializationMigration,
  movementsInitializationMigration,
  categoriesInitializationMigration,
  addSortIndexFieldToAccountMigration,
  addShowTotalFieldToAccountMigration,
  addDeletedFieldToAccountMigration,
  currencyRatesInitializationMigration,
  rebuildCurrencyRatesBuySellMigration,
];
```

- [ ] **Step 5: Update `applyRates` in `lib/services/utils.service.dart`**

Replace the existing `applyRates` method (currently at [:55-64](../../../lib/services/utils.service.dart#L55-L64)) with:

```dart
  void applyRates({ required double usdBuy, required double usdSell, required double eurBuy, required double eurSell }) {
    currencyMappings = [
      CurrencyMapping(from: Currency.ARS, to: Currency.EUR, multiplier: 1 / eurSell),
      CurrencyMapping(from: Currency.ARS, to: Currency.USD, multiplier: 1 / usdSell),
      CurrencyMapping(from: Currency.USD, to: Currency.ARS, multiplier: usdBuy),
      CurrencyMapping(from: Currency.USD, to: Currency.EUR, multiplier: usdBuy / eurSell),
      CurrencyMapping(from: Currency.EUR, to: Currency.ARS, multiplier: eurBuy),
      CurrencyMapping(from: Currency.EUR, to: Currency.USD, multiplier: eurBuy / usdSell),
    ];
  }
```

- [ ] **Step 6: Update `loadCachedMappings` call site**

In the same file, replace the `applyRates(...)` call inside `loadCachedMappings` (currently [:71](../../../lib/services/utils.service.dart#L71)) with:

```dart
        applyRates(usdBuy: cached.usdBuy, usdSell: cached.usdSell, eurBuy: cached.eurBuy, eurSell: cached.eurSell);
```

- [ ] **Step 7: Update `updateCurrencyMappings`**

Replace the body between fetching `body` and the success log (currently [:89-98](../../../lib/services/utils.service.dart#L89-L98)) so it reads the four quotes and persists them (removing the `1.11` constant):

```dart
      double usdBuy = body['blue']['value_buy'];
      double usdSell = body['blue']['value_sell'];
      double eurBuy = body['blue_euro']['value_buy'];
      double eurSell = body['blue_euro']['value_sell'];
      applyRates(usdBuy: usdBuy, usdSell: usdSell, eurBuy: eurBuy, eurSell: eurSell);
      await _databaseService.currencyRatesRepository.saveLatest(CurrencyRates(
        usdBuy: usdBuy,
        usdSell: usdSell,
        eurBuy: eurBuy,
        eurSell: eurSell,
        updatedAt: DateTime.now(),
      ));
```

(The seed `currencyMappings` list at [:34-41](../../../lib/services/utils.service.dart#L34-L41) stays at `multiplier: 1` — no change.)

- [ ] **Step 8: Analyze**

Run: `flutter analyze`
Expected: no new errors/warnings (specifically no references to `usdToArs`, `eurToArs`, or `eurToUsd` remain — grep to confirm: `grep -rn "usdToArs\|eurToArs\|eurToUsd" lib/` returns nothing).

- [ ] **Step 9: Commit**

```bash
git add lib/models/currency_rates.model.dart lib/repositories/currency_rates.repository.dart lib/migrations/rebuild_currency_rates_buy_sell.migration.dart lib/migrations/migrations_list.dart lib/services/utils.service.dart
git commit -m "Rebuild currency mappings with direction-based buy/sell rates

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Dashboard compra/venta display

**Files:**
- Modify: `lib/views/home/exchange_rates.dart`

**Interfaces:**
- Consumes: `latestRates` (`CurrencyRates?`) with fields `usdBuy/usdSell/eurBuy/eurSell` from Task 1; `utilsService.beautifyCurrency`, `utilsService.getCurrencyIcon`; `Currency`.
- Produces: none (leaf view).

- [ ] **Step 1: Add a `(buy, sell)` accessor**

In `_ExchangeRatesTableState` (in `lib/views/home/exchange_rates.dart`), add this method (e.g. just above `build`):

```dart
  (double, double)? ratesFor(Currency currency) {
    if (latestRates == null) return null;
    switch (currency) {
      case Currency.USD:
        return (latestRates!.usdBuy, latestRates!.usdSell);
      case Currency.EUR:
        return (latestRates!.eurBuy, latestRates!.eurSell);
      case Currency.ARS:
        return null;
    }
  }
```

- [ ] **Step 2: Render compra/venta in `buildRateRow`**

Replace the current `buildRateRow` body (currently [:92-112](../../../lib/views/home/exchange_rates.dart#L92-L112)) with a version that reads the pair and formats `compra/venta`:

```dart
  TableRow buildRateRow(BuildContext context, Currency currency) {
    var pair = ratesFor(currency);
    var text = pair == null
      ? '—/—'
      : '${ utilsService.beautifyCurrency(pair.$1, Currency.ARS) }/${ utilsService.beautifyCurrency(pair.$2, Currency.ARS) }';
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              utilsService.getCurrencyIcon(currency),
              const SizedBox(width: 10),
              Text(currency.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.end),
        ),
      ],
    );
  }
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: no new errors/warnings. (The `utils.service.dart` import remains used via `utilsService`; no unused-import warning.)

- [ ] **Step 4: Commit**

```bash
git add lib/views/home/exchange_rates.dart
git commit -m "Show compra/venta rates on the dashboard exchange table

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Documentation sync

**Files:**
- Modify: `docs/features/currency.md`
- Modify: `docs/tech-debt.md`

**Interfaces:** none (docs only).

- [ ] **Step 1: Update `docs/features/currency.md` Mechanics**

Rewrite the "Mechanics" bullets that describe the mappings so they reflect buy/sell. Replace the `updateCurrencyMappings()` bullet and the persisted-fields bullet with descriptions matching the new behavior:

- `applyRates(...)` now takes four values (`usdBuy`, `usdSell`, `eurBuy`, `eurSell`) and builds the six multipliers direction-based: ARS→foreign uses `1/…Sell`, foreign→ARS uses `…Buy`, and USD↔EUR is derived through ARS (`usdBuy/eurSell`, `eurBuy/usdSell`).
- `updateCurrencyMappings()` fetches `blue.value_buy`/`blue.value_sell` and `blue_euro.value_buy`/`blue_euro.value_sell`.
- The `currency_rates` table stores `usdBuy, usdSell, eurBuy, eurSell` + `updatedAt`.

Update the `exchange_rates.dart` bullet under "Views involved" to say it shows **compra/venta** per currency (`value_buy`/`value_sell`, e.g. `$1.504/$1.538`) read from `currencyRatesRepository.findLatest`, falling back to `—/—` before the first cached row exists.

Under "Edge cases / debt", **remove** the "EUR↔USD is hardcoded at 1.11" bullet and instead note that USD↔EUR is derived through ARS from the blue rates.

- [ ] **Step 2: Update `docs/tech-debt.md`**

Remove the bullet (currently [:36-38](../../tech-debt.md#L36-L38)):

```markdown
- Hardcoded `eurToUsd = 1.11` in
  [utils.service.dart](../lib/services/utils.service.dart) `updateCurrencyMappings` — no
  EUR→USD API was found at the time; revisit later.
```

- [ ] **Step 3: Commit**

```bash
git add docs/features/currency.md docs/tech-debt.md
git commit -m "Docs: buy/sell exchange rates, retire 1.11 EUR-USD debt

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Manual verification

**Files:** none.

- [ ] **Step 1: Run the app**

Run: `flutter run` (on an emulator/device). While online, open the dashboard.

- [ ] **Step 2: Verify behavior**

Confirm:
- "Tasas de cambio" shows two values per currency (e.g. `$1.504/$1.538`), compra first, and they differ.
- Account totals converted between currencies use the sell rate when going ARS→USD/EUR and the buy rate when going USD/EUR→ARS (spot-check one account total).
- No console errors on startup (the migration drops + recreates `currency_rates` without error).
- Kill and relaunch **offline**: rates persist (compra/venta still shown from the cached row).

---

## Notes for the executor

- **No test files** — do not add `flutter test` steps; this project has no tests by policy.
- **JSON number typing:** assigning `body['blue']['value_sell']` (a JSON num) to a `double` matches the pre-existing pattern for `value_buy`; the example payload has decimal values (`1502.0`). If bluelytics ever returns an integer literal, that assignment would throw — but this mirrors the existing code and is out of scope to harden here.
- **Upgrade caveat (expected, not a bug):** a user offline at the moment of upgrade loses the cached row (drop/recreate) and sees 1:1 until the next online launch — documented trade-off.
