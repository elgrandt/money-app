


import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/migrations/migration_definition.dart';
import 'package:money/repositories/movements.repository.dart';

var logger = GetIt.instance.get<Logger>();

var movementsInitializationMigration = MigrationDefinition(
  'movements_initialization',
  () async {
    await GetIt.instance.get<MovementsRepository>().initializeTable();
  }, () async {
    logger.e('Cannot down this migration');
  }
);