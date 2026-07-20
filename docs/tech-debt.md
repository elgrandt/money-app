# Tech debt

This file enumerates **every existing place** that does not match the patterns defined in
these docs, so the debt is trackable and can be paid down incrementally. Keep it current per
the maintenance policy in [README.md](README.md): when you fix an item, remove it; when you
add code that breaks a pattern (it happens), record it here. The patterns themselves are in
[conventions.md](conventions.md), [coding-style.md](coding-style.md), and
[ui-patterns.md](ui-patterns.md).

Audit baseline: 2026-07-20. A bugs/robustness pass plus two formatting/state cleanups paid down
most of the previously-listed debt (leading blank lines, import blanks, tight interpolation,
`super.key` spacing, narration/Spanish comments, missing `mounted` guards, `void` overrides,
most inline `GetIt`, deprecated APIs, and several bugs). What remains is below.

## Robustness / data-integrity (documented only)

- **Balance mutations are not transactional.**
  [movements.repository.dart:139-176](../lib/repositories/movements.repository.dart#L139) and
  [accounts.repository.dart:51-94](../lib/repositories/accounts.repository.dart#L51) perform
  insert/delete and `updateBalance` as separate awaits; a failure midway leaves the stored
  `Account.total` inconsistent with movements. Wrapping each operation in a `db.transaction`
  would guarantee the invariant. **Low priority** — the failure window is small.
- **Migration sync continues after a failed migration.**
  [migrations.repository.dart](../lib/repositories/migrations.repository.dart) catches a
  failing `up()` and only logs it, so `sync()` still runs later migrations even though an
  earlier one failed — breaking the ordered-migration guarantee. Making it stop (rethrow) is a
  startup-behavior decision left for later.
- **Backup safety.** [backups.dart](../lib/views/backups/backups.dart) copies/overwrites the
  live `db.sqlite` while the connection is open: `saveBackup` may miss unflushed WAL data, and
  restore replaces the file under the open handle. A "restart the app" dialog after restore is
  in place as a mitigation; the proper fix (close → replace → reopen → re-init the DB, and
  flush/checkpoint before saving) is deferred.

## Behavior / config debt (documented only)

- Hardcoded `eurToUsd = 1.11` in
  [utils.service.dart](../lib/services/utils.service.dart) `updateCurrencyMappings` — no
  EUR→USD API was found at the time; revisit later.
- Unused codegen dependencies in `pubspec.yaml`: `json_serializable`, `json_annotation`,
  `build_runner` — nothing uses them; models are hand-written.

## Coding-style / state-pattern violations

- **Inline `GetIt.instance.get<…>()` in `const` `StatelessWidget`s.** Caching the lookup in a
  field (the DI convention) would force dropping the `const` constructor, so these are left
  pending a decision on how to cache DI in a const widget:
  [currency_selector.dart](../lib/views/generics/currency_selector.dart) (`getCurrencyIcon` in
  `build`), [dashboard.dart](../lib/views/home/dashboard.dart) (`buildTotalsChart` value
  callback), and `MovementListItem` in
  [movements_list.dart](../lib/views/home/movements_list.dart) (`amount` getter / `buildAmount`
  — a per-list-item hot path). State classes and repositories have been converted to cached
  fields.
- **`canSubmit` runs `Form.validate()` inside `build`** (validation as a build-time side
  effect) — [new_movement.dialog.dart](../lib/views/movements/new_movement.dialog.dart),
  [new_account.dialog.dart](../lib/views/accounts/new_account.dialog.dart),
  [new_category.dialog.dart](../lib/views/categories/new_category.dialog.dart). Fixing this
  needs a small pattern decision (compute validity from field changes instead of validating in
  `build`), so it is deferred.

## Not a violation (recorded to avoid re-flagging)

- **File size** — no file exceeds the ~500-line guideline; the largest is
  `new_movement.dialog.dart` at ~440 lines.
- **`SCREAMING_CASE` enum members** (`Currency`, `MovementType`, `DatabaseColumnType`, …) trip
  the `constant_identifier_names` lint. This is the project's deliberate style — enums are
  stored via `.name` and read back with `byName`, so the wire values are intentional. Do not
  "fix".
- **`convertCurrencies` triggers an unawaited `updateCurrencyMappings()`**
  ([utils.service.dart](../lib/services/utils.service.dart)). Intentional: the multiplier
  changes infrequently, so the rate is refreshed in the background without blocking the UI.
  First-load conversions in `Home` are covered because `initializeCurrencies()` awaits the
  update before rendering.
</content>
