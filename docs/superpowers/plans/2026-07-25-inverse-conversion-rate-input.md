# Inverse Conversion Rate Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In the new/edit movement dialog, let the user enter the exchange rate in the ≥ 1 direction (the price of the stronger currency), showing `Tasa de conversión 1 ÷ X` and storing `1/X` when the target currency is stronger than the source.

**Architecture:** Pure UI change in a single dialog. The stored `conversionRate` semantics are unchanged (`target = amount * conversionRate`, a full-precision `double`). A derived getter `isRateInverse` decides the direction from live rates; the raw typed value (`rawConversionRate`, always ≥ 1) is the single source of truth and the effective `conversionRate` is computed from it. No model, repository, or migration changes.

**Tech Stack:** Flutter/Dart, `flutter_masked_text2` (`MoneyMaskedTextController`), `get_it` DI, `UtilsService` for currency conversion.

## Global Constraints

- **No tests by policy** — do not add tests. Verification gate is `flutter analyze` (must pass clean) plus manual verification in the running app.
- **Language** — code and doc identifiers/prose in English (feature docs are English); UI strings in Spanish (`es_AR`).
- **Git** — work on branch `feature/inverse-conversion-rate-input` (already created); never commit to `master`.
- **Docs-maintenance rule** — doc updates ship in the same commit as the code.
- **Meta-rule** — follow the approved spec: `docs/superpowers/specs/2026-07-25-inverse-conversion-rate-input-design.md`. Do not invent new patterns.

---

### Task 1: Inverse conversion-rate input in the movement dialog

**Files:**
- Modify: `lib/views/movements/new_movement.dialog.dart`
- Modify: `docs/features/movements.md`
- Modify: `docs/features/currency.md`

**Interfaces:**
- Consumes: `utilsService.convertCurrencies(double amount, Currency from, Currency to)` → `double` (returns `amount` when `from == to` or when a mapping is missing).
- Consumes: `MoneyMaskedTextController({ String decimalSeparator, String thousandSeparator, int precision, double initialValue })`.
- Consumes: `Movement.conversionRate` (`double?`, null for non-cross-currency movements).
- Produces (internal to the dialog state): `bool get isRateInverse`, `double rawConversionRate`, `double get conversionRate`. `conversionRate` keeps the same meaning callers already rely on (`create(..., conversionRate, ...)` and the "Recibís" preview).

---

- [ ] **Step 1: Replace the `conversionRate` field with raw value + derived getters**

In `_NewMovementDialogState`, replace the field declaration:

```dart
  double conversionRate = 1;
```

with:

```dart
  double rawConversionRate = 0;
```

Then add these getters near the other getters (`canSubmit`, `isEditing`):

```dart
  bool get isRateInverse {
    return source.currency != target.currency &&
        utilsService.convertCurrencies(1, source.currency, target.currency) < 1;
  }

  double get conversionRate {
    if (rawConversionRate == 0) return 0;
    return isRateInverse ? 1 / rawConversionRate : rawConversionRate;
  }
```

Note: `isRateInverse` reads `source`/`target` (`late Account`). It is only evaluated where those are already assigned — inside `buildConversionRateSection` (built after accounts load) and inside `fillFormDataWithMovement` (after `source`/`target` are set in the same `setState`).

- [ ] **Step 2: Change the controller to precision 2, default 0**

Replace:

```dart
  final conversionRateInputController = MoneyMaskedTextController(decimalSeparator: ',', thousandSeparator: '.', precision: 6, initialValue: 1);
```

with:

```dart
  final conversionRateInputController = MoneyMaskedTextController(decimalSeparator: ',', thousandSeparator: '.', precision: 2, initialValue: 0);
```

- [ ] **Step 3: Update `fillFormDataWithMovement` (edit path)**

Replace these two lines inside `fillFormDataWithMovement`:

```dart
      conversionRate = movement.conversionRate ?? 1;
      conversionRateInputController.text = conversionRate.toStringAsFixed(6);
```

with:

```dart
      var storedRate = movement.conversionRate ?? 1;
      rawConversionRate = isRateInverse ? 1 / storedRate : storedRate;
      conversionRateInputController.text = rawConversionRate.toStringAsFixed(2);
```

For non-cross-currency movements `storedRate` is `1` and `isRateInverse` is `false` (same currency), so `rawConversionRate` stays `1`; the section is not shown, so the value is unused.

- [ ] **Step 4: Update `buildConversionRateSection` — parse to raw value and dynamic label**

In `buildConversionRateSection`, change the `onChanged` assignment from:

```dart
              if (double.tryParse(value) != null) {
                conversionRate = double.tryParse(value)! / 1000000;
              }
```

to:

```dart
              if (double.tryParse(value) != null) {
                rawConversionRate = double.tryParse(value)! / 100;
              }
```

Then replace the `decoration` (currently `const InputDecoration(...)` with a static `'Tasa de conversión '` prefix and `'x'` suffix) with a non-const one whose prefix/suffix depend on `isRateInverse`:

```dart
          decoration: InputDecoration(
            border: InputBorder.none,
            prefix: Text(
              isRateInverse ? 'Tasa de conversión 1 ÷ ' : 'Tasa de conversión ',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            suffix: isRateInverse
                ? null
                : const Text('x', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            errorStyle: const TextStyle(height: 0, fontSize: 0),
          ),
```

Leave the `validator` unchanged (it already rejects empty / non-parseable / zero) and leave the "Recibís …" preview line unchanged (it uses `amount * conversionRate`, and `conversionRate` is now the getter).

- [ ] **Step 5: Run static analysis**

Run: `flutter analyze`
Expected: no new errors or warnings introduced by the change (the file compiles; `conversionRate` is now a getter and every reference — `submit`, the preview `Text`, `fillFormDataWithMovement` — resolves).

- [ ] **Step 6: Update `docs/features/movements.md`**

In the "Edge cases" list, replace the "Currency conversion on transfer" bullet:

```markdown
- **Currency conversion on transfer** — when `source.currency != target.currency`, the dialog
  shows a conversion-rate field, `conversionRate` is stored, and the target is credited
  `amount * conversionRate`; the source is debited `amount`
  ([movements.repository.dart:146-161](../../lib/repositories/movements.repository.dart#L146-L161)).
```

with:

```markdown
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
```

- [ ] **Step 7: Update `docs/features/currency.md`**

Append a sentence to the `convertCurrencies` bullet (currently ending "Used for balances and totals, which are always valued at today's rates."):

```markdown
- `convertCurrencies(amount, from, to)` — returns `amount` when `from == to`, otherwise applies
  the current (live) mapping ([:120-129](../../lib/services/utils.service.dart#L120-L129)). Used
  for balances and totals, which are always valued at today's rates. The new/edit movement dialog
  also uses it to choose the conversion-rate input direction: when
  `convertCurrencies(1, source, target) < 1` the target currency is stronger, so the rate is
  entered inverted as `1 ÷ X` (see [movements.md](movements.md)).
```

- [ ] **Step 8: Manual verification in the running app**

Run: `flutter run`

Verify each of these:
- New TRANSFER, source USD → target ARS (destination weaker): label reads `Tasa de conversión … x`, entering `1485,23` credits the target `amount × 1485,23` (check the "Recibís" line).
- New TRANSFER, source ARS → target USD (destination stronger): label reads `Tasa de conversión 1 ÷ …`, entering `1485,23` credits the target `amount ÷ 1485,23` ("Recibís" ≈ `amount / 1485.23`).
- Switching source/target so the direction flips updates the label and the "Recibís" preview without retyping.
- The rate field starts at `0,00` and the Crear button stays disabled until a non-zero rate is entered.
- Edit an existing ARS → USD transfer: the field shows the inverse value (≈ `1485,23`), not the tiny stored rate; saving without changes keeps the same effective `conversionRate`.

- [ ] **Step 9: Commit**

```bash
git add lib/views/movements/new_movement.dialog.dart docs/features/movements.md docs/features/currency.md
git commit -m "$(cat <<'EOF'
Enter conversion rate in the >=1 direction (1 / X for stronger target)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:**
- General rule by currency strength → `isRateInverse` (Step 1). ✓
- Direction via live rate `convertCurrencies(1, source, target) < 1` → Step 1. ✓
- Precision 2 → Step 2. ✓
- Default 0 to force manual entry → Steps 2 & (validator unchanged) 4. ✓
- Single source of truth (raw value + derived `conversionRate`) → Step 1. ✓
- Dynamic label `1 ÷ X` vs `X x` → Step 4. ✓
- Edit path re-derives displayed value → Step 3. ✓
- No persistence change → no model/repo/migration task. ✓
- Docs updated same commit → Steps 6–7, committed in Step 9. ✓
- Edge cases (rates unloaded, empty/zero, USD↔EUR) → handled by `isRateInverse` fallback and unchanged validator; documented in the spec. ✓

**Placeholder scan:** none — every step has concrete before/after code.

**Type consistency:** `conversionRate` used as a `double` everywhere (was a field, now a getter — same type, same call sites: `submit` → `create(..., conversionRate, ...)`, preview `amount * conversionRate`). `rawConversionRate` is a `double`. `isRateInverse` returns `bool`. Consistent across steps.
