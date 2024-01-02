


import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/migrations/migration_definition.dart';
import 'package:money/services/database.service.dart';

var logger = GetIt.instance.get<Logger>();

var categoriesInitializationMigration = MigrationDefinition(
  'categories_initialization',
  () async {
    var databaseService = GetIt.instance.get<DatabaseService>();
    databaseService.categoriesRepository.initializeTable();
  }, () async {
    logger.e('Cannot down this migration');
  }
);