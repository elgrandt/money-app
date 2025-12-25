
import 'package:get_it/get_it.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:money/services/database.service.dart';
import 'package:sqflite/sqflite.dart';

class AccountsRepository extends BaseRepository<Account> {
  static List<DatabaseColumnDefinition> accountColumns = [
    DatabaseColumnDefinition('id', DatabaseColumnType.INTEGER, primaryKey: PrimaryKeyDefinition(autoincrement: true)),
    DatabaseColumnDefinition('name', DatabaseColumnType.TEXT),
    DatabaseColumnDefinition('total', DatabaseColumnType.REAL),
    DatabaseColumnDefinition('currency', DatabaseColumnType.TEXT),
    DatabaseColumnDefinition('sortIndex', DatabaseColumnType.INTEGER),
    DatabaseColumnDefinition('showTotal', DatabaseColumnType.INTEGER),
    DatabaseColumnDefinition('deleted', DatabaseColumnType.INTEGER),
  ];

  var databaseService = GetIt.instance.get<DatabaseService>();

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
    map['sortIndex'] = model.sortIndex;
    map['showTotal'] = model.showTotal ? 1 : 0;
    map['deleted'] = model.deleted ? 1 : 0;
    return map;
  }

  @override
  Account mapToModel(Map<String, Object?> map) {
    return Account(
      name: map['name'] as String,
      total: map['total'] as double,
      currency: Currency.values.byName(map['currency'] as String),
      id: map['id'] as int?,
      sortIndex: map['sortIndex'] as int,
      showTotal: map['showTotal'] == 1,
      deleted: map['deleted'] == 1,
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

  Future<void> switchShowTotal(int id) async {
    var account = await findById(id);
    if (account != null) {
      account.showTotal = !account.showTotal;
      await update(account);
    } else {
      throw Exception('Account not found');
    }
  }

  @override
  Future<int> delete(int id) async {
    var account = await findById(id);
    if (account != null) {
      await removeAllAccountMovements(id);
      account.deleted = true;
      await update(account);
      return 1;
    } else {
      throw Exception('Account not found');
    }
  }

  Future<void> removeAllAccountMovements(int accountId) async {
    // Get all movements for the account
    var movements = await databaseService.movementsRepository.find(
      where: 'sourceId = ? OR targetId = ?',
      args: [accountId, accountId],
    );
    // Delete add or remove movements
    var addOrRemoveMovements = movements.where((movement) => movement.type == MovementType.ADD || movement.type == MovementType.REMOVE).toList();
    var addOrRemoveMovementIds = addOrRemoveMovements.map((m) => m.id!).toList();
    await databaseService.movementsRepository.deleteMany(addOrRemoveMovementIds);
  }

  @override
  Future<List<Account>> find({ List<String>? columns, String? where, List<Object?> args = const[], int? limit, int? offset, String? orderBy }) async {
    return await super.find(columns: columns, where: where, args: args, limit: limit, offset: offset, orderBy: orderBy)
      .then((accounts) => accounts.where((account) => !account.deleted).toList());
  }
}
