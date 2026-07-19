# Accounts

## What it does

Accounts are the wallets the user tracks money in. Each has a name, a currency
(ARS / USD / EUR), and a stored balance. The user can create accounts, reorder them (drag), and
delete them; the total of an account can be shown or hidden. The app requires at least one
account — the last one cannot be deleted, and a welcome screen prompts the user to create the
first.

## Data model

`Account` — [account.model.dart](../../lib/models/account.model.dart):

- `name` — display name.
- `total` — stored balance (denormalized; see [conventions.md](../conventions.md)).
- `currency` — `Currency` enum (`ARS`, `USD`, `EUR`).
- `sortIndex` — ordering position.
- `showTotal` — whether the balance is revealed (per-account toggle).
- `deleted` — soft-delete flag.

## Key repository methods

`AccountsRepository` — [accounts.repository.dart](../../lib/repositories/accounts.repository.dart):

- `updateBalance(id, amount)` — adds `amount` to the account's `total`
  ([:52-60](../../lib/repositories/accounts.repository.dart#L52-L60)); called from movement
  create/remove.
- `switchShowTotal(id)` — toggles `showTotal`
  ([:62-70](../../lib/repositories/accounts.repository.dart#L62-L70)).
- `delete(id)` — soft delete: removes the account's ADD/REMOVE movements via
  `removeAllAccountMovements`, then sets `deleted = true`
  ([:72-95](../../lib/repositories/accounts.repository.dart#L72-L95)).
- `find(...)` — overridden to exclude soft-deleted accounts
  ([:97-101](../../lib/repositories/accounts.repository.dart#L97-L101)).

## Views involved

- [account_list.dart](../../lib/views/accounts/account_list.dart) — the `/accounts` screen; a
  `ReorderableListView` that persists order via `updateAccountsOrder`, with per-row delete.
- [new_account.dialog.dart](../../lib/views/accounts/new_account.dialog.dart) — create dialog
  (name + currency); new accounts get `sortIndex = accountsCount` and `total = 0`.
- [total_viewer.dart](../../lib/views/home/total_viewer.dart) — shows/hides an account's total
  (tapping toggles `showTotal`); for the aggregate (no account) it toggles local visibility.
- Accounts drive the per-account tabs on the home screen
  ([home.dart](../../lib/views/home/home.dart)).

## Edge cases

- **Cannot delete the last account** — the delete icon is hidden when `accounts!.length <= 1`
  ([account_list.dart:137-144](../../lib/views/accounts/account_list.dart#L137-L144)).
- **Soft delete keeps transfers** — `removeAllAccountMovements` deletes only ADD/REMOVE
  movements; transfers referencing the account are left intact
  ([accounts.repository.dart:85-95](../../lib/repositories/accounts.repository.dart#L85-L95)).
- **Balance is denormalized** — any new balance-affecting path must call `updateBalance` to keep
  `total` correct.
- Reordering temporarily sets `disableAccountUpdate` to avoid the change-event refetch fighting
  the in-progress reorder.
