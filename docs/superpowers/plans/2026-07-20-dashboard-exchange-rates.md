# Dashboard "Tasas de cambio" Section Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Tasas de cambio" section to the home dashboard, between "Movimientos por categoría" and "Movimientos por día", showing the current USD and EUR rates against the peso as a table plus the last-update timestamp.

**Architecture:** A new stateful widget `ExchangeRatesTable` ([lib/views/home/exchange_rates.dart](../../../lib/views/home/exchange_rates.dart)) reads live rates from `UtilsService.convertCurrencies` and the last-update timestamp from `CurrencyRatesRepository.findLatest`, refreshing via the repository's `'change'` event. The stateless `Dashboard` composes it with a titled, `Divider`-separated block like its sibling sections.

**Tech Stack:** Flutter / Dart, `get_it` DI, `sqflite`, `events_emitter`, `intl` (`DateFormat`).

## Global Constraints

- **No tests.** This project has no tests by policy (CLAUDE.md). Verification is `flutter analyze` (must report **no** new issues) plus a manual dashboard check. Do **not** add test files.
- **Language:** code + logs in English; UI strings in Spanish (`es_AR`).
- **Imports at top of file** — never inline/fully-qualified references.
- **Never commit to `master`.** Work is on branch `feature/dashboard-exchange-rates` (already created and checked out). Confirm with `git branch --show-current` before each commit.
- **Enums stored/displayed** use `.name` (e.g. `Currency.USD.name` → `"USD"`).
- **Money formatting** always via `UtilsService.beautifyCurrency`.
- **Docs-maintenance rule:** documentation-worthy changes update the relevant doc in the same change (Task 2).
- **Commit trailer** on every commit:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

---

### Task 1: Create the `ExchangeRatesTable` widget

**Files:**
- Create: `lib/views/home/exchange_rates.dart`

**Interfaces:**
- Consumes (all existing):
  - `GetIt.instance.get<DatabaseService>()` → `.currencyRatesRepository.findLatest()` → `Future<CurrencyRates?>`; `.currencyRatesRepository.events` (`EventEmitter`); `.initialized` (`Future`).
  - `GetIt.instance.get<UtilsService>()` → `convertCurrencies(double, Currency, Currency)` → `double`; `beautifyCurrency(double, Currency)` → `String`; `getCurrencyIcon(Currency)` → `Widget`.
  - `Currency` enum (`ARS`/`USD`/`EUR`) from `package:money/models/account.model.dart`.
  - `CurrencyRates` model (`.updatedAt` is `DateTime`) from `package:money/models/currency_rates.model.dart`.
  - `TableUpdateEvent<Model>` from `package:money/repositories/base.repository.dart`; `EventListener` from `package:events_emitter/events_emitter.dart`.
- Produces: `class ExchangeRatesTable extends StatefulWidget` with `const ExchangeRatesTable({ super.key })` — consumed by Task 2.

- [ ] **Step 1: Create the widget file**

Create `lib/views/home/exchange_rates.dart` with exactly this content:

```dart
import 'dart:async';
import 'package:events_emitter/events_emitter.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/currency_rates.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';

class ExchangeRatesTable extends StatefulWidget {
  const ExchangeRatesTable({ super.key });

  @override
  State<ExchangeRatesTable> createState() => _ExchangeRatesTableState();
}

class _ExchangeRatesTableState extends State<ExchangeRatesTable> {
  var databaseService = GetIt.instance.get<DatabaseService>();
  var utilsService = GetIt.instance.get<UtilsService>();
  var logger = GetIt.instance.get<Logger>();
  EventListener<TableUpdateEvent<CurrencyRates>>? ratesListener;
  CurrencyRates? latestRates;
  bool loaded = false;

  final List<Currency> currencies = [Currency.USD, Currency.EUR];

  @override
  void initState() {
    super.initState();
    loadLatestRates();
    watchRatesChanges();
  }

  @override
  void dispose() {
    super.dispose();
    ratesListener?.cancel();
  }

  Future<void> watchRatesChanges() async {
    await databaseService.initialized;
    ratesListener = databaseService.currencyRatesRepository.events.on<TableUpdateEvent<CurrencyRates>>('change', (event) {
      logger.d('Currency rates change: $event');
      loadLatestRates();
    });
  }

  Future<void> loadLatestRates() async {
    await databaseService.initialized;
    try {
      var rates = await databaseService.currencyRatesRepository.findLatest();
      if (!mounted) return;
      setState(() {
        latestRates = rates;
        loaded = true;
      });
    } catch (error, stackTrace) {
      logger.e('Error loading currency rates', error: error, stackTrace: stackTrace);
    }
  }

  String lastUpdateText() {
    if (!loaded) return '—';
    if (latestRates == null) return 'Nunca';
    return DateFormat('dd/MM/yyyy HH:mm').format(latestRates!.updatedAt);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: IntrinsicColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: currencies.map((currency) => buildRateRow(context, currency)).toList(),
          ),
          const SizedBox(height: 15),
          Text('Última actualización: ${ lastUpdateText() }', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  TableRow buildRateRow(BuildContext context, Currency currency) {
    var rate = utilsService.convertCurrencies(1, currency, Currency.ARS);
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
          child: Text(utilsService.beautifyCurrency(rate, Currency.ARS), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze lib/views/home/exchange_rates.dart`
Expected: "No issues found!" (or no issues for this file).

- [ ] **Step 3: Commit**

```bash
git branch --show-current   # must print: feature/dashboard-exchange-rates
git add lib/views/home/exchange_rates.dart
git commit -m "$(cat <<'EOF'
Add ExchangeRatesTable widget for dashboard

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Wire the section into the dashboard and update docs

**Files:**
- Modify: `lib/views/home/dashboard.dart` (add import; add `buildExchangeRates`; insert block in `build`)
- Modify: `docs/features/currency.md` (add view to "Views involved")
- Modify: `docs/features/statistics.md` (note new dashboard section)

**Interfaces:**
- Consumes: `ExchangeRatesTable` (`const ExchangeRatesTable()`) from Task 1.
- Produces: final feature — no downstream consumers.

- [ ] **Step 1: Add the import to `dashboard.dart`**

In [lib/views/home/dashboard.dart](../../../lib/views/home/dashboard.dart), add this import alongside the existing `import 'package:money/views/...'` lines (keep alphabetical grouping with the other `home` import):

```dart
import 'package:money/views/home/exchange_rates.dart';
```

- [ ] **Step 2: Add the `buildExchangeRates` method**

In the same file, add this method after `buildExpensesByCategoryChart` (immediately before `buildExpensesByDayChart`):

```dart
  Widget buildExchangeRates(BuildContext context) {
    return const Column(
      key: Key('exchange-rates'),
      children: [
        Text('Tasas de cambio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        SizedBox(height: 20),
        ExchangeRatesTable(),
      ],
    );
  }
```

- [ ] **Step 3: Insert the section block in `build`**

In the `build` method's `Column` children, replace this fragment:

```dart
          buildExpensesByCategoryChart(context),
          const SizedBox(height: 15),
          const Divider(),
          const SizedBox(height: 15),
          buildExpensesByDayChart(context),
```

with:

```dart
          buildExpensesByCategoryChart(context),
          const SizedBox(height: 15),
          const Divider(),
          const SizedBox(height: 15),
          buildExchangeRates(context),
          const SizedBox(height: 15),
          const Divider(),
          const SizedBox(height: 15),
          buildExpensesByDayChart(context),
```

- [ ] **Step 4: Run static analysis**

Run: `flutter analyze`
Expected: no new issues (same baseline as before the change).

- [ ] **Step 5: Update `docs/features/currency.md`**

In the "Views involved" section of [docs/features/currency.md](../../features/currency.md), add a bullet after the `currency_selector.dart` bullet:

```markdown
- [exchange_rates.dart](../../lib/views/home/exchange_rates.dart) — the dashboard's "Tasas de
  cambio" table: current USD/EUR rates against ARS (via `convertCurrencies(1, …, ARS)`) plus the
  last-update timestamp from `currencyRatesRepository.findLatest` (shows `Nunca` when no row
  exists yet). Refreshes on the repository's `change` event.
```

- [ ] **Step 6: Update `docs/features/statistics.md`**

In [docs/features/statistics.md](../../features/statistics.md), update the `dashboard.dart` bullet in "Views involved" to mention the new section. Replace:

```markdown
- [dashboard.dart](../../lib/views/home/dashboard.dart) — composes total, totals pie, latest
  movements, and both charts.
```

with:

```markdown
- [dashboard.dart](../../lib/views/home/dashboard.dart) — composes total, totals pie, latest
  movements, both charts, and the "Tasas de cambio" table (between the category and day charts).
```

- [ ] **Step 7: Manual verification**

Run: `flutter run`
Confirm on the home dashboard: a "Tasas de cambio" section appears between "Movimientos por categoría" and "Movimientos por día", showing USD and EUR rows (currency icon + name on the left, an ARS amount like `$1.400` on the right) and an "Última actualización: …" line (a `dd/MM/yyyy HH:mm` timestamp, or `Nunca` if rates have never been fetched).

- [ ] **Step 8: Commit**

```bash
git branch --show-current   # must print: feature/dashboard-exchange-rates
git add lib/views/home/dashboard.dart docs/features/currency.md docs/features/statistics.md
git commit -m "$(cat <<'EOF'
Add "Tasas de cambio" section to dashboard

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:**
- Section titled "Tasas de cambio" between the two charts → Task 2 Steps 2-3. ✓
- USD/EUR rows with ARS values via live mappings → Task 1 `buildRateRow` (`convertCurrencies(1, …, ARS)` + `beautifyCurrency`). ✓
- Icon + name rows (approved decision) → Task 1 `buildRateRow` (`getCurrencyIcon` + `currency.name`). ✓
- "Última actualización: DD/MM/YYYY HH:mm" → Task 1 `lastUpdateText` (`DateFormat('dd/MM/yyyy HH:mm')`). ✓
- Always renders; timestamp `Nunca` when no row; `—` while loading → Task 1 `lastUpdateText`. ✓
- Refresh on rate update → Task 1 `watchRatesChanges` (`'change'` event). ✓
- Docs updated same change → Task 2 Steps 5-6. ✓
- No model/repo/migration/DB change → confirmed (Task 1 & 2 touch only views + docs). ✓

**Placeholder scan:** No TBD/TODO; all code and doc edits are shown in full. The `—` and `Nunca`/date strings are literal, intended UI values, not placeholders. ✓

**Type consistency:** `ExchangeRatesTable` (const, keyed) defined in Task 1 and used identically in Task 2; `EventListener<TableUpdateEvent<CurrencyRates>>`, `CurrencyRates.updatedAt` (`DateTime`), and `UtilsService` method signatures match the codebase confirmed during design. ✓
