# Historical Expenses by Month (rework) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the "Gastos por categoría históricos" chart from daily to monthly granularity: one point per month and category, the current month included (last segment dashed), and a per-category month-over-month percentage variation in the category list.

**Architecture:** The daily repository method and `UtilsService.dayIndex` are replaced by `getExpensesByCategoryByMonth` (per category, a fixed-length list of monthly totals) and `UtilsService.monthIndex` (integer year/month arithmetic). The existing view keeps its selectors, stable colors, category toggling and empty states, and switches its X axis, period math, selection and list to months.

**Tech Stack:** Flutter 3.27 / Dart 3.6, `sqflite`, `get_it`, `intl`, `fl_chart` 0.70.0.

**Spec:** [2026-10-03-historical-expenses-by-category-design.md](../specs/2026-10-03-historical-expenses-by-category-design.md)

## Global Constraints

- **Language:** code identifiers, logs and plans in English; UI strings in Spanish (`es_AR`). Chat with the user in Spanish.
- **No tests by policy:** do not create test files. Verification = `flutter analyze` (baseline: **24 issues**, all pre-existing; this work must add none) + manual check with `flutter run` + throwaway scripts under `/tmp` (never committed).
- **Git:** never commit to `master`; work on `feature/historical-expenses-by-category` (confirm with `git branch --show-current` before each commit). Commit messages: imperative, capitalized, no type prefix, ~50 chars. End each commit message with `Co-Authored-By: Claude Code <noreply@anthropic.com>`.
- **Renames are done by the user with the IDE rename** (project rule): `CategoryDailyExpenses` → `CategoryMonthlyExpenses`, field `dailyTotals` → `monthlyTotals`, method `getExpensesByCategoryByDay` → `getExpensesByCategoryByMonth`. The plan starts only after the user confirms them (Task 1 Step 1 verifies).
- **Code style ([coding-style.md](../../coding-style.md)):** 2-space indent, single quotes, no leading blank line, no blank lines between imports, `${ expr }` with inner spaces (even for simple names), `{ a, b }` brace spacing when more than one named param, **no code comments**, member order attributes → getters → constructor → lifecycle → logic → `build` → `buildX`, no inline record types, don't cache a getter in a local just to avoid recomputing, short methods (one `buildX` per child of a long widget chain; chart data pieces as getters), no magic numbers (named fields). Imports always at the top of the file.
- **Typed results:** repository aggregates return a named class, never `Map<String, Object?>` ("Typed query results" in `docs/data-layer.md`).
- **Months:** a movement's month is the year/month of its *local* `creationDate`; never call `toUtc()`. Date SQL params use `toIso8601String()` (stored format), not `toString()`.
- **Copy (exact):** `Gastos por categoría históricos`; periods `3 meses`, `6 meses`, `1 año`, `Custom`; buttons `Habilitar todas`, `Deshabilitar todas`, `Quitar selección`; messages `No hay datos`, `No hay categorías seleccionadas`; header suffix ` (en curso)`; variation placeholder `—` (em dash).
- **Docs-in-sync:** update `docs/features/statistics.md` and `docs/data-layer.md` in the same change.
- **Meta-rule:** if something is not covered by the spec or an existing pattern, stop and ask.

## Review Focus

- A movement at 23:30 local on the **last day of a month** (and 00:30 on the 1st) must land in its own month; the upper bound is the first day of the month after `endMonth`, exclusive. Pinned in Task 1 Step 2 and Task 2 Step 3.
- The December → January boundary and `DateTime(year, month - 2)` normalization (January minus 2 → November of the previous year) must yield correct indexes. Pinned in Task 1 Step 2.
- The current month is included; the last segment is dashed; with only one month, or when the solid part has a single point, the dots still make the chart visible. Pinned in Task 2 Step 3.
- Variation must show `—` for the first month of the period and when the previous month is 0 (no divide-by-zero, no `Infinity%`/`NaN%`); rounded `0%` is neutral. Pinned in Task 2 Step 3.
- A `Custom` range inside one month (one point per line) and a `Custom` range longer than 12 months (axis label step) must not crash or overlap labels. Pinned in Task 2 Step 3.
- Switching account resets the currency but keeps period and disabled categories; no data shows `No hay datos` with selectors visible; all disabled shows `No hay categorías seleccionadas`. Pinned in Task 2 Step 3.

---

### Task 1: Data layer — `UtilsService.monthIndex` and `getExpensesByCategoryByMonth`

**Files:**
- Modify: `lib/services/utils.service.dart` (replace `dayIndex` with `monthIndex`)
- Modify: `lib/repositories/movements.repository.dart` (rewrite the body of the renamed method)
- Modify: `docs/data-layer.md` (reference class name/field after the rename)
- Commit also (already in the working tree, uncommitted): the reworked spec and this plan.

**Interfaces:**
- Consumes: `UtilsService.convertCurrenciesAt(double, Currency, Currency, DateTime)`, `BaseRepository.find({ where, args })`, `Movement.source` / `.category` / `.amount` / `.creationDate`.
- Produces:
  - `int UtilsService.monthIndex(DateTime startMonth, DateTime date)` — calendar months from `startMonth`'s month to `date`'s month: `(date.year - startMonth.year) * 12 + date.month - startMonth.month`.
  - `class CategoryMonthlyExpenses { final String category; final List<double> monthlyTotals; double get total; }` (renamed by the user; same shape as the daily class).
  - `Future<List<CategoryMonthlyExpenses>> MovementsRepository.getExpensesByCategoryByMonth(Account? account, DateTime startMonth, DateTime endMonth, Currency displayCurrency)` — one item per category with spending; every `monthlyTotals` has length `monthIndex(startMonth, endMonth) + 1`, zeros in months without spending.

- [ ] **Step 1: Verify the user's IDE renames and commit the docs**

Run:

```bash
git branch --show-current
grep -rn "CategoryDailyExpenses\|dailyTotals\|getExpensesByCategoryByDay" lib docs/data-layer.md docs/features/statistics.md
grep -rn "CategoryMonthlyExpenses\|monthlyTotals\|getExpensesByCategoryByMonth" lib | head
flutter analyze 2>&1 | grep "issues found"
```

Expected: branch is `feature/historical-expenses-by-category`; the first `grep` prints nothing in `lib/` and `docs/data-layer.md` (any leftover is a missed rename: fix it by hand); the second finds the three new names in `movements.repository.dart` and `historical_expenses_by_category.dart`; analyze prints `24 issues found`. (`docs/features/statistics.md` is rewritten in Task 3, so leftovers there are expected now.)

Then commit the spec, the plan and any rename fallout:

```bash
git add -A docs/superpowers lib docs/data-layer.md
git status --short
git commit -m "$(cat <<'EOF'
Rework historical chart design to monthly granularity

Spec and plan for grouping the historical expenses by category chart by
month with month-over-month variation, plus the IDE renames to the
monthly names.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 2: Verify the `monthIndex` logic with a throwaway script**

Create `/tmp/month_index_check.dart`:

```dart
int monthIndex(DateTime startMonth, DateTime date) {
  return (date.year - startMonth.year) * 12 + date.month - startMonth.month;
}

void main() {
  var start = DateTime(2026, 8);
  print('last day of first month: ${ monthIndex(start, DateTime(2026, 8, 31, 23, 30)) }');
  print('first day of next month: ${ monthIndex(start, DateTime(2026, 9, 1, 0, 30)) }');
  print('dec to jan: ${ monthIndex(DateTime(2025, 12), DateTime(2026, 1, 15)) }');
  print('january minus 2: ${ DateTime(2026, 1 - 2).year }-${ DateTime(2026, 1 - 2).month }');
  print('1 year count: ${ monthIndex(DateTime(2026, 10 - 11), DateTime(2026, 10, 3)) + 1 }');
  print('3 months count: ${ monthIndex(DateTime(2026, 10 - 2), DateTime(2026, 10, 3)) + 1 }');
  print('upper bound: ${ DateTime(2026, 12 + 1).toIso8601String() }');
  print('bound vs 23:30 last day: ${ DateTime(2026, 12, 31, 23, 30).toIso8601String().compareTo(DateTime(2026, 12 + 1).toIso8601String()) < 0 }');
}
```

Run: `dart run /tmp/month_index_check.dart`

Expected output:

```text
last day of first month: 0
first day of next month: 1
dec to jan: 1
january minus 2: 2025-11
1 year count: 12
3 months count: 3
upper bound: 2027-01-01T00:00:00.000
bound vs 23:30 last day: true
```

Do not commit the script.

- [ ] **Step 3: Replace `dayIndex` with `monthIndex` in `UtilsService`**

In `lib/services/utils.service.dart`, replace

```dart
  int dayIndex(DateTime startDate, DateTime date) {
    return DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(startDate.year, startDate.month, startDate.day))
        .inDays;
  }
```

with

```dart
  int monthIndex(DateTime startMonth, DateTime date) {
    return (date.year - startMonth.year) * 12 + date.month - startMonth.month;
  }
```

- [ ] **Step 4: Rewrite the repository method body**

In `lib/repositories/movements.repository.dart`, replace the whole `getExpensesByCategoryByMonth` method (currently the renamed daily method at the end of the class) with:

```dart
  Future<List<CategoryMonthlyExpenses>> getExpensesByCategoryByMonth(Account? account, DateTime startMonth, DateTime endMonth, Currency displayCurrency) async {
    var where = 'type = ? AND creationDate >= ? AND creationDate < ?';
    List<Object?> whereArgs = [
      MovementType.REMOVE.name,
      DateTime(startMonth.year, startMonth.month).toIso8601String(),
      DateTime(endMonth.year, endMonth.month + 1).toIso8601String(),
    ];
    if (account != null) {
      where += ' AND (sourceId = ? OR targetId = ?)';
      whereArgs.add(account.id);
      whereArgs.add(account.id);
    }
    var movements = await find(where: where, args: whereArgs);
    var monthCount = utilsService.monthIndex(startMonth, endMonth) + 1;
    Map<String, List<double>> monthlyTotalsByCategory = {};
    for (var movement in movements) {
      var creationDate = movement.creationDate!;
      var amount = utilsService.convertCurrenciesAt(movement.amount, movement.source!.currency, displayCurrency, creationDate);
      var monthlyTotals = monthlyTotalsByCategory.putIfAbsent(movement.category, () => List<double>.filled(monthCount, 0));
      monthlyTotals[utilsService.monthIndex(startMonth, creationDate)] += amount;
    }
    return monthlyTotalsByCategory.entries.map((entry) => CategoryMonthlyExpenses(category: entry.key, monthlyTotals: entry.value)).toList();
  }
```

Confirm the class above `MovementsRepository` reads:

```dart
class CategoryMonthlyExpenses {
  final String category;
  final List<double> monthlyTotals;

  const CategoryMonthlyExpenses({ required this.category, required this.monthlyTotals });

  double get total => monthlyTotals.fold<double>(0, (sum, value) => sum + value);
}
```

(If the IDE rename left any difference, fix it to match.)

- [ ] **Step 5: Update `docs/data-layer.md`**

In the "Typed query results" section make sure the reference text and code block use `CategoryMonthlyExpenses`, `monthlyTotals` and `getExpensesByCategoryByMonth` (the IDE rename does not touch Markdown). The code block must read:

```dart
class CategoryMonthlyExpenses {
  final String category;
  final List<double> monthlyTotals;

  const CategoryMonthlyExpenses({ required this.category, required this.monthlyTotals });

  double get total => monthlyTotals.fold<double>(0, (sum, value) => sum + value);
}
```

- [ ] **Step 6: Analyze, note the expected temporary break, commit**

Run: `flutter analyze 2>&1 | grep -E "error|issues found"`

Expected: errors only in `historical_expenses_by_category.dart` (it still calls the removed `dayIndex` and uses day fields); none in the two files edited here. These are fixed in Task 2, so this commit intentionally leaves the view uncompilable for one commit.

```bash
git branch --show-current
git add lib/services/utils.service.dart lib/repositories/movements.repository.dart docs/data-layer.md
git commit -m "$(cat <<'EOF'
Group historical expenses query by month

getExpensesByCategoryByMonth returns one fixed-length monthly series per
category, with zeros on months without spending. The month index is
integer year/month arithmetic on the local creationDate, and the upper
bound is the first day of the month after the range (exclusive).

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Monthly view with current-month segment and variation

**Files:**
- Modify (full rewrite): `lib/views/statistics/historical_expenses_by_category.dart`

**Interfaces:**
- Consumes: `MovementsRepository.getExpensesByCategoryByMonth(...)`, `CategoryMonthlyExpenses`, `UtilsService.monthIndex`, `UtilsService.beautifyCurrency`, `CurrencySelector`, `ButtonSelector`, `DateRangeSelectorDialog`, `Loader`.
- Produces: `HistoricalExpensesByCategoryChart({ super.key, Account? account })` (unchanged contract; `statistics.dart` needs no change).

- [ ] **Step 1: Rewrite the view**

Replace the whole file `lib/views/statistics/historical_expenses_by_category.dart` with (no leading blank line, no comments):

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
  List<CategoryMonthlyExpenses>? rows;
  DateTime? rowsStartMonth;
  late Currency selectedCurrency;
  String selectedPeriod = '3-months';
  DateTimeRange? customRange;
  Set<String> disabledCategories = {};
  int? selectedMonthIndex;
  int lastRequestId = 0;
  var databaseService = GetIt.instance.get<DatabaseService>();
  var utilsService = GetIt.instance.get<UtilsService>();
  var logger = GetIt.instance.get<Logger>();
  final colorSeed = 134;
  final periodOptions = ['3-months', '6-months', '1-year', 'custom'];
  final periodOptionNames = ['3 meses', '6 meses', '1 año', 'Custom'];
  final maxAxisLabels = 12;
  final axisIntervalCount = 5;
  final provisionalDashArray = [5, 5];
  final sectionSpacing = 15.0;
  final chartHeight = 300.0;
  final lineWidth = 2.0;
  final selectedMonthLineWidth = 1.5;
  final touchSpotThreshold = 1000.0;
  final axisTitleSize = 50.0;
  final hiddenTitles = const AxisTitles(sideTitles: SideTitles(showTitles: false));
  final categoryRowPadding = 6.0;
  final categoryIconColumnWidth = 50.0;
  final categoryIconSize = 20.0;
  final disabledIconOpacity = 0.3;
  final variationSpacing = 8.0;
  final categoryTextStyle = const TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

  DateTime get currentMonth {
    var now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  DateTime get selectedPeriodStartMonth {
    if (selectedPeriod == '3-months') return DateTime(currentMonth.year, currentMonth.month - 2);
    if (selectedPeriod == '6-months') return DateTime(currentMonth.year, currentMonth.month - 5);
    if (selectedPeriod == '1-year') return DateTime(currentMonth.year, currentMonth.month - 11);
    return DateTime(customRange!.start.year, customRange!.start.month);
  }

  DateTime get selectedPeriodEndMonth {
    if (selectedPeriod == 'custom') return DateTime(customRange!.end.year, customRange!.end.month);
    return currentMonth;
  }

  int get monthCount {
    return rows!.first.monthlyTotals.length;
  }

  bool get includesCurrentMonth {
    return utilsService.monthIndex(rowsStartMonth!, currentMonth) == monthCount - 1;
  }

  bool get hasProvisionalSegment {
    return includesCurrentMonth && monthCount >= 2;
  }

  int get labelStep {
    return (monthCount / maxAxisLabels).ceil();
  }

  List<CategoryMonthlyExpenses> get sortedRows {
    var sorted = [...rows!];
    sorted.sort((a, b) => b.total.compareTo(a.total));
    return sorted;
  }

  List<CategoryMonthlyExpenses> get activeRows {
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
        .expand((row) => row.monthlyTotals)
        .fold<double>(0, max);
    return maxValue == 0 ? 1 : maxValue;
  }

  double get chartInterval {
    return max(1, (chartMaxY / axisIntervalCount).ceil()).toDouble();
  }

  String get selectedMonthTitle {
    var title = DateFormat('MM/yyyy').format(monthAt(selectedMonthIndex!));
    var isCurrent = includesCurrentMonth && selectedMonthIndex == monthCount - 1;
    return isCurrent ? '${ title } (en curso)' : title;
  }

  LineChartData get chartData {
    return LineChartData(
      minX: 0,
      maxX: max(1, monthCount - 1).toDouble(),
      minY: 0,
      maxY: chartMaxY,
      lineBarsData: activeRows.expand(toLineBars).toList(),
      lineTouchData: touchData,
      extraLinesData: selectedMonthLines,
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

  ExtraLinesData get selectedMonthLines {
    return ExtraLinesData(
      verticalLines: [
        if (selectedMonthIndex != null)
          VerticalLine(x: selectedMonthIndex!.toDouble(), color: Colors.grey.shade700, strokeWidth: selectedMonthLineWidth),
      ],
    );
  }

  FlGridData get gridData {
    return FlGridData(
      drawVerticalLine: false,
      horizontalInterval: chartInterval,
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
        interval: chartInterval,
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

  DateTime monthAt(int monthIndex) {
    return DateTime(rowsStartMonth!.year, rowsStartMonth!.month + monthIndex);
  }

  double? variationPercent(CategoryMonthlyExpenses row, int monthIndex) {
    if (monthIndex == 0) return null;
    var previous = row.monthlyTotals[monthIndex - 1];
    if (previous == 0) return null;
    return (row.monthlyTotals[monthIndex] - previous) / previous * 100;
  }

  String formatVariation(double? percent) {
    if (percent == null) return '—';
    var rounded = percent.round();
    return '${ rounded > 0 ? '+' : '' }${ rounded }%';
  }

  Color variationColor(double? percent) {
    if (percent == null || percent.round() == 0) return Colors.grey.shade700;
    return percent > 0 ? Colors.red.shade900 : Colors.green.shade900;
  }

  String compactAmount(double value) {
    if (value >= 1000000) return '${ (value / 1000000).toStringAsFixed(1) }M';
    if (value >= 1000) return '${ (value / 1000).toStringAsFixed(0) }k';
    return value.toStringAsFixed(0);
  }

  List<LineChartBarData> toLineBars(CategoryMonthlyExpenses row) {
    if (!hasProvisionalSegment) return [toLineBar(row, 0, monthCount)];
    return [
      toLineBar(row, 0, monthCount - 1),
      toLineBar(row, monthCount - 2, monthCount, dashArray: provisionalDashArray),
    ];
  }

  LineChartBarData toLineBar(CategoryMonthlyExpenses row, int fromMonth, int toMonth, { List<int>? dashArray }) {
    return LineChartBarData(
      spots: [for (var i = fromMonth; i < toMonth; i++) FlSpot(i.toDouble(), row.monthlyTotals[i])],
      color: categoryColors[row.category],
      barWidth: lineWidth,
      dashArray: dashArray,
      dotData: const FlDotData(show: true),
    );
  }

  Future<void> getRows() async {
    var requestId = ++lastRequestId;
    var startMonth = selectedPeriodStartMonth;
    var endMonth = selectedPeriodEndMonth;
    await databaseService.initialized;
    try {
      logger.d('Getting historical expenses by category');
      var result = await databaseService.movementsRepository.getExpensesByCategoryByMonth(widget.account, startMonth, endMonth, selectedCurrency);
      if (!mounted || requestId != lastRequestId) return;
      setState(() {
        rows = result;
        rowsStartMonth = startMonth;
        selectedMonthIndex = null;
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

  void clearSelectedMonth() {
    setState(() {
      selectedMonthIndex = null;
    });
  }

  void onChartTouch(FlTouchEvent event, LineTouchResponse? response) {
    var isSelectionEvent = event is FlTapUpEvent || event is FlPanUpdateEvent || event is FlLongPressMoveUpdate;
    var spots = response?.lineBarSpots;
    if (!isSelectionEvent || spots == null || spots.isEmpty) return;
    setState(() {
      selectedMonthIndex = spots.first.x.toInt();
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
      if (selectedMonthIndex != null) buildSelectedMonthHeader(context),
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
      child: LineChart(chartData, duration: Duration.zero),
    );
  }

  Widget buildBottomTitle(double value, TitleMeta meta) {
    if (value != value.toInt() || value >= monthCount || value.toInt() % labelStep != 0) return const SizedBox();
    return SideTitleWidget(
      axisSide: meta.axisSide,
      angle: -pi / 2,
      child: Text(DateFormat('MM/yy').format(monthAt(value.toInt())), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

  Widget buildSelectedMonthHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        buildSelectedMonthTitle(context),
        CupertinoButton(padding: EdgeInsets.zero, onPressed: clearSelectedMonth, child: const Text('Quitar selección')),
      ],
    );
  }

  Widget buildSelectedMonthTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Text(selectedMonthTitle, style: categoryTextStyle),
    );
  }

  Widget buildCategoryList(BuildContext context) {
    return Column(
      children: sortedRows.map((row) => buildCategoryRow(context, row)).toList(),
    );
  }

  Widget buildCategoryRow(BuildContext context, CategoryMonthlyExpenses row) {
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
            if (selectedMonthIndex != null && !isDisabled(category)) buildCategoryMonthDetails(context, row),
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

  Widget buildCategoryMonthDetails(BuildContext context, CategoryMonthlyExpenses row) {
    var amount = row.monthlyTotals[selectedMonthIndex!];
    var percent = variationPercent(row, selectedMonthIndex!);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(utilsService.beautifyCurrency(amount, selectedCurrency), style: categoryTextStyle),
          SizedBox(width: variationSpacing),
          Text(formatVariation(percent), style: categoryTextStyle.copyWith(color: variationColor(percent))),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze 2>&1 | grep -E "error|historical|issues found"`
Expected: `24 issues found` and nothing mentioning `historical_expenses_by_category.dart` or `movements.repository.dart`. Fix any new finding before continuing.

- [ ] **Step 3: Manual verification with `flutter run`**

Run the app, open Estadísticas → Tipo de gráfico → `Gastos por categoría históricos`. Have expenses in at least 3 categories over several months. Check each item:

1. Order on screen: currency selector, period selector, chart, `Habilitar todas` / `Deshabilitar todas`, category list.
2. `3 meses` shows 3 points per line (current month and the 2 previous), `6 meses` 6, `1 año` 12; each X label is `MM/yy`, one per month, none overlapping.
3. The last segment (previous month → current month) is dashed; all points show dots.
4. Tap/drag on the chart draws a vertical line at the nearest month; the list header shows `MM/yyyy` (with ` (en curso)` for the current month) and each active row shows that month's amount plus the variation (`+25%` red when it rose, `-10%` green when it fell, `—` grey for the first month or when the previous month is 0, `0%` grey). `Quitar selección` clears it.
5. Tap a category: name struck through, circle faded, its line and its details disappear; `Deshabilitar todas` → `No hay categorías seleccionadas` (list and buttons stay); `Habilitar todas` restores everything. Colors match the "Gastos por categoría" table for the same period/currency.
6. A movement on the last day of a month at 23:30 counts in that month; one on the 1st at 00:30 counts in the new month.
7. `Custom` inside a single month: dots visible, no crash, variation `—`. `Custom` over more than 12 months: labels thin out (every 2nd), no overlap. Cancelling the dialog keeps the previous selection.
8. Change currency and period: disabled categories stay disabled. Change account: currency resets to that account's currency (USD for `Todas`), period and disabled categories stay.
9. An account/period with no expenses shows `No hay datos`, selectors visible. Y-axis labels are not repeated for small maximums.

Record any failure and fix it before committing.

- [ ] **Step 4: Commit**

```bash
git branch --show-current
git add lib/views/statistics/historical_expenses_by_category.dart
git commit -m "$(cat <<'EOF'
Show historical expenses by category per month

One point per month and category, current month included with a dashed
last segment, and month-over-month percentage variation next to each
category amount when a month is selected. Replaces the daily view.

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

- [ ] **Step 1: "What it does"**

Replace the "Historical expenses by category" bullet with:

```markdown
- **Historical expenses by category** — a monthly line chart (one point per month and category,
  current month included) to see how each category's spending varies month to month, with
  currency and period selectors (`3 meses` / `6 meses` / `1 año` / `Custom`) and a category list
  that enables/disables each line and shows the month-over-month % variation. Expenses only.
```

- [ ] **Step 2: "Key repository methods"**

Replace the `getExpensesByCategoryByDay` bullet (and fix the section's line-range link to the current range of `getExpensesByCategory`..`getExpensesByCategoryByMonth`; get it with `grep -n "Future<List" lib/repositories/movements.repository.dart` and the end line of the last method) with:

```markdown
- `getExpensesByCategoryByMonth(account, startMonth, endMonth, displayCurrency)` — expenses
  (`REMOVE`) grouped first by category and then by calendar month (both end months included);
  returns a `CategoryMonthlyExpenses` (`category`, `monthlyTotals`, `total`) per category with a
  fixed-length list (one entry per month, zeros in months without spending). The upper bound is
  exclusive on the first day of the month after `endMonth`, and the dates are bound with
  `toIso8601String()` to match the stored format.
```

- [ ] **Step 3: "Views involved"**

Replace the `historical_expenses_by_category.dart` bullet with:

```markdown
- [historical_expenses_by_category.dart](../../lib/views/statistics/historical_expenses_by_category.dart) —
  `fl_chart` line chart; `CurrencySelector` + period selector (`Custom` abre
  `DateRangeSelectorDialog`). Tocar o arrastrar sobre el gráfico marca un mes con una línea
  vertical (sin tooltip) y la lista de categorías muestra el monto de ese mes y la variación
  porcentual contra el mes anterior; tocar una categoría la habilita/deshabilita (tachada
  cuando está deshabilitada), con botones `Habilitar todas` / `Deshabilitar todas`.
```

- [ ] **Step 4: "Edge cases"**

Replace the three "Historical chart …" bullets (day granularity, period options, colors and selection) with:

```markdown
- **Historical chart month granularity** — data is monthly; a movement belongs to the month of its
  *local* `creationDate` (no `toUtc()`). `UtilsService.monthIndex` is integer year/month
  arithmetic, so there is no DST issue. The X axis has one `MM/yy` label per month (one every
  `ceil(months / 12)` months beyond 12, only possible with `Custom`).
- **Historical chart period options** — `3 meses` / `6 meses` / `1 año` are calendar months
  ending at the current month (3 / 6 / 12 points); `Custom` covers the whole months touched by the
  chosen range.
- **Historical chart current month** — always included and partial; the last segment (previous
  month → current month) is dashed and the selection header shows ` (en curso)`.
- **Historical chart variation** — `(month − previous) / previous × 100`, rounded, with sign
  (`+25%`); red when it rose, green when it fell, grey for `0%`. It is `—` for the first month of
  the period and whenever the previous month is 0.
- **Historical chart colors and selection** — colors use `Random(134)` over categories sorted by
  period total (same algorithm as the category table) and do not change when categories are
  toggled. `disabledCategories` and the period survive currency/period/account changes; changing
  the account resets only the currency to the account's. All categories start enabled.
```

Keep the existing "Date filter format mismatch (existing)" bullet.

- [ ] **Step 5: Refresh the cited line ranges**

Run `grep -n "convertCurrenciesAt" lib/repositories/movements.repository.dart` and update the two `movements.repository.dart:…` links in `docs/features/statistics.md` (the "Key repository methods" header range and the cross-currency bullet) to the current lines.

- [ ] **Step 6: Final analysis and commit**

Run: `flutter analyze 2>&1 | grep "issues found"` → expected `24 issues found`.

```bash
git branch --show-current
git add docs/features/statistics.md
git commit -m "$(cat <<'EOF'
Document monthly historical expenses chart

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```
