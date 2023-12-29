


import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/migrations/migration_definition.dart';
import 'package:money/services/database.service.dart';

var logger = GetIt.instance.get<Logger>();

var accountsInitializationMigration = MigrationDefinition(
  'accounts_initialization',
  () async {
    var databaseService = GetIt.instance.get<DatabaseService>();
    databaseService.accountsRepository.initializeTable();
  }, () async {
    logger.e('Cannot down this migration');
  }
);