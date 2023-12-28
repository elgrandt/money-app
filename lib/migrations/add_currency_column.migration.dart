


import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/migrations/migration_definition.dart';
import 'package:money/repositories/accounts.repository.dart';

var logger = GetIt.instance.get<Logger>();

var addCurrencyColumnMigration = MigrationDefinition(
  'add_currency_column',
  () async {
    var accountRespository = await GetIt.instance.get<AccountsRepository>();
    accountRespository.db.rawQuery('ALTER TABLE ${ accountRespository.tableName } ADD COLUMN currency NOT NULL DEFAULT "ARS"');
  }, () async {
    logger.e('Cannot down this migration');
  }
);