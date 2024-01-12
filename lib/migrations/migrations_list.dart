
import 'package:money/migrations/accounts_initialization.migration.dart';
import 'package:money/migrations/add_order_field_to_account.migration.dart';
import 'package:money/migrations/categories_initialization.migration.dart';
import 'package:money/migrations/example.migration.dart';
import 'package:money/migrations/migration_definition.dart';
import 'package:money/migrations/movements_initialization.migration.dart';

List<MigrationDefinition> migrationDefinitions = [
  exampleMigration,
  accountsInitializationMigration,
  movementsInitializationMigration,
  categoriesInitializationMigration,
  addSortIndexFieldToAccountMigration,
];