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
  final axisLabelAngle = -pi / 4;
  final hiddenTitles = const AxisTitles(sideTitles: SideTitles(showTitles: false));
  final categoryRowPadding = 6.0;
  final categoryIconColumnWidth = 50.0;
  final categoryIconSize = 20.0;
  final disabledIconOpacity = 0.3;
  final variationSpacing = 8.0;
  final variationTextStyle = const TextStyle(fontSize: 13, fontWeight: FontWeight.bold);
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
    return isCurrent ? '$title (en curso)' : title;
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

  bool hasVariation(double? percent) {
    return percent != null && percent.round() != 0;
  }

  String formatVariation(double percent) {
    var rounded = percent.round();
    return '${ rounded > 0 ? '+' : '' }$rounded%';
  }

  Color variationColor(double percent) {
    return percent > 0 ? Colors.red.shade900 : Colors.green.shade900;
  }

  String compactAmount(double value) {
    if (value >= 1000000) return '${ (value / 1000000).toStringAsFixed(1) }M';
    if (value >= 1000) return '${ (value / 1000).toStringAsFixed(1).replaceAll('.0', '') }k';
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
      angle: axisLabelAngle,
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
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (hasVariation(percent)) buildCategoryVariation(context, percent!),
          Text(utilsService.beautifyCurrency(amount, selectedCurrency), style: categoryTextStyle),
        ],
      ),
    );
  }

  Widget buildCategoryVariation(BuildContext context, double percent) {
    return Padding(
      padding: EdgeInsets.only(right: variationSpacing),
      child: Text(formatVariation(percent), style: variationTextStyle.copyWith(color: variationColor(percent))),
    );
  }
}
