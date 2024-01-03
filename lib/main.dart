import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/home/home.dart';

void main() async {
  GlobalKey<MoneyAppState> appKey = GlobalKey();
  runApp(MoneyApp(key: appKey));
  GetIt.instance.registerSingleton(appKey);
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

class MoneyApp extends StatefulWidget {
  const MoneyApp({super.key});

  @override
  State<MoneyApp> createState() => MoneyAppState();
}

class MoneyAppState extends State<MoneyApp> {

  @override
  void initState() {
    super.initState();
  }

  void reRender() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // ignore: prefer_const_constructors
      home: Home(),
    );
  }
}
