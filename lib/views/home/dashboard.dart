
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:money/models/account.model.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/generics/easy_pie_chart.dart';
import 'package:money/views/home/total_viewer.dart';
import 'package:money/views/statistics/all_expenses.dart';
import 'package:money/views/statistics/expenses_by_category.dart';
import 'package:money/views/statistics/expenses_by_day.dart';

class Dashboard extends StatelessWidget {
  final List<Account> accounts;

  const Dashboard({ super.key, required this.accounts });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 15),
          buildTotal(context),
          buildTotalsChart(context),
          const SizedBox(height: 15),
          const Divider(),
          const SizedBox(height: 15),
          buildAllExpensesChart(context),
          const SizedBox(height: 15),
          const Divider(),
          const SizedBox(height: 15),
          buildExpensesByCategoryChart(context),
          const SizedBox(height: 15),
          const Divider(),
          const SizedBox(height: 15),
          buildExpensesByDayChart(context),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget buildTotal(BuildContext context) {
    return Column(
      key: Key('total'),
      children: [
        const SizedBox(height: 10),
        const Text('Patrimonio total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        TotalViewer(accounts: accounts, currency: Currency.USD)
      ],
    );
  }

  Widget buildTotalsChart(BuildContext context) {
    return EasyPieChart(
      key: Key('totals-chart'),
      labelPosition: LabelPosition.bottom,
      randomGenerator: Random(124),
      items: accounts,
      label: (account) => account.name,
      value: (account) => max(GetIt.instance.get<UtilsService>().convertCurrencies(account.total, account.currency, Currency.USD) , 0),
      maxWidth: 150,
      maxHeight: 150,
      maxLabelWidth: 200,
    );
  }

  Widget buildExpensesByCategoryChart(BuildContext context) {
    return const Column(
      key: Key('expenses-by-category'),
      children: [
        Text('Movimientos por categoría', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        SizedBox(height: 20),
        ExpensesByCategoryChart(),
      ],
    );
  }

  Widget buildExpensesByDayChart(BuildContext context) {
    return const Column(
      key: Key('expenses-by-day'),
      children: [
        Text('Movimientos por día', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        SizedBox(height: 20),
        ExpensesByDayChart(),
      ],
    );
  }

  Widget buildAllExpensesChart(BuildContext context) {
    return const Column(
      key: Key('all-expenses'),
      children: [
        Text('Últimos movimientos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        SizedBox(height: 20),
        AllExpensesChart(),
      ],
    );
  }
}