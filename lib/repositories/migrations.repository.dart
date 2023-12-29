
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/models/migration.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:money/migrations/migrations_list.dart';
import 'package:sqflite/sqflite.dart';

class MigrationsRepository extends BaseRepository<Migration> {
  Logger logger = GetIt.instance.get<Logger>();

  static List<DatabaseColumnDefinition> migrationColumns = [
    DatabaseColumnDefinition('id', DatabaseColumnType.INTEGER, primaryKey: PrimaryKeyDefinition(autoincrement: true)),
    DatabaseColumnDefinition('name', DatabaseColumnType.TEXT),
  ];

  MigrationsRepository(Database db): super(db, 'migrations', MigrationsRepository.migrationColumns);

  @override
  Map<String, Object?> modelToMap(Migration model) {
    var map = <String, Object?>{};
    if (model.id != null) {
      map['id'] = model.id;
    }
    map['name'] = model.name;
    return map;
  }

  @override
  Migration mapToModel(Map<String, Object?> map) {
    return Migration(
      map['name'] as String,
      id: map['id'] as int?
    );
  }

  Future<void> sync() async {
    logger.i('Starting migration sync');
    var migrationsRan = (await find()).map((migration) => migration.name).toList();
    for (var migrationDefinition in migrationDefinitions) {
      var ran = migrationsRan.contains(migrationDefinition.name);
      if (!ran) {
        await runMigration(migrationDefinition.name);
      }
    }
  }

  Future<void> runMigration(String name) async {
    logger.d('Running migration $name');
    var definition = migrationDefinitions.firstWhere((def) => def.name == name);
    try {
      await definition.up();
      insert(Migration(name));
      logger.d('Migration $name ran successfully');
    } catch (error) {
      logger.e('Error running migration', error: error);
    }
  }

  Future<void> downMigration(String name) async {
    logger.d('Running migration down $name');
    var migrations = await find(where: 'name = ?', args: [name]);
    if (migrations.isEmpty) throw ArgumentError('La migración $name no está en la base de datos');
    var definition = migrationDefinitions.firstWhere((def) => def.name == name);
    try {
      await definition.down();
      await delete(migrations.first.id!);
      logger.d('Migration down $name ran successfully');
    } catch (error) {
      logger.e('Error running migration', error: error);
    }
  }
}