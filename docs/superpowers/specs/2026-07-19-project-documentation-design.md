# Project Documentation & CLAUDE.md — Design

**Date:** 2026-07-19
**Status:** Approved design, pending spec review

## Goal

Produce a `docs/` folder describing the existing functionality of the money-app, plus a
root `CLAUDE.md` that captures the most important architectural facts, coding patterns, and
conventions and references the specs. The purpose is to let Claude keep developing the app
the same way it has been built so far — same layered architecture, same file organization,
same naming, same formatting, same UI patterns — and to keep this documentation alive as the
project evolves.

This session also removes clearly-dead leftover files (documentation is the primary goal,
but the safe deletions are in scope).

## The meta-rule (most important)

**Everything in this project is written to a defined pattern.** When Claude needs to do
something and a pattern for it exists in these docs, it follows that pattern exactly. When
Claude **cannot find** a pattern for what it's about to do, it must **not** invent or assume
one — it stops, discusses the approach with the user, and once agreed the new pattern is
documented here before (or alongside) the code. This rule is stated prominently in
`CLAUDE.md` and `conventions.md`.

## The documentation-maintenance rule

**The docs are kept in sync with the code, as soon as possible.** Whenever a change touches
something that is documented, or introduces something that should be documented (a new
feature, a new pattern defined via the meta-rule, a new convention, resolved/!new tech debt),
the relevant doc is updated **in the same change**, not deferred. The policy itself, plus the
structure of the `docs/` folder and guidance on what does and does not warrant documentation,
lives in `docs/README.md`. `CLAUDE.md` instructs Claude to follow it on every change.

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
  stored in SQLite as TEXT via `.name`; booleans as `1/0`.
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

```text
docs/
  README.md              documentation guide: docs structure, maintenance policy,
                         what to document vs not, how to route (conventions/tech-debt/TODO)
  architecture.md        layers, DI (GetIt), startup sequence, event-driven refresh flow
  conventions.md         meta-rule, folder structure, file naming, file-size guideline,
                         language rule, DI rule, denormalized balance, no-tests, soft-delete
  coding-style.md        formatting, comments, method ordering, naming, async/state patterns
  ui-patterns.md         visual patterns: screen/dialog shells, buttons, colors, selectors
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
CLAUDE.md                (root) concise summary + meta-rule + docs-maintenance rule +
                         "how to add a feature" recipe + read-before-you-act guide + references
README.md                (root) project intro + TODO list (the 3 home.dart items)
```

### docs/README.md — the documentation guide

This is the doc that explains the docs. Contents:

- **Purpose:** what this folder is and who/what it's for (keeping development consistent).
- **Structure:** a one-line description of every doc file and the `features/` folder, so a
  reader knows where to look and where new content belongs.
- **Maintenance policy (the docs-maintenance rule):** update docs in the *same change* that
  alters or adds something documentation-worthy — never defer. If a change defines a new
  pattern (via the meta-rule), document it before/with the code.
- **What to document:**
  - Architecture and layer responsibilities.
  - Conventions, coding style, and UI patterns (anything a future change should imitate).
  - New patterns agreed via the meta-rule.
  - Feature behavior (what exists, from the user's perspective) + key code references.
  - Cross-cutting behavior (e.g. currency conversion).
  - Known tech debt (`tech-debt.md`) and backlog ideas (root `README.md` TODO).
- **What NOT to document:**
  - Things obvious from reading the code, or restating a single function line-by-line.
  - Transient implementation minutiae and one-off details.
  - Anything already captured by git history or the code itself.
  - Exhaustive method-by-method dumps (feature docs stay functional + references).
- **Routing guide:** intentional pattern → `conventions.md` / `coding-style.md` /
  `ui-patterns.md`; known issue → `tech-debt.md`; future work idea → root `README.md` TODO;
  new feature → new/updated file under `features/`.
- **Markdown style:** all docs are markdown-lint clean (this repo lints markdown) — fenced
  code blocks specify a language, and lists are surrounded by blank lines.

### CLAUDE.md (the anchor) — kept concise

- One-paragraph app description + stack (Flutter, sqflite, GetIt, local-first, es_AR).
- **The meta-rule**, stated up front: follow documented patterns; if none exists, stop and
  discuss — never assume.
- **The docs-maintenance rule:** keep docs in sync in the same change; points to
  `docs/README.md` for the policy and structure.
- The layered architecture in ~5 bullets, linking to `docs/architecture.md`.
- **Golden-path recipe — "How to add a new entity/feature":** create model → create
  repository (columns + map methods) → register in `DatabaseService` → write a migration →
  add it to `migrations_list.dart` → build views subscribing to repo events. Links to
  `data-layer.md` and `migrations.md`.
- Pointers to `conventions.md`, `coding-style.md`, `ui-patterns.md` with one-line summaries.
- Commands: `flutter run`, `flutter analyze`, `flutter test`. Explicitly note there is **no**
  build_runner/codegen step (models are hand-written) and that the global Java/mvn rules do
  not apply — this is a Dart/Flutter project.
- Reconcile the global-CLAUDE rules that touch this repo: (a) prefer IDE rename for renames;
  (b) "add DB enums for enumerated types" — note that here enums are stored as TEXT via
  `.name`, which is the established pattern for this SQLite app.
- **Read-before-you-act guide:** which doc(s) to read before a given kind of task, so Claude
  loads the right context before writing code:
  - Adding/altering a persisted entity → read `data-layer.md` + `migrations.md`.
  - Building or changing a screen/dialog → read `coding-style.md` + `ui-patterns.md`.
  - Touching a feature → read that feature's doc under `features/`.
  - Anything with no matching pattern → stop and invoke the meta-rule.
- Links to every feature doc.

### architecture.md

The layers; how `main.dart` boots (`runApp` → logger → services → database); the
`initialized` completer gate; and the event-driven reactive pattern (repos emit
`TableUpdateEvent`, views listen and refetch).

### conventions.md — intentional patterns to replicate

- **The meta-rule** (repeated from CLAUDE.md, in full).
- **Folder structure:** `lib/{models,repositories,services,migrations,views}` and
  `lib/views/{<feature>,generics}`; what belongs in each.
- **File naming:** suffix convention `*.model.dart`, `*.repository.dart`, `*.service.dart`,
  `*.migration.dart`, `*.dialog.dart`; screens are `<name>.dart`; snake_case filenames;
  one feature = one folder under `views/`.
- **File-size guideline:** keep files roughly **under ~500 lines**; when a file grows past
  that, that's a signal to split. Multiple **related** classes in one file are fine and
  expected (e.g. `movements_list.dart` holds `MovementsList` + `MovementListItem`;
  `navbar.dart` holds `Navbar` + `NavigationMenu`).
- **Language rule:** English code identifiers **and log messages**, Spanish UI strings. Code
  that violates this (e.g. Spanish logs) is tech debt, not a pattern to copy.
- **DI rule:** always cache `GetIt.instance.get<X>()` in a field on the class; do not call it
  inline in `build`/getters.
- **Denormalized balance rule:** `Account.total` is stored, not computed. It MUST be adjusted
  on every account-affecting change (see `movementsRepository.create()` / `remove()`). This
  is a deliberate performance choice.
- **No-tests policy:** the project does not write automated tests.
- Soft-delete pattern for accounts (`deleted` flag).
- Enums stored as TEXT via `.name`; booleans as `1/0`.

### coding-style.md — confirmed micro-patterns

Formatting:
- 2-space indentation, no tabs.
- Single quotes for all strings.
- **No leading blank line at the top of a file; no blank lines between imports.**
- Named-param brace spacing: `{ super.key, this.x }` when >1 param; `{super.key}` when it's
  the only param.
- `const SizedBox(height: N)` / `SizedBox(width: N)` for spacing inside Columns/Rows.
- **String interpolation always uses spaces inside braces — `${ expr }` — even for simple
  expressions.**

Comments:
- **Minimal comments; code should be self-documenting.** The only sanctioned comments are
  extension markers (e.g. `// Add new repositories here`). Avoid narrating code.

Method ordering inside a class:
- **attributes → getter/setter members → constructor → lifecycle
  (`initState`/`dispose`/`didUpdateWidget`) → logic methods → `build` → `buildX()` methods.**
- `buildX()` sub-widget methods appear in the order they are used within `build`.
- Untyped getters for computed values (`get canSubmit { … }`).

Naming:
- Data fetch = `getX()`; event subscription = `watchXChanges()`; listener field = `xListener`;
  dialog opener = `openXDialog()`; navigation = `goToX(context)`; sub-widget builder =
  `buildX(context)`.
- State classes are `_XState` (private) unless an external widget needs a
  `GlobalKey<…State>`, in which case the underscore is dropped (e.g. `MovementsListState`).

Async / state:
- `await databaseService.initialized;` before any DB access.
- Fetch methods use try/catch logging `logger.e('Error …', error: error, stackTrace: …)`.
- **`mounted` / `context.mounted` guard is required after every `await` that is followed by
  `setState` or use of `context`.**
- Event-driven refresh: subscribe in `watchXChanges`, refetch on event, `cancel()` in
  `dispose`.

### ui-patterns.md — confirmed visual patterns

- **Screen shell:** full screens wrapped in `Navbar(title: …, body: …)`; FAB is primaryColor,
  circular, white `Icons.add`.
- **Dialog shell:** `Dialog → Form (if inputs) → SingleChildScrollView(padding: symmetric
  25/25) → Column → [buildTitle, content…, buildActionButtons]`.
- **Title style:** `fontSize: 20, color: Theme.of(context).primaryColor, FontWeight.bold`,
  centered.
- **Action buttons row:** `spaceEvenly`; Cancel = `TextButton` (primaryColor text) + primary
  action = `ElevatedButton` (primaryColor bg / white text, `fixedSize: Size(120, 30)`),
  disabled → `disabledColor`, gated on a `canSubmit` getter.
- **Loading state:** `data == null ? const Loader() : buildContent(context)`; `Loader` is a
  centered "Cargando…" text.
- **Semantic colors:** inflow/income = `Colors.green.shade900`, outflow/expense =
  `Colors.red.shade900`, neutral transfer = `Colors.yellow.shade900`; primary accents via
  `Theme.of(context).primaryColor`.
- **Component choice:** segmented choice → `ButtonSelector`; dropdown/picker →
  `CupertinoSelect`; text-style tappable → `CupertinoButton(padding: zero)`.
- **Money formatting** always via `utilsService.beautifyCurrency`; **confirmations** always
  via `utilsService.confirm`.

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

Dead files (deleted this session):
- `dmmf.json` (leftover Prisma schema, unused).
- Empty `db.sqlite` and `package.json` / `package-lock.json` (node leftovers).
- Stale `test/widget_test.dart` (doesn't match the app).

Documented only (left untouched this session):
- Hardcoded `EURtoUSD = 1.11` in `utils.service.dart` — no EUR→USD API was found at the time;
  revisit later.
- Three Spanish log strings in `database.service.dart` (`'Creando tablas'`,
  `'Conectado a la base de datos'`, `'Error conectado a la base de datos'`) violate the
  EN-logs rule.
- Unused codegen dependencies (`json_serializable`, `json_annotation`, `build_runner`).
- Files that start with a leading blank line and/or have blank lines between imports (violate
  the formatting rule).
- Missing `mounted`/`context.mounted` guards after `await` before `setState` — e.g.
  `account_list.dart` `getAccounts`, `statistics.dart` `getAccounts`.
- Inline `GetIt.instance.get<…>()` not cached in a field — e.g. `movements_list.dart:138`,
  `dashboard.dart`.
- String interpolations without inner spaces where the rule now requires `${ expr }`.
- Empty `initState` that only calls `super.initState()` — e.g. `total_viewer.dart`.

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

Behavior/style-affecting items are documented in `tech-debt.md` only and left untouched.

## Success criteria

- `docs/` and `CLAUDE.md` exist with the structure above.
- A developer (or Claude) can read CLAUDE.md + the relevant docs and extend a feature
  following the established patterns without re-reading the whole codebase.
- Docs reflect reality, including the tech-debt split between intentional conventions and
  known debt.
- The meta-rule is unmistakable: no un-patterned code gets written without discussion.
- The docs-maintenance rule is unmistakable: docs are updated in the same change that makes
  them stale.
- The five dead files are removed; the build still runs (`flutter analyze` clean of new
  errors).
