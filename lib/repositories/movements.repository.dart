
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:money/services/database.service.dart';
import 'package:sqflite/sqflite.dart';

class MovementsRepository extends BaseRepository<Movement> {
  static List<DatabaseColumnDefinition> movementColumns = [
    DatabaseColumnDefinition('id', DatabaseColumnType.INTEGER, primaryKey: PrimaryKeyDefinition(autoincrement: true)),
    DatabaseColumnDefinition('creationDate', DatabaseColumnType.DATE, defaultValue: 'current_timestamp'),
    DatabaseColumnDefinition('type', DatabaseColumnType.TEXT),
    DatabaseColumnDefinition('description', DatabaseColumnType.TEXT),
    DatabaseColumnDefinition('amount', DatabaseColumnType.REAL),
    DatabaseColumnDefinition('category', DatabaseColumnType.TEXT),
    DatabaseColumnDefinition('sourceId', DatabaseColumnType.INTEGER, foreignKey: ForeignKeyDefinition('accounts')),
    DatabaseColumnDefinition('targetId', DatabaseColumnType.INTEGER, foreignKey: ForeignKeyDefinition('accounts')),
  ];

  var logger = GetIt.instance.get<Logger>();
  var databaseService = GetIt.instance.get<DatabaseService>();

  MovementsRepository(Database db): super(db, 'movements', MovementsRepository.movementColumns);

  @override
  Map<String, Object?> modelToMap(Movement model) {
    var map = <String, Object?>{};
    if (model.id != null) {
      map['id'] = model.id;
    }
    map['type'] = model.type.name;
    map['description'] = model.description;
    map['amount'] = model.amount;
    map['category'] = model.category;
    map['sourceId'] = model.source?.id;
    map['targetId'] = model.target?.id;
    return map;
  }

  @override
  Movement mapToModel(Map<String, Object?> map) {
    var typeString = map['type'] as String;
    var type = MovementType.values.byName(typeString);
    Account? source;
    if (map.containsKey('source') && map['source'] != null) {
      source = databaseService.accountsRepository.mapToModel(map['source'] as Map<String, Object?>);
    }
    Account? target;
    if (map.containsKey('target') && map['target'] != null) {
      target = databaseService.accountsRepository.mapToModel(map['target'] as Map<String, Object?>);
    }
    return Movement(
      type,
      map['description'] as String,
      map['amount'] as double,
      map['category'] as String,
      id: map['id'] as int?,
      source: source,
      target: target,
      creationDate: DateTime.tryParse(map['creationDate'] as String),
    );
  }

  @override
  Future<List<Movement>> find({ List<String>? columns, String? where, List<Object?> args = const[], int? limit, int? offset, String? orderBy }) async {
    await GetIt.instance.allReady();
    List<String> fullColumns = [];
    for (var movementColumn in columnDefinitions) {
      if (columns == null || columns.contains(movementColumn.name)) {
        fullColumns.add('movement.${ movementColumn.name } AS movement_${ movementColumn.name }');
      }
    }
    for (var accountColumn in databaseService.accountsRepository.columnDefinitions) {
      fullColumns.add('source.${accountColumn.name} AS source_${accountColumn.name}');
      fullColumns.add('target.${accountColumn.name} AS target_${accountColumn.name}');
    }
    var query = 'SELECT ${ fullColumns.join(', ') } FROM $tableName AS movement LEFT JOIN accounts AS source ON movement.sourceId = source.id LEFT JOIN accounts as target ON movement.targetId = target.id';
    if (where != null) {
      query += ' WHERE $where';
    }
    if (orderBy != null) {
      query += ' ORDER BY $orderBy';
    }
    if (limit != null) {
      query += ' LIMIT $limit';
    }
    if (offset != null) {
      query += ' OFFSET $offset';
    }
    var results = await db.rawQuery(query, args);
    var maps = results.map((result) {
      Map<String, Object?> map = {};
      for (var columnName in result.keys) {
        if (columnName.startsWith('movement_')) {
          map[columnName.substring(9)] = result[columnName];
        }
      }
      if (map['sourceId'] != null && map['source_id'] != null) {
        Map<String, Object?> sourceMap = {};
        for (var columnName in result.keys) {
          if (columnName.startsWith('source_')) {
            sourceMap[columnName.substring(7)] = result[columnName];
          }
        }
        map['source'] = sourceMap;
      }
      if (map['targetId'] != null && map['target_id'] != null) {
        Map<String, Object?> targetMap = {};
        for (var columnName in result.keys) {
          if (columnName.startsWith('target_')) {
            targetMap[columnName.substring(7)] = result[columnName];
          }
        }
        map['target'] = targetMap;
      }
      return map;
    }).toList();
    var models = maps.map((map) => mapToModel(map)).toList();
    return models;
  }

  Future<List<Movement>> getLastMovements(Account? account, int page, int itemsPerPage) {
    return find(
      where: account != null ? 'sourceId = ? OR targetId = ?' : null,
      limit: itemsPerPage,
      offset: itemsPerPage * page,
      args: account != null ? [account.id, account.id] : [],
      orderBy: 'creationDate DESC'
    );
  }
}