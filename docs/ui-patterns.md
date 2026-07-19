# UI patterns

The visual and structural patterns used across the app's screens and dialogs. For how build
methods are decomposed and named, see [coding-style.md](coding-style.md).

## Screen shell

Full screens are wrapped in the generic `Navbar` widget, which provides the `AppBar` (centered
title, hamburger menu) and hosts the body and floating action button —
[navbar.dart](../lib/views/generics/navbar.dart):

```dart
return Navbar(
  title: 'Cuentas',
  floatingActionButton: FloatingActionButton(...),
  body: accounts == null ? const Loader() : buildAccountList(context),
);
```

The floating action button is `Theme.of(context).primaryColor`, circular
(`RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))`), with a white
`Icons.add` — see [account_list.dart:82-94](../lib/views/accounts/account_list.dart#L82-L94).

## Dialog shell

Dialogs follow: `Dialog → Form` (when there are inputs) `→ SingleChildScrollView`
(padding `symmetric(vertical: 25, horizontal: 25)`) `→ Column → [buildTitle, ...content,
buildActionButtons]` — see
[new_account.dialog.dart](../lib/views/accounts/new_account.dialog.dart).

## Title style

Dialog titles are centered, `fontSize: 20`, `Theme.of(context).primaryColor`, bold:

```dart
Text('Nueva cuenta', textAlign: TextAlign.center,
  style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold));
```

## Action buttons

A row with `mainAxisAlignment: MainAxisAlignment.spaceEvenly` holding a Cancel `TextButton`
(primary-color text) and a primary `ElevatedButton` (primary-color background, white text,
`fixedSize: const Size(120, 30)`). The primary button is enabled/disabled from a `canSubmit`
getter, falling back to `Theme.of(context).disabledColor` when disabled — see
[new_account.dialog.dart:100-125](../lib/views/accounts/new_account.dialog.dart#L100-L125).

## Loading state

While data is null, show the generic `Loader` (a centered "Cargando…" text) and swap to the
real content once loaded — [loader.dart](../lib/views/generics/loader.dart):

```dart
body: accounts == null ? const Loader() : buildAccountList(context),
```

## Semantic colors

Movement direction is color-coded:

- Income / inflow → `Colors.green.shade900`
- Expense / outflow → `Colors.red.shade900`
- Neutral transfer → `Colors.yellow.shade900`

See `getMovementTypeColor` in
[movements_list.dart:144-164](../lib/views/home/movements_list.dart#L144-L164). Primary accents
use `Theme.of(context).primaryColor`; destructive actions use `CupertinoColors.destructiveRed`
or `Theme.of(context).colorScheme.error`.

## Component choice

- **Segmented / multi-choice selection** → `ButtonSelector`
  ([button_selector.dart](../lib/views/generics/button_selector.dart)), used for movement type,
  currency, period, and category selection. It optionally renders an add (`+`) button.
- **Dropdown / picker** → `CupertinoSelect`
  ([cupertino_select.dart](../lib/views/generics/cupertino_select.dart)), used for account and
  chart-type selection and the source/target pickers.
- **Text-style tappable action** → `CupertinoButton(padding: EdgeInsets.zero)`, used for menu
  entries and inline actions.
- **Pie charts** → the generic `EasyPieChart<T>`
  ([easy_pie_chart.dart](../lib/views/generics/easy_pie_chart.dart)); **tabs** → the generic
  `Tabs` ([tabs.dart](../lib/views/generics/tabs.dart)).

## Money and confirmations

- Format every monetary value through `UtilsService.beautifyCurrency(amount, currency)` — never
  format currency ad hoc.
- Ask for destructive confirmation through `UtilsService.confirm(context, title:, message:)`,
  which returns a `Future<bool>` — see
  [utils.service.dart:89-128](../lib/services/utils.service.dart#L89-L128).
