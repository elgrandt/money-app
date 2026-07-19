# Coding style

How code is written and organized within a file. For project-level rules (structure, naming
by role, DI, storage) see [conventions.md](conventions.md); for visual widgets see
[ui-patterns.md](ui-patterns.md).

## Formatting

- **2-space indentation**, no tabs.
- **Single quotes** for all strings.
- **No leading blank line** at the top of a file, and **no blank lines between imports** —
  the file starts on line 1 with the first `import` and the import block is contiguous.
- **Named-parameter brace spacing:** spaces inside the braces when there is more than one
  parameter, tight braces when `super.key` is the only one:

  ```dart
  const NewMovementDialog({ super.key, this.selectedAccount, this.movement });
  const Loader({super.key});
  ```

- Use `const SizedBox(height: N)` / `SizedBox(width: N)` for spacing inside `Column`/`Row`.
- **String interpolation always uses spaces inside the braces — `${ expr }`** — even for
  simple expressions.

## Comments

Keep comments minimal; the code should be self-documenting. The only sanctioned comments are
extension markers such as `// Add new repositories here` in
[database.service.dart](../lib/services/database.service.dart). Do not narrate what the code
does line by line.

## Method ordering inside a class

Order members as:

**attributes → getter/setter members → constructor → lifecycle
(`initState` / `dispose` / `didUpdateWidget`) → logic methods → `build` → `buildX()` methods.**

- `buildX()` sub-widget methods appear in the order they are used within `build`.
- Use untyped getters for computed values, e.g. `get canSubmit { ... }`,
  `get filteredMovements { ... }`.

## Build decomposition

- **Keep `build` simple and descriptive** — it should read as a high-level composition of the
  screen's sections, not a deep inline widget tree.
- Extract a `buildX(context)` method for a section when it is **large** or when a name makes
  the structure clearer **semantically** — for example the dialog sections `buildTitle`,
  `buildContent`, `buildActionButtons` in
  [new_movement.dialog.dart](../lib/views/movements/new_movement.dialog.dart), or the chart
  sections `buildTotal`, `buildTotalsChart`, `buildAllExpensesChart` in
  [dashboard.dart](../lib/views/home/dashboard.dart). This is not limited to list-item
  iteration.
- **Do not over-extract.** Trivial widgets — a `SizedBox` spacer, a one-line `Text`, a small
  inline child — stay inline; a `buildX` per spacing would add noise, not clarity. Use
  judgment: extract when the method earns its name.
- A `buildX()` returns a `Widget`, or a `List<Widget>` (spread with `...`) when the section is
  a group of siblings — e.g. `buildAccounts`, `buildConversionRateSection`.

## Naming

- Data fetch: `getX()` — e.g. `getAccounts`, `getMovements`, `getCategories`.
- Event subscription: `watchXChanges()`; the listener is stored in an `xListener` field.
- Dialog opener: `openXDialog()`.
- Navigation: `goToX(context)`.
- Sub-widget builder: `buildX(context)`.
- `State` classes are private `_XState` **unless** an external widget needs a
  `GlobalKey<...State>` handle, in which case the underscore is dropped — e.g.
  `MovementsListState` in [movements_list.dart](../lib/views/home/movements_list.dart).

## Async and state

- **Gate on the database:** `await databaseService.initialized;` before any DB access.
- **Error handling:** fetch methods wrap the query in `try`/`catch` and log with
  `logger.e('Error ...', error: error, stackTrace: stackTrace)`.
- **Guard the context/state after awaits:** whenever `setState` or `context` is used after an
  `await`, guard it first with `if (!mounted) return;` or `if (!context.mounted) return;`.
  Example: [new_account.dialog.dart:33-36](../lib/views/accounts/new_account.dialog.dart#L33-L36).
- **Reactive refresh:** subscribe to a repository's events in `watchXChanges()`, refetch on
  change, and `cancel()` the listener in `dispose()` — see
  [architecture.md](architecture.md).
