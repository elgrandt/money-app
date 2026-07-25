import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/migrations/migration_definition.dart';
import 'package:money/services/database.service.dart';

var logger = GetIt.instance.get<Logger>();

var rebuildCurrencyRatesBuySellMigration = MigrationDefinition(
  'rebuild_currency_rates_buy_sell',
  () async {
    var databaseService = GetIt.instance.get<DatabaseService>();
    await databaseService.db.execute('DROP TABLE IF EXISTS currency_rates');
    await databaseService.currencyRatesRepository.initializeTable();
  }, () async {
    logger.e('Cannot down this migration');
  }
);
