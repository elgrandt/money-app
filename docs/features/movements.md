# Movements

## What it does

A movement is a single financial event on one or two accounts. There are three types:

- **ADD** (Ingreso / income) — money into a target account.
- **REMOVE** (Gasto / expense) — money out of a source account.
- **TRANSFER** (Transferencia) — money from a source account to a target account, with an
  optional conversion rate when the two accounts use different currencies.

Creating a movement updates the affected account balances; removing one reverses them. Editing
a movement is implemented as remove-then-create.

## Data model

`Movement` — [movement.model.dart](../../lib/models/movement.model.dart):

- `type` — `MovementType` (`ADD`, `REMOVE`, `TRANSFER`); `movementTypeNames` maps each to its
  Spanish label.
- `description`, `amount`, `category`.
- `conversionRate` — set only for cross-currency transfers.
- `source`, `target` — nullable `Account`s (which are set depends on `type`).
- `creationDate`.

## Key repository methods

`MovementsRepository` — [movements.repository.dart](../../lib/repositories/movements.repository.dart):

- `create(type, description, amount, conversionRate, category, source, target, creationDate)` —
  sets `source`/`target` per type, stores `conversionRate` only for cross-currency transfers,
  inserts, then updates balances via `AccountsRepository.updateBalance`
  ([:140-163](../../lib/repositories/movements.repository.dart#L140-L163)).
- `remove(movement)` — reverses the balance effects, then deletes
  ([:165-177](../../lib/repositories/movements.repository.dart#L165-L177)).
- `getLastMovements(account, {page, itemsPerPage})` — recent movements, optionally for one
  account, newest first ([:130-138](../../lib/repositories/movements.repository.dart#L130-L138)).
- `getExpensesByCategory(...)` / `getExpensesByDay(...)` — aggregations for statistics; both
  take a `displayCurrency` and convert each movement at its own `creationDate`
  ([:179-238](../../lib/repositories/movements.repository.dart#L179-L238)); see
  [statistics.md](statistics.md).
- `find(...)` — overridden to eagerly join source/target accounts (see
  [data-layer.md](../data-layer.md)).

## Views involved

- [new_movement.dialog.dart](../../lib/views/movements/new_movement.dialog.dart) — create/edit
  dialog: type selector, source/target pickers (shown per type), amount (masked input),
  conversion-rate section (only for cross-currency transfers), description, date, and category
  selector (with inline category creation).
- [movement_details.dialog.dart](../../lib/views/movements/movement_details.dialog.dart) — a
  human-readable sentence describing the movement, plus edit and delete actions.
- [movements_list.dart](../../lib/views/home/movements_list.dart) — the searchable list
  (`MovementsList`) and each row (`MovementListItem`), with type-colored amounts.

## Edge cases

- **Currency conversion on transfer** — when `source.currency != target.currency`, the dialog
  shows a conversion-rate field, `conversionRate` is stored, and the target is credited
  `amount * conversionRate`; the source is debited `amount`
  ([movements.repository.dart:146-161](../../lib/repositories/movements.repository.dart#L146-L161)).
  The rate is always **entered in the ≥ 1 direction** — the price of the stronger currency (e.g.
  "the dollar at 1485"). When the target currency is stronger than the source (detected via
  `convertCurrencies(1, source, target) < 1`) the field shows `Tasa de conversión 1 ÷ X` and
  stores `1/X` as `conversionRate`; otherwise it shows `Tasa de conversión X` and stores `X`
  directly. The input uses 2 decimals and defaults to `0`, so the real rate must be entered (the
  validator rejects `0`). Editing re-derives the displayed value from the stored `conversionRate`
  using the same direction check. See [currency.md](currency.md).
- **Source/target by type** — ADD has only a target, REMOVE only a source, TRANSFER both
  ([:145-147](../../lib/repositories/movements.repository.dart#L145-L147)).
- **Editing = remove + create** — the edit path removes the original (reversing balances) then
  creates the new one ([new_movement.dialog.dart:76-93](../../lib/views/movements/new_movement.dialog.dart#L76-L93)).
- Balances stay correct only because create/remove go through `updateBalance` — see the
  denormalized-balance rule in [conventions.md](../conventions.md).
- **Date-based display conversion** — when a movement's amount is shown in a display currency
  (the movements list, [movements_list.dart:129-141](../../lib/views/home/movements_list.dart#L129-L141))
  or aggregated for statistics, the conversion uses `convertCurrenciesAt` at the movement's
  `creationDate`, so a past movement keeps the value it had at the time rather than being
  re-valued at today's rate (see [currency.md](../features/currency.md)).
- **Background rate refresh on open** — opening the new/edit movement dialog fires
  `utilsService.updateCurrencyMappings()` unawaited
  ([new_movement.dialog.dart:67](../../lib/views/movements/new_movement.dialog.dart#L67)); it is
  throttled to at most once per hour, so it records the current rates into the history table when
  stale without blocking the dialog.
