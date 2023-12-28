import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/repositories/accounts.repository.dart';
import 'package:money/repositories/migrations.repository.dart';
import 'package:money/repositories/movements.repository.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/home/home.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  runApp(const MoneyApp());
  initializeLogger();
  initializeDatabase();
  initializeServices();
}

void initializeLogger() {
  var logger = Logger(
      printer: SimplePrinter()
  );
  logger.i('Starting application');
  GetIt.instance.registerSingleton(logger);
}

void initializeDatabase() {
  GetIt.instance.registerSingletonAsync(() {
    return openDatabase(
      'db.sqlite',
      version: 1,
      onCreate: (Database db, int version) async {
        GetIt.instance.get<Logger>().i('Creando tablas');
        await MigrationsRepository(db).initializeTable();
      },
    ).then((db) {
      GetIt.instance.get<Logger>().i('Conectado a la base de datos');
      GetIt.instance.registerSingleton(MigrationsRepository(db));
      GetIt.instance.registerSingleton(MovementsRepository(db));
      GetIt.instance.get<MigrationsRepository>().sync();
      return db;
    }).onError((error, stackTrace) {
      GetIt.instance.get<Logger>().e('Error conectado a la base de datos', error: error);
      throw stackTrace;
    });
  });
  GetIt.instance.registerSingletonWithDependencies(() {
    var db = GetIt.instance.get<Database>();
    return AccountsRepository(db);
  }, dependsOn: [Database]);
}

void initializeServices() {
  GetIt.instance.registerSingleton(UtilsService());
}

class MoneyApp extends StatelessWidget {
  const MoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Money',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routes: {
        '/': (context) => const Home(),
      },
    );
  }
}
