import 'package:money/migrations/accounts_initialization.migration.dart';
import 'package:money/migrations/add_created_at_to_currency_rates.migration.dart';
import 'package:money/migrations/add_deleted_field_to_account.migration.dart';
import 'package:money/migrations/add_sort_index_field_to_account.migration.dart';
import 'package:money/migrations/add_showTotal_field_to_account.migration.dart';
import 'package:money/migrations/backfill_currency_rates_history.migration.dart';
import 'package:money/migrations/categories_initialization.migration.dart';
import 'package:money/migrations/currency_rates_initialization.migration.dart';
import 'package:money/migrations/example.migration.dart';
import 'package:money/migrations/migration_definition.dart';
import 'package:money/migrations/movements_initialization.migration.dart';
import 'package:money/migrations/rebuild_currency_rates_buy_sell.migration.dart';

List<MigrationDefinition> migrationDefinitions = [
  exampleMigration,
  accountsInitializationMigration,
  movementsInitializationMigration,
  categoriesInitializationMigration,
  addSortIndexFieldToAccountMigration,
  addShowTotalFieldToAccountMigration,
  addDeletedFieldToAccountMigration,
  currencyRatesInitializationMigration,
  rebuildCurrencyRatesBuySellMigration,
  addCreatedAtToCurrencyRatesMigration,
  backfillCurrencyRatesHistoryMigration,
];
