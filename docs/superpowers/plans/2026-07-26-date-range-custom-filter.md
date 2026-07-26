# Custom Date Range Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar las opciones de período de "Gastos por categoría" por `Este mes` / `Mes pasado` / `1 mes` / `Custom`, donde `Custom` abre un diálogo genérico y reutilizable de selección de rango de fechas.

**Architecture:** Un nuevo widget genérico `DateRangeSelectorDialog` (en `views/generics/`) devuelve un `DateTimeRange?` vía `showDialog`. El repositorio `getExpensesByCategory` gana un parámetro `endDate` para acotar el límite superior. La vista `expenses_by_category.dart` mapea cada opción de período a un par (startDate, endDate) y, para `Custom`, guarda el rango elegido en un campo de estado.

**Tech Stack:** Flutter / Dart, `sqflite`, `get_it`, `intl` (`DateFormat`), `CupertinoDatePicker` en `showCupertinoModalPopup`.

## Global Constraints

- **Idioma:** identificadores, código, logs y nombres de archivo en inglés; textos de UI en español (`es_AR`). Chat en español.
- **Sin tests:** el proyecto no tiene tests por política. Verificación = `flutter analyze` sin issues + comprobación manual con `flutter run`. No crear archivos de test.
- **Git:** nunca commitear a `master`. Trabajar en la rama `feature/date-range-custom-filter` (ya creada). Agregar co-autor en cada commit: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Copy exacto de las opciones:** `Este mes`, `Mes pasado`, `1 mes`, `Custom` (nótese `Este`, sin tilde en la "E", corrigiendo el `Éste` actual).
- **Botón Custom:** siempre muestra el texto "Custom"; queda resaltado cuando `selectedPeriod == 'custom'`.
- **Cancelar el diálogo de rango** no altera la selección actual.
- **Docs-in-sync:** actualizar `docs/ui-patterns.md` y `docs/features/statistics.md` en el mismo cambio.
- **No inventar patrones:** seguir el shell de diálogo de `new_account.dialog.dart` y el patrón de date picker en bottom sheet de `new_movement.dialog.dart`.

---

### Task 1: Diálogo genérico `DateRangeSelectorDialog`

**Files:**
- Create: `lib/views/generics/date_range_selector.dialog.dart`

**Interfaces:**
- Consumes: nada (widget autónomo, sin dependencias de estadísticas).
- Produces: widget `DateRangeSelectorDialog`, invocable con
  ```dart
  showDialog<DateTimeRange>(
    context: context,
    builder: (_) => DateRangeSelectorDialog({
      DateTimeRange? initialRange,   // default: 1° del mes actual → ahora
      DateTime? firstDate,           // límite inferior seleccionable (opcional)
      DateTime? lastDate,            // límite superior seleccionable (opcional)
      String title = 'Seleccionar rango',
    }),
  )
  ```
  Devuelve `Future<DateTimeRange?>`: el rango elegido (`start` a las 00:00:00, `end` a las 23:59:59) al aplicar, o `null` al cancelar.

- [ ] **Step 1: Crear el archivo con el widget completo**

Crear `lib/views/generics/date_range_selector.dialog.dart` con este contenido exacto:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRangeSelectorDialog extends StatefulWidget {
  final DateTimeRange? initialRange;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String title;

  const DateRangeSelectorDialog({
    super.key,
    this.initialRange,
    this.firstDate,
    this.lastDate,
    this.title = 'Seleccionar rango',
  });

  @override
  State<DateRangeSelectorDialog> createState() => _DateRangeSelectorDialogState();
}

class _DateRangeSelectorDialogState extends State<DateRangeSelectorDialog> {
  late DateTime fromDate;
  late DateTime toDate;

  @override
  void initState() {
    super.initState();
    var now = DateTime.now();
    fromDate = widget.initialRange?.start ?? DateTime(now.year, now.month);
    toDate = widget.initialRange?.end ?? now;
  }

  DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);
  DateTime endOfDay(DateTime date) => DateTime(date.year, date.month, date.day, 23, 59, 59);

  bool get canSubmit {
    return !startOfDay(toDate).isBefore(startOfDay(fromDate));
  }

  void submit() {
    Navigator.of(context).pop(DateTimeRange(start: startOfDay(fromDate), end: endOfDay(toDate)));
  }

  void showDatePicker(DateTime initial, void Function(DateTime) onChanged) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: initial,
            minimumDate: widget.firstDate,
            maximumDate: widget.lastDate,
            onDateTimeChanged: onChanged,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
        child: Column(
          children: [
            buildTitle(context),
            const SizedBox(height: 20),
            buildDateRow(context, 'Desde', fromDate, (date) => setState(() => fromDate = date)),
            const SizedBox(height: 10),
            buildDateRow(context, 'Hasta', toDate, (date) => setState(() => toDate = date)),
            const SizedBox(height: 20),
            buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget buildTitle(BuildContext context) {
    return Text(widget.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold));
  }

  Widget buildDateRow(BuildContext context, String label, DateTime value, void Function(DateTime) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 18)),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => showDatePicker(value, onChanged),
          child: Text(DateFormat('dd/MM/yyyy').format(value), style: const TextStyle(fontSize: 20)),
        ),
      ],
    );
  }

  Widget buildActionButtons(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          style: ButtonStyle(fixedSize: WidgetStateProperty.all(const Size(120, 30))),
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: canSubmit ? Theme.of(context).primaryColor : Theme.of(context).disabledColor,
            foregroundColor: Colors.white,
            fixedSize: const Size(120, 30),
          ),
          onPressed: canSubmit ? submit : null,
          child: const Text('Aplicar', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verificar análisis estático**

Run: `flutter analyze lib/views/generics/date_range_selector.dialog.dart`
Expected: "No issues found!" (o sin issues nuevos para ese archivo).

- [ ] **Step 3: Commit**

```bash
git add lib/views/generics/date_range_selector.dialog.dart
git commit -m "Add generic DateRangeSelectorDialog widget

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Agregar `endDate` a `getExpensesByCategory`

**Files:**
- Modify: `lib/repositories/movements.repository.dart:177-206`
- Modify: `lib/views/statistics/expenses_by_category.dart:59` (puente temporal para que compile)

**Interfaces:**
- Consumes: nada.
- Produces: nueva firma
  ```dart
  Future<List<Map<String, Object?>>> getExpensesByCategory(
      Account? account, MovementType? movementType,
      DateTime? startDate, DateTime? endDate, Currency displayCurrency)
  ```
  El filtro superior es `creationDate <= endDate.toString()` cuando `endDate != null`.

- [ ] **Step 1: Modificar la firma y agregar el filtro superior**

En [movements.repository.dart:177-188](../../../lib/repositories/movements.repository.dart#L177-L188), cambiar la firma y agregar el bloque `endDate` justo después del bloque `startDate`:

```dart
Future<List<Map<String, Object?>>> getExpensesByCategory(Account? account, MovementType? movementType, DateTime? startDate, DateTime? endDate, Currency displayCurrency) async {
  var where = 'type = ?';
  List<Object?> whereArgs = [movementType!.name];
  if (account != null) {
    where += ' AND (sourceId = ? OR targetId = ?)';
    whereArgs.add(account.id);
    whereArgs.add(account.id);
  }
  if (startDate != null) {
    where += ' AND creationDate >= ?';
    whereArgs.add(startDate.toString());
  }
  if (endDate != null) {
    where += ' AND creationDate <= ?';
    whereArgs.add(endDate.toString());
  }
  var movements = await find(where: where, args: whereArgs);
```

(El resto del método `fold` no cambia.)

- [ ] **Step 2: Puente temporal en el único caller para que compile**

En [expenses_by_category.dart:59](../../../lib/views/statistics/expenses_by_category.dart#L59), agregar `null` como argumento `endDate` (se reemplaza por la lógica real en Task 3):

```dart
var result = await databaseService.movementsRepository.getExpensesByCategory(widget.account, selectedMovementType, startDate, null, displayCurrency);
```

- [ ] **Step 3: Verificar análisis estático**

Run: `flutter analyze`
Expected: "No issues found!" (no debe haber errores de aridad en la llamada).

- [ ] **Step 4: Commit**

```bash
git add lib/repositories/movements.repository.dart lib/views/statistics/expenses_by_category.dart
git commit -m "Add optional endDate upper bound to getExpensesByCategory

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Nuevas opciones de período y flujo Custom en la vista

**Files:**
- Modify: `lib/views/statistics/expenses_by_category.dart`

**Interfaces:**
- Consumes: `DateRangeSelectorDialog` (Task 1) y `getExpensesByCategory(..., endDate, ...)` (Task 2).
- Produces: nada para tareas posteriores.

- [ ] **Step 1: Agregar el import del diálogo genérico**

En la lista de imports de [expenses_by_category.dart](../../../lib/views/statistics/expenses_by_category.dart#L1-L10), agregar (respetando orden alfabético entre los `package:money/views/generics/...`):

```dart
import 'package:money/views/generics/date_range_selector.dialog.dart';
```

- [ ] **Step 2: Agregar el campo de estado `customRange`**

Debajo de `String? selectedPeriod = 'this-month';` ([expenses_by_category.dart:24](../../../lib/views/statistics/expenses_by_category.dart#L24)), agregar:

```dart
DateTimeRange? customRange;
```

- [ ] **Step 3: Reescribir el cálculo de fechas en `getExpensesByCategory()`**

Reemplazar el cuerpo de [getExpensesByCategory()](../../../lib/views/statistics/expenses_by_category.dart#L50-L65) por:

```dart
void getExpensesByCategory() async {
  DateTime? startDate;
  DateTime? endDate;
  var now = DateTime.now();
  if (selectedPeriod == 'this-month') {
    startDate = DateTime(now.year, now.month);
  } else if (selectedPeriod == 'last-month') {
    startDate = DateTime(now.year, now.month - 1);
    endDate = DateTime(now.year, now.month).subtract(const Duration(seconds: 1));
  } else if (selectedPeriod == 'month') {
    startDate = now.subtract(const Duration(days: 30));
  } else if (selectedPeriod == 'custom') {
    startDate = customRange?.start;
    endDate = customRange?.end;
  }
  var result = await databaseService.movementsRepository.getExpensesByCategory(widget.account, selectedMovementType, startDate, endDate, displayCurrency);
  if (!mounted) return;
  result.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
  setState(() {
    expensesByCategory = result;
  });
}
```

- [ ] **Step 4: Reescribir `buildPeriodSelect` y agregar `selectCustomRange`**

Reemplazar [buildPeriodSelect()](../../../lib/views/statistics/expenses_by_category.dart#L95-L108) por:

```dart
Widget buildPeriodSelect(BuildContext context) {
  var options = ['this-month', 'last-month', 'month', 'custom'];
  var optionNames = ['Este mes', 'Mes pasado', '1 mes', 'Custom'];
  return ButtonSelector(
    options: optionNames.map((e) => Text(e)).toList(),
    selectedIndex: options.indexOf(selectedPeriod),
    onSelectionChange: (index) {
      var option = options[index];
      if (option == 'custom') {
        selectCustomRange();
      } else {
        setState(() {
          selectedPeriod = option;
          getExpensesByCategory();
        });
      }
    },
  );
}

void selectCustomRange() async {
  var range = await showDialog<DateTimeRange>(
    context: context,
    builder: (context) => DateRangeSelectorDialog(
      initialRange: customRange,
      lastDate: DateTime.now(),
    ),
  );
  if (range == null || !mounted) return;
  setState(() {
    selectedPeriod = 'custom';
    customRange = range;
    getExpensesByCategory();
  });
}
```

- [ ] **Step 5: Verificar análisis estático**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Verificación manual**

Run: `flutter run`
Verificar en la pantalla de Estadísticas → "Gastos por categoría":
- Se ven exactamente los botones `Este mes`, `Mes pasado`, `1 mes`, `Custom`.
- `Mes pasado` muestra solo datos del mes calendario anterior.
- Tocar `Custom` abre el diálogo; al aplicar un rango, el gráfico se actualiza y `Custom` queda resaltado.
- Cancelar el diálogo deja la selección como estaba.
- En el diálogo, "Aplicar" se deshabilita si "Hasta" es anterior a "Desde".

- [ ] **Step 7: Commit**

```bash
git add lib/views/statistics/expenses_by_category.dart
git commit -m "Use Este mes / Mes pasado / 1 mes / Custom period options in expenses-by-category

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Actualizar documentación

**Files:**
- Modify: `docs/ui-patterns.md`
- Modify: `docs/features/statistics.md`

**Interfaces:**
- Consumes: nada.
- Produces: nada.

- [ ] **Step 1: Documentar el diálogo genérico en `ui-patterns.md`**

En [docs/ui-patterns.md](../../ui-patterns.md), dentro de la sección "Component choice", agregar un bullet nuevo al final de la lista:

```markdown
- **Selección de rango de fechas** → el diálogo genérico `DateRangeSelectorDialog`
  ([date_range_selector.dialog.dart](../lib/views/generics/date_range_selector.dialog.dart)):
  se abre con `showDialog<DateTimeRange>` y devuelve un `DateTimeRange?` (`null` al cancelar).
  Recibe `initialRange`, `firstDate`, `lastDate` y `title`; internamente "Desde" queda a las
  00:00:00 y "Hasta" a las 23:59:59. Usa el mismo `CupertinoDatePicker` en bottom sheet de
  216px que el input de fecha de un movimiento.
```

- [ ] **Step 2: Actualizar `statistics.md` — firma del método**

En [docs/features/statistics.md:18-23](../../features/statistics.md#L18-L23), actualizar la descripción de `getExpensesByCategory` y la nota de filtrado:

- Cambiar la firma a `getExpensesByCategory(account, movementType, startDate, endDate, displayCurrency)`.
- Cambiar la frase "Both filter by type, optionally by account, and optionally from a start date." por: "`getExpensesByDay` filtra por tipo, opcionalmente por cuenta y opcionalmente desde una fecha de inicio; `getExpensesByCategory` además acepta una fecha de fin (`endDate`) para acotar el rango por arriba."

- [ ] **Step 3: Actualizar `statistics.md` — bullet de "Period options"**

En [docs/features/statistics.md:56-57](../../features/statistics.md#L56-L57), reemplazar el bullet por:

```markdown
- **Period options** — category chart: `this-month` / `last-month` / `month` / `custom` (el
  botón `custom` abre `DateRangeSelectorDialog` y guarda el rango elegido en `customRange`); day
  chart: `week` / `month` / `year` / all.
```

- [ ] **Step 4: Verificar consistencia**

Revisar visualmente que los links relativos en los docs resuelven y que no quedó ninguna mención a las opciones viejas (`1 año` / `Todos`) en la descripción del gráfico de categoría.

- [ ] **Step 5: Commit**

```bash
git add docs/ui-patterns.md docs/features/statistics.md
git commit -m "Document DateRangeSelectorDialog and updated category period options

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage:**
- Diálogo genérico parametrizable → Task 1. ✓
- `endDate` en el repo → Task 2. ✓
- Nuevas opciones + copy "Este mes/Mes pasado/1 mes/Custom" → Task 3, Step 4. ✓
- Semántica de calendario (this-month / last-month / month / custom) → Task 3, Step 3. ✓
- Botón Custom siempre "Custom" y resaltado → Task 3 (label fijo + `indexOf` resalta cuando `selectedPeriod=='custom'`). ✓
- Cancelar no cambia la selección → Task 3, `selectCustomRange` (return temprano si `range == null`). ✓
- "Aplicar" deshabilitado si Hasta < Desde → Task 1, `canSubmit`. ✓
- Docs (ui-patterns + statistics) → Task 4. ✓

**2. Placeholder scan:** El `null` de Task 2 Step 2 es un puente intencional reemplazado en Task 3 Step 3, no un placeholder pendiente. No hay TODOs ni "handle edge cases" sin código.

**3. Type consistency:** `DateRangeSelectorDialog(initialRange, firstDate, lastDate, title)` y `DateTimeRange?` de retorno coinciden entre Task 1 y su uso en Task 3. La firma `getExpensesByCategory(..., DateTime? endDate, ...)` coincide entre Task 2 (definición) y Task 3 Step 3 (uso). `customRange` (`DateTimeRange?`) coincide entre Steps 2, 3 y 4 de Task 3.
