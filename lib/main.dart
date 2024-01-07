import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/home/home.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Home(),
    );
  }
}
