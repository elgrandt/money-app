# Tech debt

This file enumerates **every existing place** that does not match the patterns defined in
these docs, so the debt is trackable and can be paid down incrementally. Keep it current per
the maintenance policy in [README.md](README.md): when you fix an item, remove it; when you
add code that breaks a pattern (it happens), record it here. The patterns themselves are in
[conventions.md](conventions.md), [coding-style.md](coding-style.md), and
[ui-patterns.md](ui-patterns.md).

Audit baseline: 2026-07-20 (bugs / robustness pass — a batch of mechanical fixes, deprecations,
and several small bugs were paid down; the items below are what remains).

## Robustness / data-integrity (documented only)

- **Balance mutations are not transactional.**
  [movements.repository.dart:140-177](../lib/repositories/movements.repository.dart#L140) and
  [accounts.repository.dart:52-95](../lib/repositories/accounts.repository.dart#L52) perform
  insert/delete and `updateBalance` as separate awaits; a failure midway leaves the stored
  `Account.total` inconsistent with movements. Wrapping each operation in a `db.transaction`
  would guarantee the invariant. **Low priority** — the failure window is small.
- **Migration sync continues after a failed migration.**
  [migrations.repository.dart:49-59](../lib/repositories/migrations.repository.dart#L49)
  catches a failing `up()` and only logs it, so `sync()` still runs later migrations even
  though an earlier one failed — breaking the ordered-migration guarantee. Making it stop
  (rethrow) is a startup-behavior decision left for later. (The record `insert` is now awaited.)
- **Backup safety.** [backups.dart](../lib/views/backups/backups.dart) copies/overwrites the
  live `db.sqlite` while the connection is open: `saveBackup` may miss unflushed WAL data, and
  restore replaces the file under the open handle. A "restart the app" dialog after restore is
  in place as a mitigation; the proper fix (close → replace → reopen → re-init the DB, and
  flush/checkpoint before saving) is deferred.

## Behavior / config debt (documented only)

- Hardcoded `EURtoUSD = 1.11` in
  [utils.service.dart:67](../lib/services/utils.service.dart#L67) — no EUR→USD API was found at
  the time; revisit later.
- Unused codegen dependencies in `pubspec.yaml`: `json_serializable`, `json_annotation`,
  `build_runner` — nothing uses them; models are hand-written.

## Language-rule violations (English code + logs, Spanish UI)

- Spanish code comments — [expenses_by_day.dart:70](../lib/views/statistics/expenses_by_day.dart#L70),
  [:89](../lib/views/statistics/expenses_by_day.dart#L89),
  [:96](../lib/views/statistics/expenses_by_day.dart#L96),
  [:114](../lib/views/statistics/expenses_by_day.dart#L114).

## Formatting-rule violations

- **Leading blank line at top of file** (rule: never). 39 files — everything under `lib/`
  except `main.dart`, `home.dart`, `movements_list.dart`, `all_expenses.dart`, `backups.dart`:
  - `migrations/accounts_initialization.migration.dart`
  - `migrations/add_deleted_field_to_account.migration.dart`
  - `migrations/add_order_field_to_account.migration.dart`
  - `migrations/add_showTotal_field_to_account.migration.dart`
  - `migrations/categories_initialization.migration.dart`
  - `migrations/example.migration.dart`
  - `migrations/migration_definition.dart`
  - `migrations/migrations_list.dart`
  - `migrations/movements_initialization.migration.dart`
  - `models/account.model.dart`
  - `models/base.model.dart`
  - `models/category.model.dart`
  - `models/migration.model.dart`
  - `models/movement.model.dart`
  - `repositories/accounts.repository.dart`
  - `repositories/base.repository.dart`
  - `repositories/categories.repository.dart`
  - `repositories/migrations.repository.dart`
  - `repositories/movements.repository.dart`
  - `services/database.service.dart`
  - `services/utils.service.dart`
  - `views/accounts/account_list.dart`
  - `views/accounts/new_account.dialog.dart`
  - `views/categories/category_list.dart`
  - `views/categories/new_category.dialog.dart`
  - `views/generics/button_selector.dart`
  - `views/generics/cupertino_select.dart`
  - `views/generics/currency_selector.dart`
  - `views/generics/easy_pie_chart.dart`
  - `views/generics/loader.dart`
  - `views/generics/navbar.dart`
  - `views/generics/tabs.dart`
  - `views/home/dashboard.dart`
  - `views/home/total_viewer.dart`
  - `views/movements/movement_details.dialog.dart`
  - `views/movements/new_movement.dialog.dart`
  - `views/statistics/expenses_by_category.dart`
  - `views/statistics/expenses_by_day.dart`
  - `views/statistics/statistics.dart`
  - Note: the field-adding migration files have **two or three** leading blank lines.
- **Blank line inside the import block** (rule: none) —
  [database.service.dart:3](../lib/services/database.service.dart#L3),
  [utils.service.dart:3](../lib/services/utils.service.dart#L3),
  [button_selector.dart:3](../lib/views/generics/button_selector.dart#L3),
  [easy_pie_chart.dart:3](../lib/views/generics/easy_pie_chart.dart#L3),
  [navbar.dart:3](../lib/views/generics/navbar.dart#L3),
  [dashboard.dart:3](../lib/views/home/dashboard.dart#L3),
  [expenses_by_category.dart:3](../lib/views/statistics/expenses_by_category.dart#L3),
  [expenses_by_day.dart:3](../lib/views/statistics/expenses_by_day.dart#L3).
- **Tight `${x}` interpolation** (rule: always `${ x }`) —
  [movements.repository.dart:82](../lib/repositories/movements.repository.dart#L82),
  [:83](../lib/repositories/movements.repository.dart#L83);
  [base.repository.dart:81](../lib/repositories/base.repository.dart#L81),
  [:84](../lib/repositories/base.repository.dart#L84),
  [:105](../lib/repositories/base.repository.dart#L105),
  [:140](../lib/repositories/base.repository.dart#L140);
  [movement.model.dart:30](../lib/models/movement.model.dart#L30);
  [easy_pie_chart.dart:34](../lib/views/generics/easy_pie_chart.dart#L34);
  [utils.service.dart:20](../lib/services/utils.service.dart#L20);
  [movements_list.dart:37](../lib/views/home/movements_list.dart#L37);
  [new_movement.dialog.dart:317](../lib/views/movements/new_movement.dialog.dart#L317).
- **Spaced braces around a lone `super.key`** (rule: tight `{super.key}`) —
  [navbar.dart:47](../lib/views/generics/navbar.dart#L47),
  [category_list.dart:16](../lib/views/categories/category_list.dart#L16).

## Comment-policy violations (minimal, self-documenting code)

- Narration comments — [cupertino_select.dart:13](../lib/views/generics/cupertino_select.dart#L13),
  [:20](../lib/views/generics/cupertino_select.dart#L20),
  [:24](../lib/views/generics/cupertino_select.dart#L24),
  [:26](../lib/views/generics/cupertino_select.dart#L26),
  [:55](../lib/views/generics/cupertino_select.dart#L55),
  [:59](../lib/views/generics/cupertino_select.dart#L59) (copied from the Flutter sample);
  [account_list.dart:135](../lib/views/accounts/account_list.dart#L135);
  [category_list.dart:127](../lib/views/categories/category_list.dart#L127).

## Coding-style / state-pattern violations

- **Missing `mounted` / `context.mounted` guard after `await` before `setState`** —
  [account_list.dart:48](../lib/views/accounts/account_list.dart#L48) (`getAccounts`),
  [statistics.dart:33](../lib/views/statistics/statistics.dart#L33) (`getAccounts`),
  [category_list.dart:46](../lib/views/categories/category_list.dart#L46) (`getCategories`),
  [new_movement.dialog.dart:101](../lib/views/movements/new_movement.dialog.dart#L101)
  (`getCategories`) and [:110](../lib/views/movements/new_movement.dialog.dart#L110)
  (`getAccounts`),
  [home.dart:52](../lib/views/home/home.dart#L52) (`initializeCurrencies`) and
  [:59](../lib/views/home/home.dart#L59) (`getAccounts`),
  [expenses_by_category.dart:48](../lib/views/statistics/expenses_by_category.dart#L48)
  (`getExpensesByCategory`),
  [expenses_by_day.dart:50](../lib/views/statistics/expenses_by_day.dart#L50)
  (`getExpensesByDay` → `doCalculations`).
- **`use_build_context_synchronously`** — the dialog `submit`/delete flows guard with
  `if (!context.mounted)` after an `await`, but the analyzer flags the guard as "unrelated"
  (a `State` should guard with its own `mounted`): [new_account.dialog.dart:36](../lib/views/accounts/new_account.dialog.dart#L36),
  [new_category.dialog.dart:29](../lib/views/categories/new_category.dialog.dart#L29),
  [movement_details.dialog.dart:82](../lib/views/movements/movement_details.dialog.dart#L82),
  [new_movement.dialog.dart:92](../lib/views/movements/new_movement.dialog.dart#L92).
- **Inline `GetIt.instance.get<…>()` not cached in a field.** Views:
  [currency_selector.dart:24](../lib/views/generics/currency_selector.dart#L24),
  [dashboard.dart:64](../lib/views/home/dashboard.dart#L64),
  [total_viewer.dart:37](../lib/views/home/total_viewer.dart#L37) /
  [:48](../lib/views/home/total_viewer.dart#L48) /
  [:60](../lib/views/home/total_viewer.dart#L60),
  [movements_list.dart:36](../lib/views/home/movements_list.dart#L36) /
  [:81](../lib/views/home/movements_list.dart#L81) /
  [:138](../lib/views/home/movements_list.dart#L138) /
  [:223](../lib/views/home/movements_list.dart#L223),
  [expenses_by_day.dart:318](../lib/views/statistics/expenses_by_day.dart#L318) /
  [:348](../lib/views/statistics/expenses_by_day.dart#L348). Repositories:
  [movements.repository.dart:152](../lib/repositories/movements.repository.dart#L152) /
  [:166](../lib/repositories/movements.repository.dart#L166) /
  [:197](../lib/repositories/movements.repository.dart#L197) /
  [:228](../lib/repositories/movements.repository.dart#L228),
  [base.repository.dart:166](../lib/repositories/base.repository.dart#L166). (Migration files
  legitimately use top-level/local `GetIt` access — that is the migration structure, not a
  violation.)
- **Empty `initState` that only calls `super.initState()`** —
  [total_viewer.dart:32](../lib/views/home/total_viewer.dart#L32).
- **Missing `void` return type on overrides** —
  [statistics.dart:28](../lib/views/statistics/statistics.dart#L28) (`initState`),
  [movements_list.dart:57](../lib/views/home/movements_list.dart#L57) (`didUpdateWidget`).
- **`canSubmit` runs `Form.validate()` inside `build`** (validation as a build-time side
  effect) — [new_movement.dialog.dart:53](../lib/views/movements/new_movement.dialog.dart#L53),
  [new_account.dialog.dart:22](../lib/views/accounts/new_account.dialog.dart#L22),
  [new_category.dialog.dart:22](../lib/views/categories/new_category.dialog.dart#L22).

## Naming

- **`non_constant_identifier_names`** — the currency-rate locals `USDtoARS` / `EURtoARS` /
  `EURtoUSD` in [utils.service.dart:65-67](../lib/services/utils.service.dart#L65) are not
  lowerCamelCase. Minor; they mirror the API's directional naming.

## Not a violation (recorded to avoid re-flagging)

- **File size** — no file exceeds the ~500-line guideline; the largest is
  `new_movement.dialog.dart` at 440 lines.
- **`SCREAMING_CASE` enum members** (`Currency`, `MovementType`, `DatabaseColumnType`, …) trip
  the `constant_identifier_names` lint. This is the project's deliberate style — enums are
  stored via `.name` and read back with `byName`, so the wire values are intentional. Do not
  "fix".
- **`convertCurrencies` triggers an unawaited `updateCurrencyMappings()`**
  ([utils.service.dart:78-79](../lib/services/utils.service.dart#L78)). Intentional: the
  multiplier changes infrequently, so the rate is refreshed in the background without blocking
  the UI. First-load conversions in `Home` are covered because `initializeCurrencies()` awaits
  the update before rendering.
</content>
