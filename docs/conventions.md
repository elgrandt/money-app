# Conventions

The rules that govern how this project is built. Follow them exactly. For formatting and
per-method style see [coding-style.md](coding-style.md); for visual patterns see
[ui-patterns.md](ui-patterns.md).

## The meta-rule

**Everything in this project is written to a defined pattern.** When a pattern for what you
are doing exists in these docs, follow it exactly. When you **cannot find** a pattern for what
you are about to do, do **not** invent or assume one — stop, discuss the approach, and once
it is agreed, document the new pattern here **before or alongside** the code that first uses
it. Un-patterned code should never be written silently.

## Folder structure

```text
lib/
  main.dart                 app entry point, DI registration, routes
  models/                   *.model.dart — data classes (extend BaseModel)
  repositories/             *.repository.dart — data access (extend BaseRepository)
  services/                 *.service.dart — DatabaseService, UtilsService (GetIt singletons)
  migrations/               *.migration.dart — schema migrations + the ordered list
  views/
    <feature>/              screens and dialogs for one feature
    generics/               reusable widgets used across features
```

- Models, repositories, services, and migrations are flat folders keyed by suffix.
- Each feature gets one folder under `views/` (e.g. `views/accounts`, `views/movements`).
- Cross-feature reusable widgets live in `views/generics/`.

## File naming

- Suffix by role: `*.model.dart`, `*.repository.dart`, `*.service.dart`, `*.migration.dart`,
  `*.dialog.dart`. Screens (non-dialog views) are plain `<name>.dart`.
- Filenames are `snake_case`; migration files describe the change
  (e.g. `add_deleted_field_to_account.migration.dart`).

## File-size guideline

~500 lines is a **soft signal, not a hard limit**. A cohesive file at 502 or 600 lines is
fine when it can't be split cleanly (e.g. a large view). Treat crossing ~500 as a prompt to
ask "can this be split sensibly?" — split when it can, leave it when a split would be
artificial. Multiple **related** classes in one file are fine and expected, e.g.
`movements_list.dart` holds `MovementsList` + `MovementListItem`, and `navbar.dart` holds
`Navbar` + `NavigationMenu`.

## Prefer generalization

When a widget or helper looks like it could be reusable, build it as a generic from the start
— even if there is no second use site yet. Generic widgets live in `lib/views/generics/`
(e.g. `ButtonSelector`, `CupertinoSelect`, `EasyPieChart`, `Tabs`, `Loader`, `Navbar`);
generic helpers live in a service (e.g. `UtilsService.filterList`, `normalizeString`,
`confirm`). Parameterize them via constructor callbacks/typedefs and generics
(`EasyPieChart<T>`, `filterList<T>`), and keep them free of feature-specific models or state.
If generalizing would force an awkward abstraction, keep it local — but the default leans
toward extracting a reusable component.

## Language

English code identifiers **and log messages**; Spanish (`es_AR`) for user-facing UI strings.
Code that violates this (e.g. Spanish log messages or comments) is tech debt, not a pattern to
copy — see [tech-debt.md](tech-debt.md).

## Dependency injection

Always cache `GetIt.instance.get<X>()` in a field on the consuming class:

```dart
var databaseService = GetIt.instance.get<DatabaseService>();
var utilsService = GetIt.instance.get<UtilsService>();
var logger = GetIt.instance.get<Logger>();
```

Do not call `GetIt.instance.get<X>()` inline inside `build`, getters, or hot paths.

## Denormalized balances

`Account.total` is **stored, not computed** from movements — a deliberate performance choice.
Any operation that affects an account's balance MUST adjust `total` explicitly. Movement
creation and removal do this via `AccountsRepository.updateBalance` — see
[movements.repository.dart:140-177](../lib/repositories/movements.repository.dart#L140-L177)
and [accounts.repository.dart:52-60](../lib/repositories/accounts.repository.dart#L52-L60).
If you add a new way to affect balances, it must keep `total` consistent.

## Soft delete

Accounts are soft-deleted: `AccountsRepository.delete` sets the `deleted` flag (and removes the
account's non-transfer movements) instead of deleting the row, and `find` filters out deleted
accounts — [accounts.repository.dart:72-101](../lib/repositories/accounts.repository.dart#L72-L101).

## Storage encoding

- Enums are stored as `TEXT` using `.name`, and read back with `Enum.values.byName(...)` (or
  `firstWhere`). Always create the value as text, never an ordinal index.
- Booleans are stored as `INTEGER` `1`/`0`.

## No tests

The project does not write automated tests. Do not add a test framework or tests unless
explicitly asked.

## Git workflow

Never commit directly to `master`. All work happens on a feature branch named
`feature/<short-description>` (kebab-case, e.g. `feature/edit-accounts`). Before committing
anything, confirm you are on the feature branch and not on `master`; if you are on `master`,
create or switch to the feature branch first.
