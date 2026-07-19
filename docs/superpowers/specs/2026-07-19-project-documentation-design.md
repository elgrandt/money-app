# Project Documentation & CLAUDE.md — Design

**Date:** 2026-07-19
**Status:** Approved design, pending spec review

## Goal

Produce a `docs/` folder describing the existing functionality of the money-app, plus a
root `CLAUDE.md` that captures the most important architectural facts and conventions and
references the specs. The purpose is to let Claude keep developing the app the same way it
has been built so far — same layered architecture, same naming, same patterns.

This session also removes clearly-dead leftover files (documentation is the primary goal,
but the safe deletions are in scope).

## Non-goals

- No behavior changes to the app.
- No refactors of existing code.
- No new tests (the project intentionally does not write tests).
- No fixing of documented tech debt beyond deleting dead files (see Cleanup below).

## What the app is (for context)

A local-first Flutter personal-finance tracker. Spanish UI (`es_AR` locale), single user,
offline SQLite storage via `sqflite`. Tracks accounts (multi-currency ARS/USD/EUR),
movements (income / expense / transfer with FX conversion), categories, statistics, and
local backups.

## Architecture summary (the patterns to preserve)

Hand-rolled layered architecture:

- **Models** (`lib/models/*.model.dart`) — plain Dart classes extending `BaseModel`
  (`id` + equality-by-id). Enums carry display-name maps (e.g. `movementTypeNames`) and are
  stored in SQLite as TEXT via `.name`.
- **Repositories** (`lib/repositories/*.repository.dart`) — extend `BaseRepository<Model>`.
  Declare a typed column-definition DSL (`DatabaseColumnDefinition`, `PrimaryKeyDefinition`,
  `ForeignKeyDefinition`), implement `modelToMap`/`mapToModel` by hand, and **emit a
  `TableUpdateEvent`** (INSERT/UPDATE/DELETE) via an `EventEmitter` on every write. Domain
  methods (`create`, `remove`, `getExpensesByCategory`, …) live here.
- **Services** (`lib/services/*.service.dart`) — `DatabaseService` (singleton owning the
  `Database` and all repositories, runs migration `sync()` on startup, exposes an
  `initialized` completer) and `UtilsService` (currency conversion via the bluelytics API,
  formatting, confirm dialogs, string normalization).
- **Migrations** (`lib/migrations/*.migration.dart`) — a custom framework:
  `MigrationDefinition(name, up, down)` registered in the ordered `migrationDefinitions`
  list; `MigrationsRepository.sync()` runs the unrun ones at startup; migrations are
  idempotent (catch duplicate-column errors).
- **Views** (`lib/views/<feature>/`) — screens and `*.dialog.dart` dialogs. Use
  `GetIt.instance.get<X>()` for DI, `await databaseService.initialized` before DB access,
  and subscribe to repository `events` for reactive refresh. Reusable widgets live in
  `lib/views/generics/`.
- **DI** — `get_it` singletons registered in `main.dart`.

## Documentation structure

```
docs/
  README.md              index: what each doc is, where to start
  architecture.md        layers, DI (GetIt), startup sequence, event-driven refresh flow
  conventions.md         naming, file suffixes, language rule, patterns, "the way we build"
  data-layer.md          BaseModel, BaseRepository, column-definition DSL, map methods, events
  migrations.md          MigrationDefinition framework, sync, idempotency, example template
  tech-debt.md           honest list of things to fix
  features/
    accounts.md
    movements.md
    categories.md
    statistics.md
    backups.md
    currency.md          conversion via bluelytics + rate handling (cross-cutting)
CLAUDE.md                (root) concise summary + "how to add a feature" recipe + doc references
README.md                (root) project intro + TODO list (the 3 home.dart items)
```

### CLAUDE.md (the anchor) — kept concise

- One-paragraph app description + stack (Flutter, sqflite, GetIt, local-first, es_AR).
- The layered architecture in ~5 bullets, linking to `docs/architecture.md`.
- **Golden-path recipe — "How to add a new entity/feature":** create model → create
  repository (columns + map methods) → register in `DatabaseService` → write a migration →
  add it to `migrations_list.dart` → build views subscribing to repo events. Links to
  `data-layer.md` and `migrations.md`.
- Conventions summary (file suffixes, EN code+logs / ES UI, no tests) → links `conventions.md`.
- Commands: `flutter run`, `flutter analyze`, `flutter test`. Explicitly note there is **no**
  build_runner/codegen step (models are hand-written) and that the global Java/mvn rules do
  not apply — this is a Dart/Flutter project.
- Reconcile the two global-CLAUDE rules that touch this repo: (a) prefer IDE rename for
  renames; (b) "add DB enums for enumerated types" — note that here enums are stored as TEXT
  via `.name`, which is the established pattern for this SQLite app.
- Links to every feature doc.

### architecture.md

The layers; how `main.dart` boots (`runApp` → logger → services → database); the
`initialized` completer gate; and the event-driven reactive pattern (repos emit
`TableUpdateEvent`, views listen and refetch).

### conventions.md — intentional patterns to replicate

- File-naming suffixes: `.model.dart`, `.repository.dart`, `.service.dart`,
  `.migration.dart`, `.dialog.dart`; snake_case files.
- **Language rule:** English code identifiers **and log messages**, Spanish UI strings. Any
  code that violates this (e.g. Spanish logs) is tech debt, not a pattern to copy.
- Dialog pattern; `GetIt.instance.get<X>()` DI usage.
- **Denormalized balance rule:** `Account.total` is stored, not computed. It MUST be adjusted
  on every account-affecting change (see `movementsRepository.create()` / `remove()`). This
  is a deliberate performance choice.
- **No-tests policy:** the project does not write automated tests.
- Soft-delete pattern for accounts (`deleted` flag).
- Enums stored as TEXT via `.name`.

### data-layer.md

Deep on `BaseRepository` (find/insert/update/delete/count + events); the typed SQL DSL; the
manual `modelToMap`/`mapToModel` convention, using the movements JOIN-based `find` override
as the advanced example.

### migrations.md

The framework, the ordered list, `sync()` at startup, idempotency (catch duplicate-column),
and `example.migration.dart` as the intentional template to copy for new migrations.

### Feature docs

Depth = **functional + key code references**. Each doc covers:
1. What it does (user's perspective).
2. Data model.
3. Key repository methods (with `file.dart:line` references).
4. Views involved.
5. Edge cases (e.g. transfer FX conversion, soft-deleted accounts).

### tech-debt.md

- Remove `dmmf.json` (leftover Prisma schema, unused) — *deleted this session*.
- Remove empty `db.sqlite` and `package.json` / `package-lock.json` (node leftovers) —
  *deleted this session*.
- Remove stale `test/widget_test.dart` (doesn't match the app) — *deleted this session*.
- Hardcoded `EURtoUSD = 1.11` in `utils.service.dart` — no EUR→USD API was found at the
  time; revisit later. *Documented only.*
- Three Spanish log strings in `database.service.dart` (`'Creando tablas'`,
  `'Conectado a la base de datos'`, `'Error conectado a la base de datos'`) violate the
  EN-logs convention. *Documented only.*
- Unused codegen dependencies (`json_serializable`, `json_annotation`, `build_runner`) —
  declared in `pubspec.yaml` but nothing uses them. *Documented only.*

### Root README.md

Brief intro, plus a TODO list holding the three items currently in the `home.dart` comment:
- Edit accounts
- Transfer currency exchange rate
- Add account total functionality

## Cleanup performed this session (safe deletions)

- `dmmf.json`
- `db.sqlite`
- `package.json`
- `package-lock.json`
- `test/widget_test.dart`

Behavior-affecting items (EURtoUSD constant, Spanish logs, unused deps) are documented in
`tech-debt.md` only and left untouched.

## Success criteria

- `docs/` and `CLAUDE.md` exist with the structure above.
- A developer (or Claude) can read CLAUDE.md + the relevant feature doc and extend a feature
  following the established patterns without re-reading the whole codebase.
- Docs reflect reality, including the tech-debt split between intentional conventions and
  known debt.
- The five dead files are removed; the build still runs (`flutter analyze` clean of new
  errors).
