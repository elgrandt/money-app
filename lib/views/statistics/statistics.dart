
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/services/database.service.dart';
import 'package:money/views/generics/cupertino_select.dart';
import 'package:money/views/generics/loader.dart';
import 'package:money/views/generics/navbar.dart';
import 'package:money/views/statistics/expenses_by_category.dart';
import 'package:money/views/statistics/expenses_by_day.dart';

class Statistics extends StatefulWidget {
  const Statistics({super.key});

  @override
  State<Statistics> createState() => _StatisticsState();
}

class _StatisticsState extends State<Statistics> {
  Account? account;
  String? chartType;
  List<Account>? accounts;
  var databaseService = GetIt.instance.get<DatabaseService>();
  var logger = GetIt.instance.get<Logger>();

  @override
  initState() {
    super.initState();
    getAccounts();
  }

  Future<void> getAccounts() async {
    await databaseService.initialized;
    try {
      logger.d('Getting accounts');
      var accounts = await databaseService.accountsRepository.find(orderBy: 'sortIndex ASC');
      setState(() {
        this.accounts = accounts;
      });
    } catch (error, stackTrace) {
      logger.e('Error getting accounts', error: error, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navbar(
      title: 'Estadísticas',
      body: accounts == null ? const Loader() : buildStatisticsPage(context),
    );
  }

  Widget buildStatisticsPage(BuildContext context) {
    return ListView(
      children: [
        buildAccountSelector(context),
        buildChartTypeSelector(context),
        if (chartType != null)
          Padding(
            padding: const EdgeInsets.all(10),
            child: buildChart(context),
          ),
      ],
    );
  }

  Widget buildAccountSelector(BuildContext context) {
    var options = [
      'Todas',
      ...accounts!.map((account) => account.name),
    ];
    return ListTile(
      title: const Text('Cuenta'),
      trailing: CupertinoSelect(
        options: options,
        selectedIndex: account == null ? 0 : accounts!.indexOf(account!) + 1,
        onSelectedIndexChange: (index) {
          setState(() {
            account = index == 0 ? null : accounts![index - 1];
          });
        },
      ),
    );
  }

  Widget buildChartTypeSelector(BuildContext context) {
    var options = [
      'Ninguno',
      'Gastos por categoría',
      'Gastos por día',
    ];
    return ListTile(
      title: const Text('Tipo de gráfico'),
      trailing: CupertinoSelect(
        options: options,
        selectedIndex: chartType == null ? 0 : options.indexOf(chartType!),
        onSelectedIndexChange: (index) {
          setState(() {
            chartType = index == 0 ? null : options[index];
          });
        },
      ),
    );
  }

  Widget buildChart(BuildContext context) {
    if (chartType == 'Gastos por categoría') {
      return ExpensesByCategoryChart(account: account);
    } else if (chartType == 'Gastos por día') {
      return ExpensesByDayChart(account: account);
    } else {
      return Container();
    }
  }
}
