# Data layer

The data layer is a thin, hand-rolled ORM over `sqflite`: models are plain classes, and each
table has a repository extending `BaseRepository<Model>` that owns the SQL, the map
conversions, and change events. For how the layers fit together see
[architecture.md](architecture.md).

## BaseModel

All models extend `BaseModel`, which carries a nullable `id` and defines equality by `id` —
[base.model.dart](../lib/models/base.model.dart). Models are plain Dart classes: mutable
fields, a positional/named constructor, and a `toString()` for logging. There is no JSON or
codegen; conversion to and from the database is done by hand in the repository.

## BaseRepository

`BaseRepository<Model>` provides the shared table operations —
[base.repository.dart:156-235](../lib/repositories/base.repository.dart#L156-L235):

- `initializeTable()` — builds and runs `CREATE TABLE` from the column definitions.
- `insert(model)` — inserts, assigns the generated `id`, emits an `InsertEvent`, returns the model.
- `findById(id, {columns})` — convenience wrapper over `find`.
- `find({columns, where, args, limit, offset, orderBy})` — queries and maps rows to models.
- `delete(id)` / `deleteMany(ids)` — delete, emitting `DeleteEvent`(s).
- `update(model)` — updates by `id`, emits an `UpdateEvent`.
- `count({where, args})` — row count.
- `deleteAll()` — clears the table.

Subclasses must implement the two abstract methods:

```dart
Map<String, Object?> modelToMap(Model model);
Model mapToModel(Map<String, Object?> map);
```

A concrete repository is constructed with its table name and column list, e.g.
`AccountsRepository(db) : super(db, 'accounts', AccountsRepository.accountColumns)`.

## The typed column DSL

Schema is declared with typed definition objects rather than raw SQL strings, which
`toString()` into a `CREATE TABLE` body —
[base.repository.dart:8-123](../lib/repositories/base.repository.dart#L8-L123):

- `DatabaseColumnType` — `NULL`, `INTEGER`, `REAL`, `TEXT`, `BLOB`, `DATE`.
- `DatabaseColumnDefinition(name, type, {nullable, unique, primaryKey, check, defaultValue, collate, foreignKey})`.
- `PrimaryKeyDefinition({order, autoincrement})`.
- `ForeignKeyDefinition(table, {columns, onDelete, onUpdate, ...})`.

Each repository declares its columns as a `static` list — for example
[accounts.repository.dart:10-18](../lib/repositories/accounts.repository.dart#L10-L18):

```dart
static List<DatabaseColumnDefinition> accountColumns = [
  DatabaseColumnDefinition('id', DatabaseColumnType.INTEGER, primaryKey: PrimaryKeyDefinition(autoincrement: true)),
  DatabaseColumnDefinition('name', DatabaseColumnType.TEXT),
  DatabaseColumnDefinition('total', DatabaseColumnType.REAL),
  DatabaseColumnDefinition('currency', DatabaseColumnType.TEXT),
  DatabaseColumnDefinition('sortIndex', DatabaseColumnType.INTEGER),
  DatabaseColumnDefinition('showTotal', DatabaseColumnType.INTEGER),
  DatabaseColumnDefinition('deleted', DatabaseColumnType.INTEGER),
];
```

Note: adding a column here defines the schema for a **fresh** database. Existing databases are
evolved with a migration — see [migrations.md](migrations.md).

## The map-method convention

`modelToMap` / `mapToModel` are written by hand and follow fixed encoding rules —
[accounts.repository.dart:24-50](../lib/repositories/accounts.repository.dart#L24-L50):

- Only set `id` in the map when it is non-null (let SQLite autoincrement on insert).
- Enums → `TEXT` via `.name`; read back with `Enum.values.byName(...)` (or `firstWhere`).
- Booleans → `1`/`0`; read back with `== 1`.

## Change events

Every write emits a `TableUpdateEvent` on the repository's `EventEmitter` —
[base.repository.dart:125-154](../lib/repositories/base.repository.dart#L125-L154):
`InsertEvent` and `UpdateEvent` carry the model; `DeleteEvent` carries the id. Views subscribe
to these to refresh reactively (see [architecture.md](architecture.md)). When you add a write
path, go through the base methods (or emit the event yourself) so the UI stays in sync.

## Advanced example: custom `find` with joins

`MovementsRepository` overrides `find` to join each movement to its source and target accounts
in one query —
[movements.repository.dart:72-128](../lib/repositories/movements.repository.dart#L72-L128). It
aliases movement columns as `movement_<col>` and account columns as `source_<col>` /
`target_<col>`, then reassembles nested `source` / `target` maps before delegating to
`mapToModel`. This is the reference pattern for a repository that needs related data eagerly
loaded.
