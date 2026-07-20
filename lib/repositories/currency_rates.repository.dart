import 'package:money/models/currency_rates.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:sqflite/sqflite.dart';

class CurrencyRatesRepository extends BaseRepository<CurrencyRates> {
  static List<DatabaseColumnDefinition> currencyRatesColumns = [
    DatabaseColumnDefinition('id', DatabaseColumnType.INTEGER, primaryKey: PrimaryKeyDefinition(autoincrement: true)),
    DatabaseColumnDefinition('usdToArs', DatabaseColumnType.REAL),
    DatabaseColumnDefinition('eurToArs', DatabaseColumnType.REAL),
    DatabaseColumnDefinition('eurToUsd', DatabaseColumnType.REAL),
    DatabaseColumnDefinition('updatedAt', DatabaseColumnType.DATE),
  ];

  CurrencyRatesRepository(Database db): super(db, 'currency_rates', CurrencyRatesRepository.currencyRatesColumns);

  @override
  Map<String, Object?> modelToMap(CurrencyRates model) {
    var map = <String, Object?>{};
    if (model.id != null) {
      map['id'] = model.id;
    }
    map['usdToArs'] = model.usdToArs;
    map['eurToArs'] = model.eurToArs;
    map['eurToUsd'] = model.eurToUsd;
    map['updatedAt'] = model.updatedAt.toIso8601String();
    return map;
  }

  @override
  CurrencyRates mapToModel(Map<String, Object?> map) {
    return CurrencyRates(
      usdToArs: map['usdToArs'] as double,
      eurToArs: map['eurToArs'] as double,
      eurToUsd: map['eurToUsd'] as double,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      id: map['id'] as int?,
    );
  }

  Future<CurrencyRates?> findLatest() async {
    var results = await find(orderBy: 'id DESC', limit: 1);
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<void> saveLatest(CurrencyRates rates) async {
    var existing = await findLatest();
    if (existing != null) {
      rates.id = existing.id;
      await update(rates);
    } else {
      await insert(rates);
    }
  }
}
