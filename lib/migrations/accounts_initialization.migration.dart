


import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/migrations/migration_definition.dart';
import 'package:money/repositories/accounts.repository.dart';

var logger = GetIt.instance.get<Logger>();

var accountsInitializationMigration = MigrationDefinition(
  'accounts_initialization',
  () async {
    await GetIt.instance.get<AccountsRepository>().initializeTable();
  }, () async {
    logger.e('Cannot down this migration');
  }
);