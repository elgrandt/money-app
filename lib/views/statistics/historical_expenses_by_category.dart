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
    return rows!.first.monthlyTotals.length;
  }

  bool get isSingleDay {
    return dayCount == 1;
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

  LineChartBarData toLineBar(CategoryMonthlyExpenses row) {
    return LineChartBarData(
      spots: [for (var i = 0; i < row.monthlyTotals.length; i++) FlSpot(i.toDouble(), row.monthlyTotals[i])],
      color: categoryColors[row.category],
      barWidth: lineWidth,
      dotData: FlDotData(show: isSingleDay),
    );
  }

  Future<void> getRows() async {
    var requestId = ++lastRequestId;
    var startDate = selectedPeriodStartDate;
    var endDate = selectedPeriodEndDate;
    await databaseService.initialized;
    try {
      logger.d('Getting historical expenses by category');
      var result = await databaseService.movementsRepository.getExpensesByCategoryByMonth(widget.account, startDate, endDate, selectedCurrency);
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
    if (value != value.toInt() || value >= dayCount) return const SizedBox();
    var date = dateAt(value.toInt());
    if (date.day != 1) return const SizedBox();
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

  Widget buildCategoryDayAmount(BuildContext context, CategoryMonthlyExpenses row) {
    var amount = row.monthlyTotals[selectedDayIndex!];
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Text(utilsService.beautifyCurrency(amount, selectedCurrency), style: categoryTextStyle),
    );
  }
}
