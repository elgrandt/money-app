
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';
import '../models/base.model.dart';

enum DatabaseColumnType {
  NULL,
  INTEGER,
  REAL,
  TEXT,
  BLOB,
  DATE
}

enum PrimaryKeyOrder {
  ASC,
  DESC
}

class PrimaryKeyDefinition {
  PrimaryKeyOrder? order;
  bool autoincrement;

  PrimaryKeyDefinition({ this.order, this.autoincrement = false });

  @override
  String toString() {
    var str = ' PRIMARY KEY';
    if (order != null) {
      str += ' ${ order!.name }';
    }
    if (autoincrement) {
      str += ' AUTOINCREMENT';
    }
    return str;
  }
}

enum ForeignKeyOnDeleteUpdateDefinition {
  SET_NULL,
  SET_DEFAULT,
  CASCADE,
  RESTRICT,
  NO_ACTION
}

enum DeferredInitialValue {
  DEFERRED,
  IMMEDIATE
}

class ForeignKeyDefinition {
  String table;
  List<String>? columns;
  ForeignKeyOnDeleteUpdateDefinition? onDelete;
  ForeignKeyOnDeleteUpdateDefinition? onUpdate;
  String? match;
  bool? deferrable;
  DeferredInitialValue? initialDeferred;

  ForeignKeyDefinition(this.table, { this.columns, this.onDelete, this.onUpdate, this.match, this.deferrable, this.initialDeferred });

  @override
  String toString() {
    var str = ' REFERENCES $table';
    if (columns != null && columns!.isNotEmpty) {
      str += ' (${ columns!.join(',') })';
    }
    if (onDelete != null) {
      str += ' ON DELETE ${ onDelete!.name.replaceAll('_', ' ') }';
    }
    if (onUpdate != null) {
      str += ' ON UPDATE ${ onUpdate!.name.replaceAll('_', ' ') }';
    }
    if (match != null) {
      str += ' MATCH $match';
    }
    if (deferrable != null) {
      str += ' ${deferrable! ? '' : 'NOT '}DEFERRABLE';
    }
    if (initialDeferred != null) {
      str += ' INITIALLY ${initialDeferred!.name}';
    }
    return str;
  }
}

class DatabaseColumnDefinition {
  String name;
  DatabaseColumnType type;
  bool nullable;
  bool unique;
  PrimaryKeyDefinition? primaryKey;
  String? check;
  String? defaultValue;
  String? collate;
  ForeignKeyDefinition? foreignKey;

  DatabaseColumnDefinition(this.name, this.type, { this.nullable = false, this.unique = false, this.primaryKey, this.check, this.defaultValue, this.collate, this.foreignKey });

  @override
  String toString() {
    String definition = '$name ${type.name}';
    if (primaryKey != null) {
      definition += primaryKey.toString();
    } else if (unique) {
      definition += ' UNIQUE';
    } else if (check != null) {
      definition += ' CHECK ($check)';
    } else if (defaultValue != null) {
      definition += ' DEFAULT $defaultValue';
    } else if (collate != null) {
      definition += ' COLLATE $collate';
    } else if (foreignKey != null) {
      definition += foreignKey.toString();
    } else if (!nullable) {
      definition += ' NOT NULL';
    }
    return definition;
  }
}

abstract class BaseRepository<Model extends BaseModel> {
  Database db;
  String tableName;
  List<DatabaseColumnDefinition> columnDefinitions;

  BaseRepository(this.db, this.tableName, this.columnDefinitions);

  Future<void> initializeTable() {
    var command = 'create table $tableName (${ columnDefinitions.join(', ') })';
    GetIt.instance.get<Logger>().d('Initializing table $command');
    return db.execute(command);
  }

  Future<Model> insert(Model model) async {
    model.id = await db.insert(tableName, modelToMap(model));
    return model;
  }

  Future<Model?> findById(int id, { List<String>? columns }) async {
    var results = await find(
        columns: columns,
        where: 'id = ?',
        args: [id]
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<List<Model>> find({ List<String>? columns, String? where, List<Object?> args = const[], int? limit, int? offset, String? orderBy }) async {
    var allColumns = columnDefinitions.map((column) => column.name).toList();
    List<Map<String, Object?>> maps = await db.query(
      tableName,
      columns: columns ?? allColumns,
      where: where,
      whereArgs: args,
      limit: limit,
      offset: offset,
      orderBy: orderBy
    );
    return maps.map((map) => mapToModel(map)).toList();
  }

  Future<int> delete(int id) async {
    return await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> update(Model model) async {
    return await db.update(tableName, modelToMap(model), where: 'id = ?', whereArgs: [model.id]);
  }

  Map<String, Object?> modelToMap(Model model);

  Model mapToModel(Map<String, Object?> map);
}