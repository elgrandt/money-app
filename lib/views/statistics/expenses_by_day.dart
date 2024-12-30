
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/generics/button_selector.dart';
import 'package:money/views/generics/loader.dart';

class ExpensesByDayChart extends StatefulWidget {
  final Account? account;

  const ExpensesByDayChart({ super.key, this.account });

  @override
  State<ExpensesByDayChart> createState() => _ExpensesByDayChartState();
}

class _ExpensesByDayChartState extends State<ExpensesByDayChart> {
  List<Map<String, Object?>>? expensesByDay;
  MovementType selectedMovementType = MovementType.REMOVE;
  String? selectedPeriod = 'week';
  var databaseService = GetIt.instance.get<DatabaseService>();
  var accumulated = false;
  List<BarChartGroupData>? groups;
  List<String>? days;
  double? minY;
  double? maxY;

  @override
  void initState() {
    super.initState();
    getExpensesByDay();
  }

  @override
  void didUpdateWidget(covariant ExpensesByDayChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account) {
      getExpensesByDay();
    }
  }

  void getExpensesByDay() async {
    DateTime? startDate;
    if (selectedPeriod == 'week') {
      startDate = DateTime.now().subtract(const Duration(days: 7));
    } else if (selectedPeriod == 'month') {
      startDate = DateTime.now().subtract(const Duration(days: 30));
    } else if (selectedPeriod == 'year') {
      startDate = DateTime.now().subtract(const Duration(days: 365));
    }
    var result = await databaseService.movementsRepository.getExpensesByDay(widget.account, selectedMovementType, startDate);
    if (result.isNotEmpty) {
      doCalculations(result);
    } else {
      setState(() {
        expensesByDay = result;
      });
    }
  }

  void doCalculations(List<Map<String, Object?>> expensesByDay) {
    // Calcular la fecha de inicio en función a la opción seleccionada
    DateTime startDate;
    if (selectedPeriod == 'week') {
      startDate = DateTime.now().subtract(const Duration(days: 7));
    } else if (selectedPeriod == 'month') {
      startDate = DateTime.now().subtract(const Duration(days: 30));
    } else if (selectedPeriod == 'year') {
      startDate = DateTime.now().subtract(const Duration(days: 365));
    } else {
      startDate = DateTime.now();
      for (var movement in expensesByDay) {
        if (movement['date'] != null) {
          var date = DateFormat('dd-MM-yyyy').parse(movement['date']! as String);
          if (date.isBefore(startDate)) {
            startDate = date;
          }
        }
      }
    }
    // Generar la lista de días entre la fecha de inicio y la fecha actual
    List<String> days = [];
    var currentDate = startDate;
    while (currentDate.isBefore(DateTime.now())) {
      days.add(DateFormat('dd-MM-yyyy').format(currentDate));
      currentDate = currentDate.add(const Duration(days: 1));
    }
    // generar los grupos de barras
    List<BarChartGroupData> groups = [];
    double sum = 0;
    for (var i = 0; i < days.length; i++) {
      var day = days[i];
      var matches = expensesByDay.where((element) => element['date'] == day);
      double amount = matches.isEmpty ? 0 : matches.first['total'] as double;
      sum += amount;
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: accumulated ? sum : amount,
            color: Colors.blue,
          ),
        ],
      ));
    }
    // Calcular los valores mínimos y máximos
    var minAmount = expensesByDay.map((e) => e['total'] as double).reduce(min);
    var maxAmount = expensesByDay.map((e) => e['total'] as double).reduce(max);
    double minY = min(0, minAmount);
    double maxY = accumulated ? groups.last.barRods[0].toY : maxAmount;
    setState(() {
      this.expensesByDay = expensesByDay;
      this.days = days;
      this.groups = groups;
      this.minY = minY;
      this.maxY = maxY;
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
        buildAccumulatedSwitch(context),
        const SizedBox(height: 15),
        if (expensesByDay == null) const Center(child: Loader()) else if (expensesByDay!.isEmpty) buildEmptyMessage(context) else buildChart(context),
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
          getExpensesByDay();
        });
      },
    );
  }

  Widget buildPeriodSelect(BuildContext context) {
    var options = ['week', 'month', 'year', null];
    var optionNames = ['1 sem', '1 mes', '1 año', 'Todos'];
    return ButtonSelector(
      options: optionNames.map((e) => Text(e)).toList(),
      selectedIndex: options.indexOf(selectedPeriod),
      onSelectionChange: (index) {
        setState(() {
          selectedPeriod = options[index];
          getExpensesByDay();
        });
      },
    );
  }

  Widget buildAccumulatedSwitch(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Acumulado', style: TextStyle(fontSize: 18, color: Theme.of(context).primaryColor)),
        const SizedBox(width: 20),
        CupertinoSwitch(
          value: accumulated,
          onChanged: (value) {
            setState(() {
              accumulated = value;
              if (expensesByDay != null && expensesByDay!.isNotEmpty) {
                doCalculations(expensesByDay!);
              }
            });
          },
        ),
      ],
    );
  }

  Widget buildEmptyMessage(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 20),
      child: Center(child: Text('No hay datos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
    );
  }

  Widget buildChart(BuildContext context) {
    if (groups != null && days != null && minY != null && maxY != null) {
      return SizedBox(
        height: 300,
        child: BarChart(
          BarChartData(
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipHorizontalAlignment: FLHorizontalAlignment.center,
                tooltipMargin: 0,
                fitInsideVertically: true,
                fitInsideHorizontally: true,
                getTooltipItem: (group, groupIndex, rod, rodIndex) => getTooltipItem(days![groupIndex], rod.toY),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              drawHorizontalLine: true,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.shade300,
                strokeWidth: 1,
              ),
              getDrawingVerticalLine: (value) => FlLine(
                color: Colors.grey.shade300,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 110,
                  getTitlesWidget: (value, meta) => bottomTitleWidgets(days![value.toInt()], meta, (value % (days!.length / 10).ceil()) == 0),
                ),
              ),
              leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: ((maxY! - minY!) / 5).ceil().toDouble(),
                    getTitlesWidget: (value, meta) => leftTitleWidgets(value, meta, (value % ((maxY! - minY!) / 5).ceil()) == 0),
                    reservedSize: 50,
                  ),
                  axisNameWidget: getLeftAxisName(),
                  axisNameSize: 15
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                left: BorderSide(color: Colors.grey.shade400),
                bottom: BorderSide(color: Colors.grey.shade400),
              ),
            ),
            minY: minY!,
            maxY: maxY!,
            barGroups: groups!,
          ),
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  Widget bottomTitleWidgets(String value, TitleMeta meta, bool show) {
    if (show) {
      return SideTitleWidget(
        axisSide: meta.axisSide,
        child: Padding(
          padding: const EdgeInsets.only(top: 35),
          child: Transform.rotate(angle: 70 * pi / 180, child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        ),
      );
    } else {
      return SideTitleWidget(
        axisSide: meta.axisSide,
        child: const SizedBox(),
      );
    }
  }

  Widget leftTitleWidgets(double value, TitleMeta meta, bool show) {
    if (show) {
      String text = value.toStringAsFixed(0);
      if (value > 1000) {
        text = '${ (value / 1000).toStringAsFixed(0) }k';
      }
      if (value > 1000000) {
        text = '${ (value / 1000000).toStringAsFixed(1) }M';
      }

      return Padding(
        padding: const EdgeInsets.only(right: 5),
        child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
      );
    } else {
      return SideTitleWidget(
        axisSide: meta.axisSide,
        child: const SizedBox(),
      );
    }
  }

  BarTooltipItem getTooltipItem(String day, double value) {
    String text = value.toStringAsFixed(0);
    if (value > 1000) {
      text = '${ (value / 1000).toStringAsFixed(0) }k';
    }
    if (value > 1000000) {
      text = '${ (value / 1000000).toStringAsFixed(1) }M';
    }
    var currency = GetIt.instance.get<UtilsService>().getCurrencySymbol(widget.account?.currency ?? Currency.USD);
    return BarTooltipItem(
      '',
      const TextStyle(fontSize: 14, color: Colors.white),
      children: [
        TextSpan(text: '$day\n', style: const TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: '$currency $text'),
      ]
    );
  }

  Widget getLeftAxisName() {
    String text = '';
    if (accumulated) {
      if (selectedMovementType == MovementType.ADD) {
        text = 'Ingresos acumulados';
      } else if (selectedMovementType == MovementType.REMOVE) {
        text = 'Gastos acumulados';
      } else if (selectedMovementType == MovementType.TRANSFER) {
        text = 'Transferencias acumuladas';
      }
    } else {
      if (selectedMovementType == MovementType.ADD) {
        text = 'Ingresos';
      } else if (selectedMovementType == MovementType.REMOVE) {
        text = 'Gastos';
      } else if (selectedMovementType == MovementType.TRANSFER) {
        text = 'Transferencias';
      }
    }
    text += ' (${ GetIt.instance.get<UtilsService>().getCurrencySymbol(widget.account?.currency ?? Currency.USD) })';
    return Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor));
  }
}
