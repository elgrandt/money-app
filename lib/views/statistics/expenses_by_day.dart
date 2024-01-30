
import 'package:flutter/material.dart';
import 'package:money/models/account.model.dart';

class ExpensesByDayChart extends StatefulWidget {
  final Account? account;

  const ExpensesByDayChart({ super.key, this.account });

  @override
  State<ExpensesByDayChart> createState() => _ExpensesByDayChartState();
}

class _ExpensesByDayChartState extends State<ExpensesByDayChart> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
