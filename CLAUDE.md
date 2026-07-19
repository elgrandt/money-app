# CLAUDE.md

Money is a local-first Flutter personal-finance tracker: Spanish (`es_AR`) UI, single user,
offline SQLite via `sqflite`, dependency injection via `get_it`. It tracks multi-currency
accounts, movements (income / expense / transfer with FX conversion), categories, statistics,
and local backups. This file is the anchor; the detailed docs live in [docs/](docs/README.md).

## Two rules that govern all work

- **Meta-rule — never assume a pattern.** Everything here is written to a defined pattern. If a
  pattern for what you're doing exists in the docs, follow it exactly. If none exists, **stop
  and discuss** — do not invent one silently; once agreed, document it before/with the code.
- **Docs-maintenance rule — keep docs in sync.** When a change touches or adds something
  documentation-worthy, update the relevant doc **in the same change**. See
  [docs/README.md](docs/README.md) for the policy, structure, and what does/doesn't get
  documented.

## Architecture (see [docs/architecture.md](docs/architecture.md))

- **Models** (`lib/models/*.model.dart`) — plain classes extending `BaseModel` (equality by id).
- **Repositories** (`lib/repositories/*.repository.dart`) — extend `BaseRepository<Model>`; own
  the SQL, hand-written `modelToMap`/`mapToModel`, and emit `TableUpdateEvent` on every write.
- **Services** (`lib/services/*.service.dart`) — `DatabaseService` (owns the DB + repositories,
  runs migrations, exposes an `initialized` future) and `UtilsService` (currency, formatting,
  dialogs); registered as `get_it` singletons in `main.dart`.
- **Migrations** (`lib/migrations/*.migration.dart`) — custom framework, run at startup.
- **Views** (`lib/views/<feature>/`, `views/generics/`) — subscribe to repo events to refresh.

## How to add a new entity/feature

1. Create the model in `lib/models/<name>.model.dart` extending `BaseModel`.
2. Create the repository in `lib/repositories/<name>.repository.dart` extending
   `BaseRepository<Model>`: declare the `static` column list (typed DSL) and implement
   `modelToMap`/`mapToModel`. See [docs/data-layer.md](docs/data-layer.md).
3. Register it in `DatabaseService` — add the `late` field, construct it in
   `initializeRepositories()`, and clear it in `deleteAllData()`
   ([database.service.dart](lib/services/database.service.dart)).
4. Write a migration for the new table/columns and append it to `migrationDefinitions`. See
   [docs/migrations.md](docs/migrations.md).
5. Build the views (subscribe to the repo's `events`, gate on `databaseService.initialized`).

## Conventions & style

- [docs/conventions.md](docs/conventions.md) — meta-rule, folder structure, file naming,
  file-size guideline, prefer-generalization, language (EN code+logs / ES UI), DI (cache in a
  field), denormalized balances, soft delete, enum/bool storage, git workflow.
- [docs/coding-style.md](docs/coding-style.md) — formatting (no leading blank line, spaced
  `${ }`), minimal comments, method ordering, build decomposition, naming, async/state
  (`initialized` gate, `mounted` guards).
- [docs/ui-patterns.md](docs/ui-patterns.md) — `Navbar` screen shell, dialog shell, title
  style, action buttons, semantic colors, `ButtonSelector` vs `CupertinoSelect`.

## Git workflow

Never commit to `master`. Work on a `feature/<short-description>` branch and confirm you are on
it before committing (details in [docs/conventions.md](docs/conventions.md)).

## Commands

- `flutter run` — run the app.
- `flutter analyze` — static analysis.
- `flutter test` — run tests (note: the project has **no** tests by policy).

There is **no** codegen/`build_runner` step — models are hand-written (the `json_serializable`
deps are unused; see [docs/tech-debt.md](docs/tech-debt.md)). This is a Dart/Flutter project, so
global Java/`mvn` rules do not apply.

## Notes reconciling global instructions

- **Renames:** prefer the IDE rename (updates all references and imports); afterward verify no
  reference was missed.
- **DB enums:** the global "create DB enums for enumerated types" rule is a Postgres convention;
  this app uses SQLite and stores enums as `TEXT` via `.name` — follow that established pattern
  here (see [docs/data-layer.md](docs/data-layer.md)).

## Read before you act

- Adding/altering a persisted entity → read [data-layer.md](docs/data-layer.md) +
  [migrations.md](docs/migrations.md).
- Building/changing a screen or dialog → read [coding-style.md](docs/coding-style.md) +
  [ui-patterns.md](docs/ui-patterns.md).
- Working on a feature → read that feature's doc under [features/](docs/features/).
- No matching pattern for the task → stop and discuss (meta-rule).

## Feature index

- [Accounts](docs/features/accounts.md)
- [Movements](docs/features/movements.md)
- [Categories](docs/features/categories.md)
- [Statistics](docs/features/statistics.md)
- [Backups](docs/features/backups.md)
- [Currency](docs/features/currency.md) (cross-cutting)
