import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/migrations/migration_definition.dart';
import 'package:money/services/database.service.dart';
import 'package:sqflite/sqflite.dart';

var logger = GetIt.instance.get<Logger>();

var addCreatedAtToCurrencyRatesMigration = MigrationDefinition(
  'add_created_at_to_currency_rates',
  () async {
    var databaseService = GetIt.instance.get<DatabaseService>();
    try {
      await databaseService.db.execute('ALTER TABLE currency_rates ADD createdAt DATE');
    } catch (error) {
      if (error is DatabaseException && error.isDuplicateColumnError()) {
        logger.w('createdAt column already exists');
      } else {
        rethrow;
      }
    }
    await databaseService.db.execute('UPDATE currency_rates SET createdAt = updatedAt WHERE createdAt IS NULL');
  }, () async {
    logger.e('Cannot down this migration');
  }
);
