
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/migrations/migration_definition.dart';

var logger = GetIt.instance.get<Logger>();

var exampleMigration = MigrationDefinition(
  'example',
  () async {
    logger.i('Running example migration (up)');
  }, () async {
    logger.i('Running example migration (down)');
  }
);