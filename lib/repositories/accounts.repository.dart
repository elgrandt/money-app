
import 'package:money/models/account.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:sqflite/sqflite.dart';

class AccountsRepository extends BaseRepository<Account> {
  static List<DatabaseColumnDefinition> accountColumns = [
    DatabaseColumnDefinition('id', DatabaseColumnType.INTEGER, primaryKey: PrimaryKeyDefinition(autoincrement: true)),
    DatabaseColumnDefinition('name', DatabaseColumnType.TEXT),
    DatabaseColumnDefinition('total', DatabaseColumnType.REAL),
    DatabaseColumnDefinition('currency', DatabaseColumnType.TEXT),
  ];

  AccountsRepository(Database db): super(db, 'accounts', AccountsRepository.accountColumns);

  @override
  Map<String, Object?> modelToMap(Account model) {
    var map = <String, Object?>{};
    if (model.id != null) {
      map['id'] = model.id;
    }
    map['name'] = model.name;
    map['total'] = model.total;
    map['currency'] = model.currency.name;
    return map;
  }

  @override
  Account mapToModel(Map<String, Object?> map) {
    return Account(
      name: map['name'] as String,
      total: map['total'] as double,
      currency: Currency.values.byName(map['currency'] as String),
      id: map['id'] as int?
    );
  }

  Future<void> updateBalance(int id, double amount) async {
    var account = await findById(id);
    if (account != null) {
      account.total += amount;
      await update(account);
    } else {
      throw Exception('Account not found');
    }
  }
}