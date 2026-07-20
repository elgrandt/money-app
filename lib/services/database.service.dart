
import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/repositories/accounts.repository.dart';
import 'package:money/repositories/categories.repository.dart';
import 'package:money/repositories/migrations.repository.dart';
import 'package:money/repositories/movements.repository.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  // Private fields
  final _autosync = true;
  final _logger = GetIt.instance.get<Logger>();
  Future<void>? _createdTables;
  final Completer<void> _initializedCompleter = Completer<void>();

  // Public fields
  late Database db;
  late MigrationsRepository migrationsRepository;
  late MovementsRepository movementsRepository;
  late AccountsRepository accountsRepository;
  late CategoriesRepository categoriesRepository;
  // Add new repositories here
  
  Future<void> get initialized {
    return _initializedCompleter.future;
  }

  DatabaseService();

  void createTables(Database db) {
    _logger.i('Creating tables');
    _createdTables = MigrationsRepository(db).initializeTable();
  }

  void initialize() {
    openDatabase(
      'db.sqlite',
      version: 1,
      onCreate: (Database db, int version) async {
        createTables(db);
      },
    ).then((db) {
      _logger.i('Connected to the database');
      this.db = db;
      initializeRepositories();
    }).onError((error, stackTrace) {
      _logger.e('Error connecting to the database', error: error, stackTrace: stackTrace);
      if (!_initializedCompleter.isCompleted) {
        _initializedCompleter.completeError(error ?? Exception('Database initialization failed'), stackTrace);
      }
    });
  }

  Future<void> initializeRepositories() async {
    if (_createdTables != null) await _createdTables;
    migrationsRepository = MigrationsRepository(db);
    movementsRepository = MovementsRepository(db);
    accountsRepository = AccountsRepository(db);
    categoriesRepository = CategoriesRepository(db);
    // Add new repositories here
    if (_autosync) {
      await migrationsRepository.sync();
    }
    _initializedCompleter.complete();
    _logger.i('Finished database initialization');
  }

  Future<void> deleteAllData() async {
    await movementsRepository.deleteAll();
    await accountsRepository.deleteAll();
    await categoriesRepository.deleteAll();
    // Add new repositories here
  }
}
