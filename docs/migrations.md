# Migrations

Schema changes are applied through a small custom migration framework that runs at startup.
The column definitions in a repository (see [data-layer.md](data-layer.md)) describe a
**fresh** database; migrations evolve **existing** databases.

## MigrationDefinition

A migration is a named pair of up/down functions —
[migration_definition.dart](../lib/migrations/migration_definition.dart):

```dart
class MigrationDefinition {
  String name;
  Future<void> Function() up;
  Future<void> Function() down;

  MigrationDefinition(this.name, this.up, this.down);
}
```

Each migration lives in its own `*.migration.dart` file under `lib/migrations/` and is
exported as a top-level variable.

## The ordered registry

All migrations are listed, in run order, in `migrationDefinitions` —
[migrations_list.dart](../lib/migrations/migrations_list.dart). **Order matters**: append new
migrations to the end of this list.

## Startup sync

On startup `DatabaseService` calls `MigrationsRepository.sync()`, which reads the names of
migrations already recorded in the `migrations` table and runs every registered migration that
has not run yet, recording each as it succeeds —
[migrations.repository.dart:37-59](../lib/repositories/migrations.repository.dart#L37-L59). The
`migrations` table itself is created during `DatabaseService` initialization.

## Idempotency

Because a migration may run against a database that already has the change (e.g. a schema
created fresh from updated column definitions), `up` should tolerate that. The established
pattern catches the duplicate-column error and warns instead of failing —
[add_deleted_field_to_account.migration.dart](../lib/migrations/add_deleted_field_to_account.migration.dart):

```dart
try {
  await databaseService.db.execute('ALTER TABLE accounts ADD deleted INT default 0 NOT NULL');
} catch (error, stackTrace) {
  if (error is DatabaseException && error.isDuplicateColumnError()) {
    logger.w('Order column already exists');
  } else {
    rethrow;
  }
}
```

## The template

`example.migration.dart` is kept intentionally as the template to copy when writing a new
migration — [example.migration.dart](../lib/migrations/example.migration.dart). It stays first
in the registry.

## Recipe: adding a migration

1. Create `lib/migrations/<describes_the_change>.migration.dart`, following
   `example.migration.dart` and the idempotency pattern above.
2. Define the `up` (apply the change) and `down` (revert, where feasible) functions.
3. Append the new definition to `migrationDefinitions` in `migrations_list.dart`.
4. If the change adds a column that should also exist in a fresh database, add it to the
   repository's `static` column list too (see [data-layer.md](data-layer.md)).
