
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
  String? selectedPeriod = 'month';
  var databaseService = GetIt.instance.get<DatabaseService>();
  final colorSeed = 134;
  bool showTotal = false;

  @override
  void initState() {
    super.initState();
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
    var options = ['month', 'year', null];
    var optionNames = ['1 mes', '1 año', 'Todos'];
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

  TableRow buildTableRow(BuildContext context, String name, double total, Color color) {
    var percent = total / expensesByCategory!.map((map) => map['total'] as double).reduce((value, element) => value + element) * 100;
    var beautifulTotal = GetIt.instance.get<UtilsService>().beautifyCurrency(total, widget.account?.currency ?? Currency.USD);
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
              showTotal = !showTotal;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(showTotal ? beautifulTotal : '${ percent.toStringAsFixed(2) }%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.end),
          ),
        ),
      ],
    );
  }
}
