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

- Unused codegen dependencies in `pubspec.yaml`: `json_serializable`, `json_annotation`,
  `build_runner` — nothing uses them; models are hand-written.

## Framework smells (not a documented-pattern violation)

- **`canSubmit` runs `Form.validate()` inside `build`.** The `get canSubmit` getter is itself a
  sanctioned pattern ([coding-style.md](coding-style.md)), and all three dialogs do it
  identically, so this breaks no money-app rule. But `FormState.validate()` mutates each
  field's error state and requests a rebuild, so evaluating it during `build` gives `build` a
  side effect — a general Flutter smell. It works here only because errors are hidden
  (`errorStyle` height 0) and the forms `setState` on change. Files:
  [new_movement.dialog.dart](../lib/views/movements/new_movement.dialog.dart),
  [new_account.dialog.dart](../lib/views/accounts/new_account.dialog.dart),
  [new_category.dialog.dart](../lib/views/categories/new_category.dialog.dart). A side-effect-free
  fix would compute validity from field changes; left as-is for now.

## Not a violation (recorded to avoid re-flagging)

- **File size** — no file exceeds the ~500-line guideline; the largest is
  `new_movement.dialog.dart` at ~440 lines.
- **Inline `GetIt` in `const` `StatelessWidget`s** (`CurrencySelector`, `Dashboard`,
  `MovementListItem`). Keeping the `const` constructor takes priority over caching the lookup
  in a field — see the DI exception in [conventions.md](conventions.md).
- **`SCREAMING_CASE` enum members** (`Currency`, `MovementType`, `DatabaseColumnType`, …) trip
  the `constant_identifier_names` lint. This is the project's deliberate style — enums are
  stored via `.name` and read back with `byName`, so the wire values are intentional. Do not
  "fix".
- **`convertCurrencies` triggers an unawaited `updateCurrencyMappings()`**
  ([utils.service.dart](../lib/services/utils.service.dart)). Intentional: the multiplier
  changes infrequently, so the rate is refreshed in the background without blocking the UI.
  `Home` no longer awaits the network fetch before rendering — `initializeCurrencies()` hydrates
  cached mappings from the DB and renders immediately, and `updateCurrencyMappings` swallows
  errors, so the background refresh is safe offline.
</content>
