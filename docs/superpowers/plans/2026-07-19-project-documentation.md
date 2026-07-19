# Project Documentation & CLAUDE.md Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a `docs/` folder documenting the money-app's functionality, architecture, and coding patterns, plus a root `CLAUDE.md`, so Claude can keep developing in the same style; and remove clearly-dead leftover files.

**Architecture:** Documentation-only work (plus five file deletions). A hybrid docs layout: cross-cutting docs (architecture, conventions, coding-style, ui-patterns, data-layer, migrations, tech-debt) + one functional doc per feature under `features/`. `CLAUDE.md` is the concise anchor that references everything and encodes two governing rules (the meta-rule and the docs-maintenance rule).

**Tech Stack:** Markdown (GitHub-flavored, markdown-lint clean). No code changes except deleting dead files and removing one comment block. Flutter/Dart project (sqflite, get_it, fl_chart).

**Source of truth:** the approved design spec at `docs/superpowers/specs/2026-07-19-project-documentation-design.md`. Each doc's required contents are described there; this plan says which file, which sections, and which code to cite.

## Global Constraints

- **Markdown-lint clean:** every doc — fenced code blocks specify a language (```dart, ```text, ```bash); lists are surrounded by blank lines; one H1 per file.
- **Clickable references:** link code as relative markdown links, e.g. `[movements.repository.dart:140](../../lib/repositories/movements.repository.dart#L140)` (adjust `../` depth per file location). Inter-doc links are relative (e.g. `[data-layer.md](data-layer.md)`).
- **Language of the docs:** written in English (matches the code-language rule). Quote Spanish UI strings verbatim where relevant.
- **Feature-doc depth:** functional + key code references — what it does, data model, key repository methods (with file:line), views involved, edge cases. NOT exhaustive method-by-method dumps.
- **Honesty:** document reality; route intentional patterns to conventions/coding-style/ui-patterns and known issues to `tech-debt.md`.
- **No behavior changes:** the only code touched is deleting dead files and removing the TODO comment block in `home.dart`.
- **Commits:** one commit per task; end every commit message with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 1: Remove dead leftover files

**Files:**
- Delete: `dmmf.json`
- Delete: `db.sqlite`
- Delete: `package.json`
- Delete: `package-lock.json`
- Delete: `test/widget_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: a clean tree; later `tech-debt.md` records these as done.

- [ ] **Step 1: Confirm nothing in `lib/` references the files**

Run: `grep -rn "dmmf\|package.json\|widget_test" lib || echo "no refs"`
Expected: `no refs` (the app opens its own `db.sqlite` in the app documents dir at runtime via `openDatabase('db.sqlite')` in [database.service.dart](../../lib/services/database.service.dart#L38); the repo-root file is a 0-byte leftover).

- [ ] **Step 2: Delete the five files**

```bash
git rm dmmf.json db.sqlite package.json package-lock.json test/widget_test.dart
```

- [ ] **Step 3: Verify the build still analyzes clean**

Run: `flutter analyze`
Expected: no new errors introduced by the deletions (pre-existing warnings, if any, are unchanged).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove dead leftover files (dmmf.json, db.sqlite, node files, stale test)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Root README.md + move home.dart TODOs

**Files:**
- Modify: `README.md` (currently just "# Money\n\nManage your money.")
- Modify: `lib/views/home/home.dart:21-26` (remove the `/* TODO ... */` comment block)

**Interfaces:**
- Consumes: nothing.
- Produces: the project's TODO backlog now lives in the README.

- [ ] **Step 1: Write the root README**

Content: keep the title/tagline; add a short "What is this" paragraph (local-first Flutter personal-finance tracker, Spanish `es_AR`, offline SQLite); add a "Documentation" section linking to `docs/README.md` and `CLAUDE.md`; add a "TODO / Backlog" section with the three items from the `home.dart` comment:

```markdown
# Money

Manage your money — a local-first Flutter personal-finance tracker (Spanish `es_AR`,
offline SQLite via `sqflite`).

## Documentation

- [docs/README.md](docs/README.md) — documentation guide and index.
- [CLAUDE.md](CLAUDE.md) — architecture, conventions, and coding patterns for contributors.

## TODO / Backlog

- Edit accounts
- Transfer currency exchange rate
- Add account total functionality
```

- [ ] **Step 2: Remove the TODO comment block from home.dart**

Delete lines 21-26 of [home.dart](../../lib/views/home/home.dart#L21-L26) (the `/* TODO ... */` block) and the blank line separating it from the class. Leave the imports and `class Home` intact.

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: no new errors. Confirm README renders (lint-clean: lists surrounded by blank lines).

- [ ] **Step 4: Commit**

```bash
git add README.md lib/views/home/home.dart
git commit -m "docs: add project README with backlog; move home.dart TODOs to README

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: docs/README.md — the documentation guide

**Files:**
- Create: `docs/README.md`

**Interfaces:**
- Produces: the maintenance policy + routing rules every other doc relies on.

- [ ] **Step 1: Write the file** with these H2 sections (content per spec "docs/README.md" section):
  1. **Purpose** — what this folder is for (keeping development consistent).
  2. **Structure** — a bulleted one-line description of every doc file and `features/`.
  3. **Maintenance policy** — the docs-maintenance rule: update docs in the *same change* that alters/adds something documentation-worthy; new patterns (from the meta-rule) get documented before/with the code.
  4. **What to document** — architecture, conventions/style/UI patterns, meta-rule patterns, feature behavior + refs, cross-cutting behavior, tech debt, backlog.
  5. **What NOT to document** — things obvious from code, line-by-line restatements, transient minutiae, anything git history already captures, exhaustive method dumps.
  6. **Routing guide** — intentional pattern → `conventions.md`/`coding-style.md`/`ui-patterns.md`; known issue → `tech-debt.md`; future idea → root `README.md` TODO; new feature → `features/`.
  7. **Markdown style** — docs are markdown-lint clean (code-fence languages; blank lines around lists).

- [ ] **Step 2: Verify** all inter-doc links resolve to files that exist or are planned in this plan; lint-clean.

- [ ] **Step 3: Commit**

```bash
git add docs/README.md
git commit -m "docs: add documentation guide (structure, maintenance policy, routing)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: docs/architecture.md

**Files:**
- Create: `docs/architecture.md`

- [ ] **Step 1: Write the file** covering:
  - The layered stack (models / repositories / services / migrations / views) — responsibility of each, one short paragraph each.
  - **Startup sequence:** `main()` → `runApp` → `initializeLogger` → `initializeServices` (registers `UtilsService`, `DatabaseService` as GetIt singletons) → `initializeDatabase`. Cite [main.dart:13-35](../../lib/main.dart#L13-L35).
  - **The `initialized` gate:** `DatabaseService` exposes a `Completer`-backed `initialized` future; views `await databaseService.initialized` before DB access. Cite [database.service.dart:27-67](../../lib/services/database.service.dart#L27-L67).
  - **Event-driven reactive refresh:** repositories emit `TableUpdateEvent` (INSERT/UPDATE/DELETE) via `EventEmitter`; views subscribe in `watchXChanges` and refetch. Cite [base.repository.dart:125-221](../../lib/repositories/base.repository.dart#L125-L221) and an example listener [movements_list.dart:64-70](../../lib/views/home/movements_list.dart#L64-L70).
  - **DI:** `get_it` singletons; `DatabaseService` owns the `Database` + all repositories.
  - Include one small ASCII/text diagram of the layer + event flow (fenced ```text).

- [ ] **Step 2: Verify** links resolve; lint-clean.

- [ ] **Step 3: Commit**

```bash
git add docs/architecture.md
git commit -m "docs: add architecture overview (layers, startup, event-driven refresh)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: docs/conventions.md

**Files:**
- Create: `docs/conventions.md`

- [ ] **Step 1: Write the file** with these sections (content per spec "conventions.md"):
  - **The meta-rule** (in full): follow documented patterns; if none exists, stop and discuss — never assume; new patterns get documented.
  - **Folder structure:** `lib/{models,repositories,services,migrations,views}`, `lib/views/{<feature>,generics}` — what belongs where.
  - **File naming:** suffixes `*.model.dart`, `*.repository.dart`, `*.service.dart`, `*.migration.dart`, `*.dialog.dart`; screens `<name>.dart`; snake_case; one feature = one folder.
  - **File-size guideline:** ~500 lines is a **soft signal, not a hard limit** — a cohesive 502/600-line file (e.g. a big view) is fine; crossing ~500 is a prompt to ask "can this split cleanly?". Multiple related classes per file OK (`movements_list.dart` = `MovementsList` + `MovementListItem`; `navbar.dart` = `Navbar` + `NavigationMenu`).
  - **Prefer generalization:** build reusable generics as soon as something looks reusable, even without a second use site; generic widgets → `lib/views/generics/`, generic helpers → a service (`UtilsService`); parameterize via callbacks/typedefs/generics (`EasyPieChart<T>`, `filterList<T>`); no feature-specific coupling.
  - **Language rule:** English code + logs, Spanish UI strings.
  - **DI rule:** always cache `GetIt.instance.get<X>()` in a field; never inline in build/getters.
  - **Denormalized balance rule:** `Account.total` is stored, not computed; adjust it on every account-affecting change. Cite [movements.repository.dart:140-177](../../lib/repositories/movements.repository.dart#L140-L177) and [accounts.repository.dart:52-60](../../lib/repositories/accounts.repository.dart#L52-L60).
  - **No-tests policy.**
  - **Soft-delete** for accounts (`deleted` flag); cite [accounts.repository.dart:72-101](../../lib/repositories/accounts.repository.dart#L72-L101).
  - **Enums stored as TEXT via `.name`; booleans as `1/0`.**

- [ ] **Step 2: Verify** links resolve; lint-clean.

- [ ] **Step 3: Commit**

```bash
git add docs/conventions.md
git commit -m "docs: add conventions (meta-rule, structure, naming, generalization, DI, storage)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: docs/coding-style.md

**Files:**
- Create: `docs/coding-style.md`

- [ ] **Step 1: Write the file** with these sections (content per spec "coding-style.md"):
  - **Formatting:** 2-space indent, single quotes, no leading blank line, no blank lines between imports, brace spacing (`{ super.key, this.x }` when >1 param, `{super.key}` when only param), `SizedBox` for spacing, always-spaced `${ expr }`.
  - **Comments:** minimal, self-documenting; only sanctioned comments are extension markers like `// Add new repositories here`.
  - **Method ordering:** attributes → getter/setter members → constructor → lifecycle → logic methods → `build` → `buildX()`; `buildX` in order of use; untyped computed getters.
  - **Build decomposition:** `build` reads as a high-level composition; extract `buildX(context)` for **large or semantically meaningful** sections (cite dialog `buildTitle`/`buildContent`/`buildActionButtons` in [new_movement.dialog.dart](../../lib/views/movements/new_movement.dialog.dart) and dashboard chart sections in [dashboard.dart](../../lib/views/home/dashboard.dart)); do **not** over-extract trivial widgets (spacers, one-line text) — use judgment; `buildX` returns `Widget` or `List<Widget>` (spread with `...`).
  - **Naming:** `getX()` fetch, `watchXChanges()` subscribe, `xListener` field, `openXDialog()`, `goToX(context)`, `buildX(context)`; `_XState` private unless external `GlobalKey<…State>` needed (e.g. `MovementsListState`).
  - **Async / state:** `await databaseService.initialized;` before DB access; try/catch logging `logger.e('Error …', error: error, stackTrace: …)`; **`mounted`/`context.mounted` guard required after every `await` before `setState`/`context`**; event-driven refresh (subscribe in `watchXChanges`, `cancel()` in `dispose`).

- [ ] **Step 2: Verify** links resolve; lint-clean.

- [ ] **Step 3: Commit**

```bash
git add docs/coding-style.md
git commit -m "docs: add coding style (formatting, comments, method order, build decomposition)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: docs/ui-patterns.md

**Files:**
- Create: `docs/ui-patterns.md`

- [ ] **Step 1: Write the file** covering (content per spec "ui-patterns.md"), each with a code reference:
  - **Screen shell:** `Navbar(title:, body:)`; FAB primaryColor/circular/white `Icons.add`. Cite [navbar.dart](../../lib/views/generics/navbar.dart) + [account_list.dart:82-94](../../lib/views/accounts/account_list.dart#L82-L94).
  - **Dialog shell:** `Dialog → Form (if inputs) → SingleChildScrollView(padding 25/25) → Column → [buildTitle, content…, buildActionButtons]`. Cite [new_account.dialog.dart](../../lib/views/accounts/new_account.dialog.dart).
  - **Title style** (fontSize 20, primaryColor, bold, centered).
  - **Action buttons row** (spaceEvenly; Cancel `TextButton` + primary `ElevatedButton`, `fixedSize: Size(120,30)`, disabled→`disabledColor`, gated on `canSubmit`).
  - **Loading state** (`data == null ? const Loader() : buildContent`); `Loader` = centered "Cargando…". Cite [loader.dart](../../lib/views/generics/loader.dart).
  - **Semantic colors** (income green.shade900, expense red.shade900, transfer yellow.shade900). Cite [movements_list.dart:144-164](../../lib/views/home/movements_list.dart#L144-L164).
  - **Component choice:** segmented → `ButtonSelector`; picker → `CupertinoSelect`; text-tappable → `CupertinoButton(padding: zero)`.
  - **Money formatting** via `utilsService.beautifyCurrency`; **confirmations** via `utilsService.confirm`. Cite [utils.service.dart:89-128](../../lib/services/utils.service.dart#L89-L128).

- [ ] **Step 2: Verify** links resolve; lint-clean.

- [ ] **Step 3: Commit**

```bash
git add docs/ui-patterns.md
git commit -m "docs: add UI patterns (screen/dialog shells, buttons, colors, selectors)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: docs/data-layer.md

**Files:**
- Create: `docs/data-layer.md`

- [ ] **Step 1: Write the file** covering:
  - **`BaseModel`** — `id` + equality-by-id. Cite [base.model.dart](../../lib/models/base.model.dart).
  - **`BaseRepository<Model>`** — `initializeTable`, `insert`, `findById`, `find`, `delete`, `deleteMany`, `update`, `count`, `deleteAll`, and the abstract `modelToMap`/`mapToModel`. Cite [base.repository.dart:156-235](../../lib/repositories/base.repository.dart#L156-L235).
  - **The typed column DSL** — `DatabaseColumnDefinition`, `PrimaryKeyDefinition`, `ForeignKeyDefinition`, `DatabaseColumnType`. Show a real column list example from [accounts.repository.dart:10-18](../../lib/repositories/accounts.repository.dart#L10-L18).
  - **Events** — every write emits `InsertEvent`/`UpdateEvent`/`DeleteEvent`. Cite [base.repository.dart:125-154](../../lib/repositories/base.repository.dart#L125-L154).
  - **Map methods convention** — hand-written; enums via `.name`, bools via `1/0`. Cite [accounts.repository.dart:24-50](../../lib/repositories/accounts.repository.dart#L24-L50).
  - **Advanced example: custom `find` with JOINs** — how `MovementsRepository.find` builds `source_`/`target_` prefixed columns and reassembles nested account maps. Cite [movements.repository.dart:72-128](../../lib/repositories/movements.repository.dart#L72-L128).

- [ ] **Step 2: Verify** links resolve; lint-clean.

- [ ] **Step 3: Commit**

```bash
git add docs/data-layer.md
git commit -m "docs: add data-layer reference (BaseRepository, column DSL, events, map methods)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: docs/migrations.md

**Files:**
- Create: `docs/migrations.md`

- [ ] **Step 1: Write the file** covering:
  - **`MigrationDefinition(name, up, down)`**. Cite [migration_definition.dart](../../lib/migrations/migration_definition.dart).
  - **Ordered registry** — `migrationDefinitions` in [migrations_list.dart](../../lib/migrations/migrations_list.dart); order matters; append new ones at the end.
  - **`sync()` at startup** — runs unrun migrations, records each in the `migrations` table. Cite [migrations.repository.dart:37-59](../../lib/repositories/migrations.repository.dart#L37-L59).
  - **Idempotency** — `up` catches duplicate-column errors. Cite [add_deleted_field_to_account.migration.dart](../../lib/migrations/add_deleted_field_to_account.migration.dart).
  - **`example.migration.dart` is the intentional template** to copy for a new migration.
  - **Recipe: adding a migration** — write `<name>.migration.dart`, define up/down, append to `migrationDefinitions`.

- [ ] **Step 2: Verify** links resolve; lint-clean.

- [ ] **Step 3: Commit**

```bash
git add docs/migrations.md
git commit -m "docs: add migrations guide (framework, sync, idempotency, template, recipe)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: docs/tech-debt.md

**Files:**
- Create: `docs/tech-debt.md`

**Interfaces:**
- Consumes: the audit in the spec's "tech-debt.md" section (authoritative enumeration).

- [ ] **Step 1: Write the file** transcribing the full enumeration from the spec, grouped by category, each item with `file:line`. Include the intro line ("enumerates every existing place that does not match the defined patterns; keep current per the docs-maintenance rule"), and the sections: Dead files (mark deleted this session), Behavior/config debt, Language-rule violations, Formatting-rule violations, Comment-policy violations, Coding-style/state violations, and the "Not a violation: file size" note. For the **leading blank line** item, list all 39 files explicitly (everything under `lib/` except `main.dart`, `home.dart`, `movements_list.dart`, `all_expenses.dart`, `backups.dart`).

- [ ] **Step 2: Verify** counts match the spec; every `file:line` reference points to a real location (spot-check 5); lint-clean.

- [ ] **Step 3: Commit**

```bash
git add docs/tech-debt.md
git commit -m "docs: add tech-debt inventory (full enumeration of pattern violations)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: Feature docs — accounts, movements, currency

**Files:**
- Create: `docs/features/accounts.md`
- Create: `docs/features/movements.md`
- Create: `docs/features/currency.md`

Each doc uses the feature-doc template: **What it does → Data model → Key repository methods (file:line) → Views involved → Edge cases.**

- [ ] **Step 1: Write `accounts.md`**
  - What: multi-currency accounts (ARS/USD/EUR), reorderable, soft-deletable, per-account total visibility.
  - Data model: `Account` (name, total, currency, sortIndex, showTotal, deleted) — [account.model.dart](../../lib/models/account.model.dart).
  - Repo methods: `updateBalance`, `switchShowTotal`, soft-delete `delete` + `removeAllAccountMovements`, `find` filtering `deleted` — [accounts.repository.dart](../../lib/repositories/accounts.repository.dart).
  - Views: [account_list.dart](../../lib/views/accounts/account_list.dart) (reorder, delete), [new_account.dialog.dart](../../lib/views/accounts/new_account.dialog.dart), [total_viewer.dart](../../lib/views/home/total_viewer.dart).
  - Edge cases: can't delete the last account (delete icon hidden when `length <= 1`); soft delete removes ADD/REMOVE movements but keeps transfers; balance denormalized.

- [ ] **Step 2: Write `movements.md`**
  - What: income (ADD), expense (REMOVE), transfer (TRANSFER) with optional FX conversion; create/edit/delete; balances updated on write.
  - Data model: `Movement` (type, description, amount, conversionRate, category, source, target, creationDate) + `MovementType` enum + `movementTypeNames` — [movement.model.dart](../../lib/models/movement.model.dart).
  - Repo methods: `create` (sets source/target by type, applies conversionRate, updates balances), `remove` (reverses balances then deletes), `getLastMovements`, `getExpensesByCategory`, `getExpensesByDay`, JOIN `find` — [movements.repository.dart](../../lib/repositories/movements.repository.dart).
  - Views: [new_movement.dialog.dart](../../lib/views/movements/new_movement.dialog.dart), [movement_details.dialog.dart](../../lib/views/movements/movement_details.dialog.dart), [movements_list.dart](../../lib/views/home/movements_list.dart).
  - Edge cases: transfer between different currencies stores `conversionRate` and credits `amount * rate`; edit = remove-then-create; source/target nullability by type.

- [ ] **Step 3: Write `currency.md`** (cross-cutting)
  - What: multi-currency support + conversion; live ARS rates from the bluelytics API; totals shown in a chosen currency.
  - Mechanics: `UtilsService.currencyMappings`, `updateCurrencyMappings` (hourly, bluelytics blue/blue_euro), `convertCurrencies`, `beautifyCurrency`, `getCurrencyIcon`/`getCurrencySymbol`, `currencyConfigs` — [utils.service.dart](../../lib/services/utils.service.dart).
  - Views: [currency_selector.dart](../../lib/views/generics/currency_selector.dart).
  - Edge cases / debt link: hardcoded `EURtoUSD = 1.11` (see [tech-debt.md](../tech-debt.md)).

- [ ] **Step 4: Verify** all three link-resolve; lint-clean.

- [ ] **Step 5: Commit**

```bash
git add docs/features/accounts.md docs/features/movements.md docs/features/currency.md
git commit -m "docs: add feature docs for accounts, movements, currency

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: Feature docs — categories, statistics, backups

**Files:**
- Create: `docs/features/categories.md`
- Create: `docs/features/statistics.md`
- Create: `docs/features/backups.md`

- [ ] **Step 1: Write `categories.md`**
  - What: per-movement-type categories used when creating movements; managed in a tabbed list; created inline from the movement dialog.
  - Data model: `Category` (name, movementType) — [category.model.dart](../../lib/models/category.model.dart).
  - Repo methods: `create`, `getCategoriesByType` — [categories.repository.dart](../../lib/repositories/categories.repository.dart).
  - Views: [category_list.dart](../../lib/views/categories/category_list.dart), [new_category.dialog.dart](../../lib/views/categories/new_category.dialog.dart).
  - Edge cases: categories are grouped by `MovementType`; the movement dialog refreshes categories via the events listener when a new one is added.

- [ ] **Step 2: Write `statistics.md`**
  - What: expenses-by-category (pie + table with currency/percent toggle) and expenses-by-day (bar chart, optional accumulated), filterable by account, movement type, and period; also surfaced on the dashboard.
  - Repo methods: `getExpensesByCategory`, `getExpensesByDay` — [movements.repository.dart:179-239](../../lib/repositories/movements.repository.dart#L179-L239).
  - Views: [statistics.dart](../../lib/views/statistics/statistics.dart), [expenses_by_category.dart](../../lib/views/statistics/expenses_by_category.dart), [expenses_by_day.dart](../../lib/views/statistics/expenses_by_day.dart), [all_expenses.dart](../../lib/views/statistics/all_expenses.dart), [dashboard.dart](../../lib/views/home/dashboard.dart), generic [easy_pie_chart.dart](../../lib/views/generics/easy_pie_chart.dart).
  - Edge cases: amounts normalized across currencies before aggregation; period options (`this-month`/`month`/`year`/all); accumulated mode recomputes bar groups.

- [ ] **Step 3: Write `backups.md`**
  - What: export the SQLite DB to a `.moneybak` file, restore from one, and wipe all data.
  - Mechanics: `saveBackup` (copies app-docs `db.sqlite` via `FilePicker.saveFile`), `restoreBackup` (overwrites the DB then emits a fake account `change` event to refresh), `openDeleteDataConfirmationDialog` → `DatabaseService.deleteAllData` — [backups.dart](../../lib/views/backups/backups.dart), [database.service.dart:69-74](../../lib/services/database.service.dart#L69-L74).
  - Edge cases: restore emits a synthetic `TableUpdateEvent` to trigger UI refresh; delete-all requires confirmation and navigates back to `/`.

- [ ] **Step 4: Verify** all three link-resolve; lint-clean.

- [ ] **Step 5: Commit**

```bash
git add docs/features/categories.md docs/features/statistics.md docs/features/backups.md
git commit -m "docs: add feature docs for categories, statistics, backups

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 13: Root CLAUDE.md (the anchor)

**Files:**
- Create: `CLAUDE.md`

**Interfaces:**
- Consumes: every doc created in Tasks 3-12 (links must resolve).

- [ ] **Step 1: Write the file** — concise, with these sections (content per spec "CLAUDE.md"):
  1. **App description + stack** (one paragraph).
  2. **The meta-rule** up front — follow documented patterns; if none exists, stop and discuss; never assume.
  3. **The docs-maintenance rule** — keep docs in sync in the same change; link [docs/README.md](docs/README.md).
  4. **Architecture** in ~5 bullets, link [docs/architecture.md](docs/architecture.md).
  5. **Golden-path recipe "How to add a new entity/feature":** model → repository (columns + map methods) → register in `DatabaseService` (`initializeRepositories`, `deleteAllData`) → migration → append to `migrations_list.dart` → views subscribing to repo events. Link [data-layer.md](docs/data-layer.md) + [migrations.md](docs/migrations.md).
  6. **Pointers** to [conventions.md](docs/conventions.md), [coding-style.md](docs/coding-style.md), [ui-patterns.md](docs/ui-patterns.md) with one-line summaries.
  7. **Commands:** `flutter run`, `flutter analyze`, `flutter test`; note **no** build_runner/codegen (models hand-written); note global Java/`mvn` rules do **not** apply (Dart/Flutter project).
  8. **Global-CLAUDE reconciliation:** prefer IDE rename for renames; "DB enums for enumerated types" → here enums are stored as TEXT via `.name` (established pattern).
  9. **Read-before-you-act guide:** persisted entity → data-layer + migrations; screen/dialog → coding-style + ui-patterns; feature work → that `features/` doc; no matching pattern → stop (meta-rule).
  10. **Feature index** — links to all six `features/` docs.

- [ ] **Step 2: Verify** every link resolves to a file created in this plan; lint-clean; the doc is concise (skim test — an anchor, not an encyclopedia).

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add root CLAUDE.md anchor (meta-rule, recipe, read-before-act guide)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 14: Final consistency pass

**Files:**
- Review: all files under `docs/`, `CLAUDE.md`, `README.md`.

- [ ] **Step 1: Link check** — grep every relative link and confirm the target exists.

Run: `grep -rhoE "\]\(([^)]+)\)" docs CLAUDE.md README.md | sed -E 's/^\]\(//; s/\)$//' | sort -u`
Then spot-check that each path (stripping `#Lxx` anchors and resolving `../`) exists.

- [ ] **Step 2: Markdown-lint sanity** — open each doc; confirm no MD warnings (code-fence languages present; blank lines around lists; single H1).

- [ ] **Step 3: Build sanity** — `flutter analyze` clean of new errors.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "docs: fix cross-references and lint issues from consistency pass

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:** architecture.md (T4), conventions.md incl. meta-rule/folder/naming/file-size/generalization/language/DI/balance/no-tests/soft-delete/enum storage (T5), coding-style.md incl. formatting/comments/method-order/build-decomposition/naming/async-state (T6), ui-patterns.md (T7), data-layer.md (T8), migrations.md (T9), tech-debt.md full enumeration (T10), six feature docs (T11-12), docs/README.md guide incl. maintenance rule + routing (T3), CLAUDE.md anchor incl. read-before-act + recipe (T13), root README + TODO move (T2), five deletions (T1), final pass (T14). All spec sections mapped.

**Placeholder scan:** no TBD/TODO-as-content; the root README "TODO / Backlog" is intended content, not a plan placeholder.

**Type/name consistency:** doc filenames, method names (`updateBalance`, `switchShowTotal`, `getExpensesByCategory`, `getExpensesByDay`, `getLastMovements`, `getCategoriesByType`, `sync`, `deleteAllData`), and file:line refs match the spec and the audited code.
