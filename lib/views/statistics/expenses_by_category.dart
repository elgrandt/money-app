
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/generics/button_selector.dart';
import 'package:money/views/generics/easy_pie_chart.dart';
import 'package:money/views/generics/loader.dart';

class ExpensesByCategoryChart extends StatefulWidget {
  final Account? account;

  const ExpensesByCategoryChart({ super.key, this.account });

  @override
  State<ExpensesByCategoryChart> createState() => _ExpensesByCategoryChartState();
}

class _ExpensesByCategoryChartState extends State<ExpensesByCategoryChart> {
  List<Map<String, Object?>>? expensesByCategory;
  MovementType selectedMovementType = MovementType.REMOVE;
  String? selectedPeriod = 'this-month';
  var databaseService = GetIt.instance.get<DatabaseService>();
  final colorSeed = 134;
  String viewMode = Currency.USD.toString();
  List<String> viewModes = [...Currency.values.map((currency) => currency.toString()), 'PERCENT'];

  @override
  void initState() {
    super.initState();
    viewMode = widget.account?.currency.toString() ?? Currency.USD.toString();
    getExpensesByCategory();
  }

  @override
  void didUpdateWidget(covariant ExpensesByCategoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account) {
      getExpensesByCategory();
    }
  }

  void getExpensesByCategory() async {
    DateTime? startDate;
    if (selectedPeriod == 'month') {
      startDate = DateTime.now().subtract(const Duration(days: 30));
    } else if (selectedPeriod == 'year') {
      startDate = DateTime.now().subtract(const Duration(days: 365));
    } else if (selectedPeriod == 'this-month') {
      startDate = DateTime(DateTime.now().year, DateTime.now().month);
    }
    var result = await databaseService.movementsRepository.getExpensesByCategory(widget.account, selectedMovementType, startDate);
    result.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    setState(() {
      expensesByCategory = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildTypeSelect(context),
        const SizedBox(height: 15),
        buildPeriodSelect(context),
        const SizedBox(height: 15),
        if (expensesByCategory == null) const Center(child: Loader()) else if (expensesByCategory!.isEmpty) buildEmptyMessage(context) else buildChart(context),
        if (expensesByCategory != null && expensesByCategory!.isNotEmpty) buildTable(context),
      ],
    );
  }

  Widget buildTypeSelect(BuildContext context) {
    return ButtonSelector(
      options: MovementType.values.map((e) => Text(movementTypeNames[e]!)).toList(),
      selectedIndex: MovementType.values.indexOf(selectedMovementType),
      onSelectionChange: (index) {
        setState(() {
          selectedMovementType = MovementType.values[index];
          getExpensesByCategory();
        });
      },
    );
  }

  Widget buildPeriodSelect(BuildContext context) {
    var options = ['this-month', 'month', 'year', null];
    var optionNames = ['Éste mes', '1 mes', '1 año', 'Todos'];
    return ButtonSelector(
      options: optionNames.map((e) => Text(e)).toList(),
      selectedIndex: options.indexOf(selectedPeriod),
      onSelectionChange: (index) {
        setState(() {
          selectedPeriod = options[index];
          getExpensesByCategory();
        });
      },
    );
  }

  Widget buildEmptyMessage(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 20),
      child: Center(child: Text('No hay datos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
    );
  }

  Widget buildChart(BuildContext context) {
    return EasyPieChart(
      randomGenerator: Random(colorSeed),
      items: expensesByCategory!,
      value: (map) => map['total'] as double,
      maxWidth: 200,
      maxHeight: 200,
      maxLabelWidth: 200,
    );
  }

  Widget buildTable(BuildContext context) {
    var generator = Random(colorSeed);
    var colors = expensesByCategory!.map((item) => Colors.primaries[generator.nextInt(Colors.primaries.length)].shade700).toList();
    List<TableRow> rows = [];
    for (var i = 0; i < expensesByCategory!.length; i++) {
      var map = expensesByCategory![i];
      rows.add(buildTableRow(context, map['category'] as String, map['total'] as double, colors[i]));
    }
    double total = expensesByCategory!.map((map) => map['total'] as double).reduce((value, element) => value + element);
    rows.add(buildTableRow(context, 'Total', total, Colors.transparent, showPercent: false));
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(50),
        1: FlexColumnWidth(1),
        2: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  TableRow buildTableRow(BuildContext context, String name, double total, Color color, {bool showPercent = true}) {
    double percent;
    if (showPercent) {
      percent = total / expensesByCategory!.map((map) => map['total'] as double).reduce((value, element) => value + element) * 100;
    } else {
      percent = 0;
    }
    String text = '';
    if (viewMode == 'PERCENT' && showPercent) {
      text = '${ percent.toStringAsFixed(2) }%';
    } else {
      var currency = Currency.values.firstWhere((currency) => currency.toString() == viewMode, orElse: () => Currency.USD);
      text = GetIt.instance.get<UtilsService>().beautifyCurrency(total, currency);
    }
    return TableRow(
      children: [
        Center(
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        GestureDetector(
          onTap: () {
            setState(() {
              var currentIndex = viewModes.indexOf(viewMode);
              viewMode = viewModes[(currentIndex + 1) % viewModes.length];
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.end),
          ),
        ),
      ],
    );
  }
}
