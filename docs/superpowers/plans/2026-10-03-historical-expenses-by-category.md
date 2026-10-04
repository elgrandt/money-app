# Historical Expenses by Category Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Gastos por categoría históricos" chart to Statistics: a daily-granularity line chart with one line per category, a currency selector, a period selector, and a toggleable category list.

**Architecture:** A new repository method `getExpensesByCategoryByDay` returns, per category, a fixed-length list of daily totals (zeros where no spending). A new view `HistoricalExpensesByCategoryChart` renders selectors, an `fl_chart` `LineChart` (day selection via a vertical line, no tooltip) and a category list that toggles lines and shows the selected day's amounts. A `UtilsService.dayIndex` helper counts calendar days without DST drift.

**Tech Stack:** Flutter 3.27 / Dart 3.6, `sqflite`, `get_it`, `intl`, `fl_chart` 0.70.0.

**Spec:** [2026-10-03-historical-expenses-by-category-design.md](../specs/2026-10-03-historical-expenses-by-category-design.md)

## Global Constraints

- **Language:** code identifiers, logs and plans in English; UI strings in Spanish (`es_AR`). Chat with the user in Spanish.
- **No tests by policy:** do not create test files. Verification = `flutter analyze` (baseline before this work: **24 issues**, all pre-existing; this work must add none) + manual check with `flutter run` + throwaway scripts under `/tmp` (never committed).
- **Git:** never commit to `master`; work on `feature/historical-expenses-by-category` (already created, confirm with `git branch --show-current` before each commit). Commit messages: imperative, capitalized, no type prefix, ~50 chars. End each commit message with `Co-Authored-By: Claude Code <noreply@anthropic.com>`.
- **Code style ([coding-style.md](../../coding-style.md)):** 2-space indent, single quotes, no leading blank line, no blank lines between imports, `${ expr }` with inner spaces, `{ a, b }` brace spacing when more than one named param, **no code comments**, member order attributes → getters → constructor → lifecycle → logic → `build` → `buildX`, no inline record types, don't cache a getter in a local just to avoid recomputing, **short methods** (one `buildX` per child of a long widget chain; chart data pieces as getters) and **no magic numbers**: sizes, seeds, option lists and styles repeated or meaningful go in named fields.
- **Java rule from global CLAUDE.md does not apply** (Dart project). Imports always at the top of the file.
- **Dates:** a movement's day is its *local* calendar day (`year`/`month`/`day` of the local `creationDate`); never call `toUtc()` on `creationDate`. Date SQL params use `toIso8601String()` (stored format), not `toString()`.
- **Copy (exact):** chart option `Gastos por categoría históricos`; periods `3 meses`, `6 meses`, `1 año`, `Custom`; buttons `Habilitar todas`, `Deshabilitar todas`, `Quitar selección`; messages `No hay datos`, `No hay categorías seleccionadas`.
- **Docs-in-sync:** update `docs/features/statistics.md` in the same change. `docs/data-layer.md` (typed query results) and `docs/tech-debt.md` are already updated.
- **Typed results:** repository aggregates return a named class, never `Map<String, Object?>` (see "Typed query results" in `docs/data-layer.md`). Existing map-returning methods are recorded as debt and are not touched.
- **Meta-rule:** if something is not covered by the spec or an existing pattern, stop and ask.

## Review Focus

- A movement at 23:30 local on the **last** day of the period must be included (this is exactly where the existing `toString()`-vs-`toIso8601String()` filter bug bites); the new query uses an exclusive bound on the next midnight. Pinned in Task 2 Step 4.
- A movement at 00:30 local on the **first** day lands in index 0, and a movement at 23:30 local keeps its own day. Pinned in Task 1 Step 2 and Task 2 Step 4.
- A period crossing a DST change must not lose or duplicate a day. Pinned in Task 1 Step 2.
- A single-day `Custom` range (start day == end day → 1 point per line) must not crash the chart. Pinned in Task 2 Step 4.
- An account/period with no expenses shows `No hay datos` and still shows the selectors; all categories disabled shows `No hay categorías seleccionadas`. Pinned in Task 2 Step 4.
- Switching account resets the currency to the account's currency but keeps period and disabled categories. Pinned in Task 2 Step 4.

---

### Task 1: Data layer — `UtilsService.dayIndex` and `getExpensesByCategoryByDay`

**Files:**
- Modify: `lib/services/utils.service.dart` (add `dayIndex` before `beautifyCurrency`, currently line 157)
- Modify: `lib/repositories/movements.repository.dart` (declare `CategoryDailyExpenses` above `MovementsRepository`; append the method at the end of the class, after `getExpensesByDay`)
- Modify: `docs/data-layer.md` and `docs/tech-debt.md` (already edited in the working tree: the "Typed query results" pattern and the debt entry)
- Commit also (already in working tree, uncommitted): `docs/superpowers/specs/2026-10-03-historical-expenses-by-category-design.md`, `docs/tech-debt.md`, this plan.

**Interfaces:**
- Consumes: `UtilsService.convertCurrenciesAt(double, Currency, Currency, DateTime)`, `BaseRepository.find({ where, args })`, `Movement.source` / `.category` / `.amount` / `.creationDate`.
- Produces:
  - `int UtilsService.dayIndex(DateTime startDate, DateTime date)` — number of calendar days from `startDate`'s day to `date`'s day (local components, DST-safe).
  - `class CategoryDailyExpenses { final String category; final List<double> dailyTotals; double get total; }` — plain immutable class declared in `movements.repository.dart` (pattern: "Typed query results" in `docs/data-layer.md`).
  - `Future<List<CategoryDailyExpenses>> MovementsRepository.getExpensesByCategoryByDay(Account? account, DateTime startDate, DateTime endDate, Currency displayCurrency)` — one item per category with spending; every `dailyTotals` has length `dayIndex(startDate, endDate) + 1`.

- [ ] **Step 1: Commit the spec, tech-debt note and plan**

```bash
git branch --show-current
git add docs/superpowers/specs/2026-10-03-historical-expenses-by-category-design.md docs/tech-debt.md docs/data-layer.md docs/superpowers/plans/2026-10-03-historical-expenses-by-category.md
git commit -m "$(cat <<'EOF'
Add design spec and plan for historical expenses chart

Also documents the typed query results pattern in data-layer and
records the date-filter mismatch and the untyped statistics queries in
tech-debt.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

Expected: branch is `feature/historical-expenses-by-category`; commit succeeds.

- [ ] **Step 2: Verify the `dayIndex` logic with a throwaway script (fails first on the naive version)**

Create `/tmp/day_index_check.dart`:

```dart
int dayIndex(DateTime startDate, DateTime date) {
  return DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(startDate.year, startDate.month, startDate.day))
      .inDays;
}

void main() {
  var start = DateTime(2026, 3, 7);
  print('naive across US DST: ${ DateTime(2026, 3, 9).difference(start).inDays }');
  print('dayIndex across US DST: ${ dayIndex(start, DateTime(2026, 3, 9)) }');
  print('00:30 first day: ${ dayIndex(DateTime(2026, 10, 3), DateTime(2026, 10, 3, 0, 30)) }');
  print('23:30 same day: ${ dayIndex(DateTime(2026, 10, 3), DateTime(2026, 10, 3, 23, 30)) }');
  print('23:30 last day of 3 days: ${ dayIndex(DateTime(2026, 10, 1), DateTime(2026, 10, 3, 23, 30)) }');
  print('len for one-day range: ${ dayIndex(DateTime(2026, 10, 3), DateTime(2026, 10, 3, 23, 59, 59)) + 1 }');
}
```

Run: `TZ=America/New_York dart run /tmp/day_index_check.dart`

Expected output:

```text
naive across US DST: 1
dayIndex across US DST: 2
00:30 first day: 0
23:30 same day: 0
23:30 last day of 3 days: 2
len for one-day range: 1
```

If the `naive` line prints `2` the shell's `TZ` was not applied; the other five lines must still match. Do not commit the script.

- [ ] **Step 3: Add `dayIndex` to `UtilsService`**

In `lib/services/utils.service.dart`, insert directly above `  String beautifyCurrency(double number, Currency currency) {`:

```dart
  int dayIndex(DateTime startDate, DateTime date) {
    return DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(startDate.year, startDate.month, startDate.day))
        .inDays;
  }

```

- [ ] **Step 4: Add `CategoryDailyExpenses` and `getExpensesByCategoryByDay` to the repository**

In `lib/repositories/movements.repository.dart`, insert directly above `class MovementsRepository extends BaseRepository<Movement> {`:

```dart
class CategoryDailyExpenses {
  final String category;
  final List<double> dailyTotals;

  const CategoryDailyExpenses({ required this.category, required this.dailyTotals });

  double get total => dailyTotals.fold<double>(0, (sum, value) => sum + value);
}

```

Then replace the end of the file

```dart
    }).entries.map((entry) => {'date': entry.key, 'total': entry.value}).toList();
  }
}
```

with

```dart
    }).entries.map((entry) => {'date': entry.key, 'total': entry.value}).toList();
  }

  Future<List<CategoryDailyExpenses>> getExpensesByCategoryByDay(Account? account, DateTime startDate, DateTime endDate, Currency displayCurrency) async {
    var where = 'type = ? AND creationDate >= ? AND creationDate < ?';
    List<Object?> whereArgs = [
      MovementType.REMOVE.name,
      DateTime(startDate.year, startDate.month, startDate.day).toIso8601String(),
      DateTime(endDate.year, endDate.month, endDate.day + 1).toIso8601String(),
    ];
    if (account != null) {
      where += ' AND (sourceId = ? OR targetId = ?)';
      whereArgs.add(account.id);
      whereArgs.add(account.id);
    }
    var movements = await find(where: where, args: whereArgs);
    var dayCount = utilsService.dayIndex(startDate, endDate) + 1;
    Map<String, List<double>> dailyTotalsByCategory = {};
    for (var movement in movements) {
      var creationDate = movement.creationDate!;
      var amount = utilsService.convertCurrenciesAt(movement.amount, movement.source!.currency, displayCurrency, creationDate);
      var dailyTotals = dailyTotalsByCategory.putIfAbsent(movement.category, () => List<double>.filled(dayCount, 0));
      dailyTotals[utilsService.dayIndex(startDate, creationDate)] += amount;
    }
    return dailyTotalsByCategory.entries.map((entry) => CategoryDailyExpenses(category: entry.key, dailyTotals: entry.value)).toList();
  }
}
```

- [ ] **Step 5: Analyze**

Run: `flutter analyze`
Expected: `24 issues found` (same as baseline, no new ones).

- [ ] **Step 6: Commit**

```bash
git branch --show-current
git add lib/services/utils.service.dart lib/repositories/movements.repository.dart
git commit -m "$(cat <<'EOF'
Add daily expenses by category query

getExpensesByCategoryByDay returns one fixed-length daily series per
category, with zeros on days without spending. The day of a movement is
its local calendar day; UtilsService.dayIndex counts days through UTC
dates so a DST change cannot shift the index.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: View `HistoricalExpensesByCategoryChart` and wiring in `statistics.dart`

**Files:**
- Create: `lib/views/statistics/historical_expenses_by_category.dart`
- Modify: `lib/views/statistics/statistics.dart` (import, chart-type option, `buildChart` branch)

**Interfaces:**
- Consumes: `MovementsRepository.getExpensesByCategoryByDay(...)`, `CategoryDailyExpenses` and `UtilsService.dayIndex` (Task 1), `CurrencySelector`, `ButtonSelector`, `DateRangeSelectorDialog`, `Loader`, `UtilsService.beautifyCurrency`.
- Produces: `HistoricalExpensesByCategoryChart({ super.key, Account? account })`.

- [ ] **Step 1: Create the view**

Create `lib/views/statistics/historical_expenses_by_category.dart` (no leading blank line, no comments):

```dart
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/repositories/movements.repository.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/generics/button_selector.dart';
import 'package:money/views/generics/currency_selector.dart';
import 'package:money/views/generics/date_range_selector.dialog.dart';
import 'package:money/views/generics/loader.dart';

class HistoricalExpensesByCategoryChart extends StatefulWidget {
  final Account? account;

  const HistoricalExpensesByCategoryChart({ super.key, this.account });

  @override
  State<HistoricalExpensesByCategoryChart> createState() => _HistoricalExpensesByCategoryChartState();
}

class _HistoricalExpensesByCategoryChartState extends State<HistoricalExpensesByCategoryChart> {
  List<CategoryDailyExpenses>? rows;
  DateTime? rowsStartDate;
  late Currency selectedCurrency;
  String selectedPeriod = '3-months';
  DateTimeRange? customRange;
  Set<String> disabledCategories = {};
  int? selectedDayIndex;
  int lastRequestId = 0;
  var databaseService = GetIt.instance.get<DatabaseService>();
  var utilsService = GetIt.instance.get<UtilsService>();
  var logger = GetIt.instance.get<Logger>();
  final colorSeed = 134;
  final periodOptions = ['3-months', '6-months', '1-year', 'custom'];
  final periodOptionNames = ['3 meses', '6 meses', '1 año', 'Custom'];
  final sectionSpacing = 15.0;
  final chartHeight = 300.0;
  final lineWidth = 2.0;
  final selectedDayLineWidth = 1.5;
  final touchSpotThreshold = 1000.0;
  final axisTitleSize = 50.0;
  final hiddenTitles = const AxisTitles(sideTitles: SideTitles(showTitles: false));
  final categoryRowPadding = 6.0;
  final categoryIconColumnWidth = 50.0;
  final categoryIconSize = 20.0;
  final disabledIconOpacity = 0.3;
  final categoryTextStyle = const TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

  DateTime get selectedPeriodStartDate {
    var now = DateTime.now();
    if (selectedPeriod == '3-months') return DateTime(now.year, now.month - 3, now.day);
    if (selectedPeriod == '6-months') return DateTime(now.year, now.month - 6, now.day);
    if (selectedPeriod == '1-year') return DateTime(now.year - 1, now.month, now.day);
    return customRange!.start;
  }

  DateTime get selectedPeriodEndDate {
    var now = DateTime.now();
    if (selectedPeriod == 'custom') return customRange!.end;
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  int get dayCount {
    return rows!.first.dailyTotals.length;
  }

  List<CategoryDailyExpenses> get sortedRows {
    var sorted = [...rows!];
    sorted.sort((a, b) => b.total.compareTo(a.total));
    return sorted;
  }

  List<CategoryDailyExpenses> get activeRows {
    return sortedRows.where((row) => !isDisabled(row.category)).toList();
  }

  Map<String, Color> get categoryColors {
    var generator = Random(colorSeed);
    return {
      for (var row in sortedRows)
        row.category: Colors.primaries[generator.nextInt(Colors.primaries.length)].shade700,
    };
  }

  double get chartMaxY {
    var maxValue = activeRows
        .expand((row) => row.dailyTotals)
        .fold<double>(0, max);
    return maxValue == 0 ? 1 : maxValue;
  }

  LineChartData get chartData {
    return LineChartData(
      minX: 0,
      maxX: max(1, dayCount - 1).toDouble(),
      minY: 0,
      maxY: chartMaxY,
      lineBarsData: activeRows.map(toLineBar).toList(),
      lineTouchData: touchData,
      extraLinesData: selectedDayLines,
      gridData: gridData,
      borderData: borderData,
      titlesData: titlesData,
    );
  }

  LineTouchData get touchData {
    return LineTouchData(
      handleBuiltInTouches: false,
      touchSpotThreshold: touchSpotThreshold,
      touchCallback: onChartTouch,
    );
  }

  ExtraLinesData get selectedDayLines {
    return ExtraLinesData(
      verticalLines: [
        if (selectedDayIndex != null)
          VerticalLine(x: selectedDayIndex!.toDouble(), color: Colors.grey.shade700, strokeWidth: selectedDayLineWidth),
      ],
    );
  }

  FlGridData get gridData {
    return FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 1),
    );
  }

  FlBorderData get borderData {
    return FlBorderData(
      border: Border(
        left: BorderSide(color: Colors.grey.shade400),
        bottom: BorderSide(color: Colors.grey.shade400),
      ),
    );
  }

  FlTitlesData get titlesData {
    return FlTitlesData(
      rightTitles: hiddenTitles,
      topTitles: hiddenTitles,
      bottomTitles: bottomTitles,
      leftTitles: leftTitles,
    );
  }

  AxisTitles get bottomTitles {
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: 1,
        reservedSize: axisTitleSize,
        getTitlesWidget: buildBottomTitle,
      ),
    );
  }

  AxisTitles get leftTitles {
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: axisTitleSize,
        getTitlesWidget: buildLeftTitle,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    selectedCurrency = widget.account?.currency ?? Currency.USD;
    getRows();
  }

  @override
  void didUpdateWidget(covariant HistoricalExpensesByCategoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account) {
      selectedCurrency = widget.account?.currency ?? Currency.USD;
      getRows();
    }
  }

  bool isDisabled(String category) {
    return disabledCategories.contains(category);
  }

  DateTime dateAt(int dayIndex) {
    return DateTime(rowsStartDate!.year, rowsStartDate!.month, rowsStartDate!.day + dayIndex);
  }

  String compactAmount(double value) {
    if (value >= 1000000) return '${ (value / 1000000).toStringAsFixed(1) }M';
    if (value >= 1000) return '${ (value / 1000).toStringAsFixed(0) }k';
    return value.toStringAsFixed(0);
  }

  LineChartBarData toLineBar(CategoryDailyExpenses row) {
    return LineChartBarData(
      spots: [for (var i = 0; i < row.dailyTotals.length; i++) FlSpot(i.toDouble(), row.dailyTotals[i])],
      color: categoryColors[row.category],
      barWidth: lineWidth,
      dotData: const FlDotData(show: false),
    );
  }

  Future<void> getRows() async {
    var requestId = ++lastRequestId;
    var startDate = selectedPeriodStartDate;
    var endDate = selectedPeriodEndDate;
    await databaseService.initialized;
    try {
      logger.d('Getting historical expenses by category');
      var result = await databaseService.movementsRepository.getExpensesByCategoryByDay(widget.account, startDate, endDate, selectedCurrency);
      if (!mounted || requestId != lastRequestId) return;
      setState(() {
        rows = result;
        rowsStartDate = startDate;
        selectedDayIndex = null;
      });
    } catch (error, stackTrace) {
      logger.e('Error getting historical expenses by category', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> selectCustomRange() async {
    var range = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => DateRangeSelectorDialog(
        initialRange: customRange,
        lastDate: DateTime.now(),
      ),
    );
    if (range == null || !mounted) return;
    setState(() {
      selectedPeriod = 'custom';
      customRange = range;
    });
    getRows();
  }

  void selectCurrency(Currency currency) {
    setState(() {
      selectedCurrency = currency;
    });
    getRows();
  }

  void selectPeriod(int index) {
    var option = periodOptions[index];
    if (option == 'custom') {
      selectCustomRange();
      return;
    }
    setState(() {
      selectedPeriod = option;
    });
    getRows();
  }

  void toggleCategory(String category) {
    setState(() {
      if (!disabledCategories.remove(category)) {
        disabledCategories.add(category);
      }
    });
  }

  void enableAllCategories() {
    setState(() {
      disabledCategories = {};
    });
  }

  void disableAllCategories() {
    setState(() {
      disabledCategories = sortedRows.map((row) => row.category).toSet();
    });
  }

  void clearSelectedDay() {
    setState(() {
      selectedDayIndex = null;
    });
  }

  void onChartTouch(FlTouchEvent event, LineTouchResponse? response) {
    var isSelectionEvent = event is FlTapUpEvent || event is FlPanUpdateEvent || event is FlLongPressMoveUpdate;
    var spots = response?.lineBarSpots;
    if (!isSelectionEvent || spots == null || spots.isEmpty) return;
    setState(() {
      selectedDayIndex = spots.first.x.toInt();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CurrencySelector(selected: selectedCurrency, onSelectionChange: selectCurrency),
        SizedBox(height: sectionSpacing),
        buildPeriodSelect(context),
        SizedBox(height: sectionSpacing),
        if (rows == null) const Center(child: Loader()) else if (rows!.isEmpty) buildEmptyMessage(context) else ...buildContent(context),
      ],
    );
  }

  Widget buildPeriodSelect(BuildContext context) {
    return ButtonSelector(
      options: periodOptionNames.map((e) => Text(e)).toList(),
      selectedIndex: periodOptions.indexOf(selectedPeriod),
      onSelectionChange: selectPeriod,
    );
  }

  Widget buildEmptyMessage(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 20),
      child: Center(child: Text('No hay datos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
    );
  }

  List<Widget> buildContent(BuildContext context) {
    return [
      if (activeRows.isEmpty) buildNoSelectionMessage(context) else buildChart(context),
      SizedBox(height: sectionSpacing),
      buildCategoryActions(context),
      if (selectedDayIndex != null) buildSelectedDayHeader(context),
      buildCategoryList(context),
    ];
  }

  Widget buildNoSelectionMessage(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(child: Text('No hay categorías seleccionadas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
    );
  }

  Widget buildChart(BuildContext context) {
    return SizedBox(
      height: chartHeight,
      child: LineChart(chartData),
    );
  }

  Widget buildBottomTitle(double value, TitleMeta meta) {
    var date = dateAt(value.toInt());
    if (value != value.toInt() || date.day != 1) return const SizedBox();
    return SideTitleWidget(
      axisSide: meta.axisSide,
      angle: -pi / 2,
      child: Text(DateFormat('MM/yy').format(date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget buildLeftTitle(double value, TitleMeta meta) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Text(compactAmount(value), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
    );
  }

  Widget buildCategoryActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        CupertinoButton(padding: EdgeInsets.zero, onPressed: enableAllCategories, child: const Text('Habilitar todas')),
        CupertinoButton(padding: EdgeInsets.zero, onPressed: disableAllCategories, child: const Text('Deshabilitar todas')),
      ],
    );
  }

  Widget buildSelectedDayHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        buildSelectedDayDate(context),
        CupertinoButton(padding: EdgeInsets.zero, onPressed: clearSelectedDay, child: const Text('Quitar selección')),
      ],
    );
  }

  Widget buildSelectedDayDate(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Text(DateFormat('dd-MM-yyyy').format(dateAt(selectedDayIndex!)), style: categoryTextStyle),
    );
  }

  Widget buildCategoryList(BuildContext context) {
    return Column(
      children: sortedRows.map((row) => buildCategoryRow(context, row)).toList(),
    );
  }

  Widget buildCategoryRow(BuildContext context, CategoryDailyExpenses row) {
    var category = row.category;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => toggleCategory(category),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: categoryRowPadding),
        child: Row(
          children: [
            buildCategoryIcon(context, category),
            buildCategoryName(context, category),
            if (selectedDayIndex != null && !isDisabled(category)) buildCategoryDayAmount(context, row),
          ],
        ),
      ),
    );
  }

  Widget buildCategoryIcon(BuildContext context, String category) {
    var color = categoryColors[category]!;
    return SizedBox(
      width: categoryIconColumnWidth,
      child: Center(
        child: Container(
          width: categoryIconSize,
          height: categoryIconSize,
          decoration: BoxDecoration(
            color: isDisabled(category) ? color.withValues(alpha: disabledIconOpacity) : color,
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
    );
  }

  Widget buildCategoryName(BuildContext context, String category) {
    return Expanded(
      child: Text(
        category,
        style: categoryTextStyle.copyWith(decoration: isDisabled(category) ? TextDecoration.lineThrough : null),
      ),
    );
  }

  Widget buildCategoryDayAmount(BuildContext context, CategoryDailyExpenses row) {
    var amount = row.dailyTotals[selectedDayIndex!];
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Text(utilsService.beautifyCurrency(amount, selectedCurrency), style: categoryTextStyle),
    );
  }
}
```

- [ ] **Step 2: Wire it into `statistics.dart`**

Add the import after the existing `expenses_by_day.dart` import (keep imports contiguous and alphabetical):

```dart
import 'package:money/views/statistics/historical_expenses_by_category.dart';
```

In `buildChartTypeSelector`, replace the `options` list with:

```dart
    var options = [
      'Ninguno',
      'Gastos por categoría',
      'Gastos por día',
      'Gastos por categoría históricos',
    ];
```

In `buildChart`, replace

```dart
    } else if (chartType == 'Gastos por día') {
      return ExpensesByDayChart(account: account);
    } else {
```

with

```dart
    } else if (chartType == 'Gastos por día') {
      return ExpensesByDayChart(account: account);
    } else if (chartType == 'Gastos por categoría históricos') {
      return HistoricalExpensesByCategoryChart(account: account);
    } else {
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: `24 issues found` (baseline, none in `historical_expenses_by_category.dart` or `statistics.dart`). Fix any new finding before continuing.

- [ ] **Step 4: Manual verification with `flutter run`**

Run the app, open Estadísticas → Tipo de gráfico → `Gastos por categoría históricos`. Have expense movements in at least 3 categories over several months (create them via the app if needed). Check each item:

1. Order on screen: currency selector, period selector, chart, `Habilitar todas` / `Deshabilitar todas`, category list.
2. Each category row's circle color matches its line; colors match the "Gastos por categoría" pie table for the same period/currency.
3. X axis shows vertical `MM/yy` labels only at the first of each month; no overlapping labels for `1 año`.
4. Tap/drag on the chart draws a vertical line and the list shows that day's amount per active category, with a date header and `Quitar selección`; lines crossing does not matter. `Quitar selección` removes the line and the amounts.
5. Tap a category: name struck through, circle faded, its line disappears, its amount disappears. `Deshabilitar todas` → `No hay categorías seleccionadas` (list and buttons stay); `Habilitar todas` restores everything.
6. Create an expense at 23:30 today and another at 00:30 on the first day of the period: both appear (last-day and first-day boundaries).
7. `Custom` with start day == end day (single day): no crash, chart renders. Cancelling the `Custom` dialog keeps the previous selection.
8. Change currency and period: disabled categories stay disabled. Change account: currency resets to that account's currency (USD for `Todas`), period and disabled categories stay.
9. An account/period with no expenses shows `No hay datos` and the selectors stay visible.

Record any failure and fix it before committing.

- [ ] **Step 5: Commit**

```bash
git branch --show-current
git add lib/views/statistics/historical_expenses_by_category.dart lib/views/statistics/statistics.dart
git commit -m "$(cat <<'EOF'
Add historical expenses by category chart

New Statistics chart with one daily line per category, currency and
period selectors, day selection through a vertical line, and a category
list that toggles lines and shows the selected day's amounts.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Update `docs/features/statistics.md`

**Files:**
- Modify: `docs/features/statistics.md`

**Interfaces:**
- Consumes: the behavior shipped in Tasks 1–2.
- Produces: documentation only.

- [ ] **Step 1: Update "What it does"**

Replace `Two chart views summarize movements, filterable by account, movement type, and time period:` with `Three chart views summarize movements, filterable by account, movement type, and time period:` and append after the "Expenses by day" bullet:

```markdown
- **Historical expenses by category** — a daily line chart with one line per category, currency
  and period selectors (`3 meses` / `6 meses` / `1 año` / `Custom`), and a category list that
  enables/disables each line. Expenses only.
```

- [ ] **Step 2: Update "Key repository methods"**

Add after the `getExpensesByDay` bullet:

```markdown
- `getExpensesByCategoryByDay(account, startDate, endDate, displayCurrency)` — expenses
  (`REMOVE`) grouped first by category and then by local calendar day; returns
  a `CategoryDailyExpenses` (`category`, `dailyTotals`, `total`) per category with a fixed-length list (one entry per day from
  `startDate` to `endDate`, zeros on days without spending). The upper bound is exclusive on the
  next midnight and the dates are bound with `toIso8601String()` to match the stored format.
```

- [ ] **Step 3: Update "Views involved"**

Add after the `expenses_by_day.dart` bullet:

```markdown
- [historical_expenses_by_category.dart](../../lib/views/statistics/historical_expenses_by_category.dart) —
  `fl_chart` line chart; `CurrencySelector` + period selector (`Custom` abre
  `DateRangeSelectorDialog`). Tocar o arrastrar sobre el gráfico marca un día con una línea
  vertical (sin tooltip) y la lista de categorías muestra el monto de ese día; tocar una
  categoría la habilita/deshabilita (tachada cuando está deshabilitada), con botones
  `Habilitar todas` / `Deshabilitar todas`.
```

- [ ] **Step 4: Update "Edge cases"**

Add these bullets at the end of "Edge cases":

```markdown
- **Historical chart day granularity** — data is daily; the X axis only labels the first day of
  each month (`MM/yy`). A movement belongs to its *local* calendar day (no `toUtc()`);
  `UtilsService.dayIndex` counts days through UTC dates so a DST change cannot shift the index.
- **Historical chart period options** — `3 meses` / `6 meses` / `1 año` / `Custom`, always ending
  today (or the custom range's end).
- **Historical chart colors and selection** — colors use `Random(134)` over categories sorted by
  period total (same algorithm as the category table) and do not change when categories are
  toggled. `disabledCategories` and the period survive currency/period/account changes; changing
  the account resets only the currency to the account's. All categories start enabled.
- **Date filter format mismatch (existing)** — `getExpensesByCategory` / `getExpensesByDay` bind
  `toString()` dates against `toIso8601String()` data, excluding movements on the end date; see
  [tech-debt.md](../tech-debt.md). The historical query avoids it.
```

- [ ] **Step 5: Final analysis and commit**

Run: `flutter analyze` → expected `24 issues found`.

```bash
git branch --show-current
git add docs/features/statistics.md
git commit -m "$(cat <<'EOF'
Document historical expenses by category chart

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```
