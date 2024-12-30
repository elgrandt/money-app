import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/accounts/account_list.dart';
import 'package:money/views/backups/backups.dart';
import 'package:money/views/categories/category_list.dart';
import 'package:money/views/home/home.dart';
import 'package:money/views/statistics/statistics.dart';

void main() async {
  runApp(const MoneyApp());
  initializeLogger();
  initializeServices();
  initializeDatabase();
}

void initializeLogger() {
  var logger = Logger(
      printer: SimplePrinter()
  );
  logger.i('Starting application');
  GetIt.instance.registerSingleton(logger);
}

void initializeDatabase() {
  GetIt.instance.get<DatabaseService>().initialize();
}

void initializeServices() {
  GetIt.instance.registerSingleton(UtilsService());
  GetIt.instance.registerSingleton(DatabaseService());
}

class MoneyApp extends StatelessWidget {
  const MoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'AR'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routes: {
        '/': (context) => const Home(),
        '/accounts': (context) => const AccountList(),
        '/categories': (context) => const CategoryList(),
        '/statistics': (context) => const Statistics(),
        '/backups': (context) => const Backups(),
      },
    );
  }
}
