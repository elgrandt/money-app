


import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/migrations/migration_definition.dart';
import 'package:money/services/database.service.dart';
import 'package:sqflite/sqflite.dart';

var logger = GetIt.instance.get<Logger>();

var addShowTotalFieldToAccountMigration = MigrationDefinition(
  'add_showTotal_field_to_account',
  () async {
    var databaseService = GetIt.instance.get<DatabaseService>();
    try {
      await databaseService.db.execute('ALTER TABLE accounts ADD showTotal INT default 0 NOT NULL');
    } catch (error, stackTrace) {
      if (error is DatabaseException && error.isDuplicateColumnError()) {
        logger.w('Order column already exists');
      } else {
        rethrow;
      }
    }
  }, () async {
    logger.e('Cannot down this migration');
  }
);