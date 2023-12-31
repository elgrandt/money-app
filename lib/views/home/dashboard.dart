
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:money/models/account.model.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/generics/easy_pie_chart.dart';
import 'package:money/views/home/total_viewer.dart';

class Dashboard extends StatelessWidget {
  final List<Account> accounts;

  const Dashboard({ super.key, required this.accounts });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        buildTotal(context),
        buildTotalsChart(context),
      ],
    );
  }

  Widget buildTotal(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        const Text('Patrimonio total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        TotalViewer(accounts: accounts, currency: Currency.USD)
      ],
    );
  }

  Widget buildTotalsChart(BuildContext context) {
    return EasyPieChart(
      labelPosition: LabelPosition.bottom,
      randomGenerator: Random(124),
      items: accounts,
      label: (account) => account.name,
      value: (account) => max(GetIt.instance.get<UtilsService>().convertCurrencies(account.total, account.currency, Currency.USD) , 0),
      maxWidth: 200,
      maxHeight: 200,
      maxLabelWidth: 200,
    );
  }
}