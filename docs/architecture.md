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

## AI service (creating a movement by voice)

Creating a movement by voice goes through one interface, `AIService`
([ai.service.dart](../lib/services/ai.service.dart)): `isAvailable()` (the UI hides the button when it is
false), `listen(MovementPromptContext, onPartialTranscript:, onListeningFinished:)` (returns the
interpreted `Movement`), `stop()` and `cancel()`. Failures arrive as `AIException` with an `AIFailure`.
The service holds the state of the one listening in progress: starting a `listen` cancels any previous
one, so there is never more than one at a time.

There are two implementations, registered in `GetIt` at startup (`initializeServices()`). To use
another engine (another API, a model that takes audio directly) add a class implementing `AIService`
and register it instead; the UI does not change.

**Active: `GeminiAIService`** ([gemini_ai.service.dart](../lib/services/gemini_ai.service.dart)). It listens
with `speech_to_text` (on-device) and sends the transcript to the Gemini API (`googleai_dart`) with a
full context prompt (date, accounts, categories, the description history per category). It trusts the
structured JSON it returns; Dart only checks that names exist and applies the default account. It needs
the key at build time:

```text
flutter run --dart-define-from-file=.env
```

`.env` holds `GEMINI_API_KEY=...` (it is git-ignored). `GEMINI_MODEL` overrides the model
(default `gemini-3.8-flash`). The key is compiled into the binary and sent in a request
header; do not distribute such a build. Without the key `isAvailable()` is false.

**Legacy: `InDeviceAIService`** ([in_device_ai.service.dart](../lib/services/in_device_ai.service.dart)).
It listens with `speech_to_text` and interprets the transcript with Apple Foundation Models, with no
network, no cost and no data leaving the phone. It is kept as legacy code in case we want to switch back;
build with `--dart-define=USE_IN_DEVICE_AI=true` to register it instead of Gemini. Because the small
on-device model makes more mistakes, it carries the Dart-side verification (evidence text checked against
the transcript, history-based category resolution, description filtering) that Gemini does not need.

Comparison on the same 28 test sentences with the real accounts, categories and history:

| Service | Correct | Median latency | Cost per command |
| --- | --- | --- | --- |
| `InDeviceAIService` | 20/28 | 1.8 s | 0 |
| `GeminiAIService` with `gemini-3.8-flash` | 27/28 | 6.7 s | ≈ USD 0.005 |
| `GeminiAIService` with `gemini-4-hydrogen` | 27/28 | 4.4 s | ≈ USD 0.010 |

The one sentence all of them miss is an exchange with no account named: the conversion rate is dropped
when the transfer accounts are unresolved.

How a sentence becomes a `Movement` is described in
[movements.md](features/movements.md#voice-assistant-creating-a-movement-by-speaking).

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
