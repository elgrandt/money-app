# Architecture

The app is a hand-rolled, layered Flutter application over a local SQLite database. There is
no backend and no external state beyond a live currency-rate API. State changes flow through
the repositories, which broadcast events that the views listen to and refresh from.

## Layers

```text
        ┌─────────────────────────────────────────────┐
        │  Views (lib/views/<feature>, views/generics)  │  StatefulWidgets, dialogs
        │   - GetIt for DI                              │
        │   - await databaseService.initialized         │
        │   - subscribe to repo events → refetch        │
        └───────────────┬───────────────────────────────┘
                        │ calls domain methods            ▲ TableUpdateEvent
                        ▼                                  │ (change)
        ┌─────────────────────────────────────────────┐
        │  Repositories (lib/repositories/*.repository) │  BaseRepository<Model>
        │   - typed column DSL, modelToMap/mapToModel   │
        │   - emit InsertEvent/UpdateEvent/DeleteEvent  │
        └───────────────┬───────────────────────────────┘
                        │ sqflite
                        ▼
        ┌─────────────────────────────────────────────┐
        │  DatabaseService (lib/services)               │  owns Database + all repositories
        │   - runs migrations on startup                │
        └─────────────────────────────────────────────┘
```

- **Models** (`lib/models/*.model.dart`) — plain Dart classes extending `BaseModel`. No
  serialization framework; equality is by `id`. See [data-layer.md](data-layer.md).
- **Repositories** (`lib/repositories/*.repository.dart`) — data access for one table each,
  extending `BaseRepository<Model>`. They own the SQL, the map conversions, and the domain
  methods, and they emit change events. See [data-layer.md](data-layer.md).
- **Services** (`lib/services/*.service.dart`) — `DatabaseService` (owns the DB and the
  repositories, runs migrations) and `UtilsService` (currency conversion, formatting, shared
  dialogs). Registered as `get_it` singletons.
- **Migrations** (`lib/migrations/*.migration.dart`) — schema evolution, run at startup. See
  [migrations.md](migrations.md).
- **Views** (`lib/views/`) — screens and `*.dialog.dart` dialogs per feature, plus reusable
  widgets in `lib/views/generics/`. See [coding-style.md](coding-style.md) and
  [ui-patterns.md](ui-patterns.md).

## Startup sequence

`main()` starts the UI immediately, then wires up services — see
[main.dart:13-35](../lib/main.dart#L13-L35):

1. `runApp(const MoneyApp())` — the widget tree renders (screens show a `Loader` until the DB
   is ready).
2. `initializeLogger()` — registers a `Logger` singleton in `GetIt`.
3. `initializeServices()` — registers `UtilsService` and `DatabaseService` singletons.
4. `initializeDatabase()` — calls `DatabaseService.initialize()`, which opens the SQLite
   database, initializes the repositories, and runs migration `sync()`.

Routes are declared in `MoneyApp` (`/`, `/accounts`, `/categories`, `/statistics`,
`/backups`) — [main.dart:55-61](../lib/main.dart#L55-L61).

## The `initialized` gate

Because `runApp` runs before the database is open, any DB access must wait. `DatabaseService`
exposes an `initialized` future backed by a `Completer`, completed once the repositories are
ready and migrations have synced — [database.service.dart:27-67](../lib/services/database.service.dart#L27-L67).
Views and dialogs `await databaseService.initialized;` before their first query. `DatabaseService`
holds `late` references to every repository (`movementsRepository`, `accountsRepository`,
`categoriesRepository`, `migrationsRepository`); new repositories are registered in
`initializeRepositories()` and wiped in `deleteAllData()`.

## Dependency injection

`get_it` provides service-locator DI. Singletons are registered once in `main.dart` and
retrieved with `GetIt.instance.get<X>()`. The convention is to cache the lookup in a field on
the consuming class rather than calling it inline — see the DI rule in
[conventions.md](conventions.md).

## Event-driven refresh

Repositories extend `BaseRepository`, which owns an `EventEmitter` and emits a
`TableUpdateEvent` (`InsertEvent` / `UpdateEvent` / `DeleteEvent`) on every `insert`,
`update`, `delete`, and `deleteMany` — [base.repository.dart:125-221](../lib/repositories/base.repository.dart#L125-L221).

Views subscribe to a repository's `events` in a `watchXChanges()` method, refetch their data
when a change arrives, and cancel the listener in `dispose()`. Example:
[movements_list.dart:64-70](../lib/views/home/movements_list.dart#L64-L70). This is how, for
instance, creating a movement updates account balances and the balances refresh across every
open tab without any manual wiring between widgets.
