# Filtro de rango de fechas custom para "Gastos por categoría"

Fecha: 2026-07-26

## Objetivo

Actualizar el filtro de período del gráfico "Gastos por categoría" cambiando las opciones
actuales (`Este mes` / `1 mes` / `1 año` / `Todos`) por `Este mes` / `Mes pasado` / `1 mes` /
`Custom`. Al tocar `Custom` se abre un diálogo para elegir fecha "desde" y fecha "hasta"; al
aplicar, la selección queda en `Custom` y el gráfico se actualiza con ese rango.

Además, se construye un **diálogo genérico y parametrizable de selección de rango de fechas**
(`DateRangeSelectorDialog`) para poder reutilizarlo en el futuro en otras pantallas.

## Contexto actual

- El selector de período vive en `buildPeriodSelect`
  ([expenses_by_category.dart:95-108](../../../lib/views/statistics/expenses_by_category.dart#L95-L108)):
  dos listas inline paralelas (`['this-month', 'month', 'year', null]` y
  `['Éste mes', '1 mes', '1 año', 'Todos']`) renderizadas con `ButtonSelector`.
  `selectedPeriod` es un `String?` (`null` = "Todos").
- El cálculo de fechas es inline en `getExpensesByCategory()`
  ([expenses_by_category.dart:50-65](../../../lib/views/statistics/expenses_by_category.dart#L50-L65))
  y solo produce un `startDate`; **no existe fecha de fin**.
- La query
  ([getExpensesByCategory](../../../lib/repositories/movements.repository.dart#L177-L206))
  filtra únicamente `creationDate >= startDate`. No hay límite superior.
- No existe un shell genérico de diálogo: cada diálogo se arma a mano siguiendo
  [new_account.dialog.dart](../../../lib/views/accounts/new_account.dialog.dart).
- El único precedente de date picker es un `CupertinoDatePicker` dentro de un
  `showCupertinoModalPopup` (bottom sheet de 216px) en
  [new_movement.dialog.dart:387-407](../../../lib/views/movements/new_movement.dialog.dart#L387-L407).

## Alcance

Dentro de alcance:

- Diálogo genérico `DateRangeSelectorDialog`.
- `getExpensesByCategory` (agregar `endDate`).
- Vista `expenses_by_category.dart` (nuevas opciones + rango custom).
- Docs: `ui-patterns.md` y `features/statistics.md`.

Fuera de alcance:

- El gráfico hermano `expenses_by_day.dart` y su método `getExpensesByDay` no se tocan.
- No se modifican modelos ni migraciones.

## Diseño

### 1. Diálogo genérico de rango de fechas

Nuevo widget en `lib/views/generics/date_range_selector.dialog.dart`, clase
`DateRangeSelectorDialog` (nombre elegido para no chocar con el `DateRangePickerDialog` de
Material).

API:

```dart
DateRangeSelectorDialog({
  DateTimeRange? initialRange,   // precarga; si null → mes actual (1° → hoy)
  DateTime? firstDate,           // límite inferior seleccionable (opcional)
  DateTime? lastDate,            // límite superior seleccionable (opcional)
  String title = 'Seleccionar rango',
})
```

- Devuelve un `DateTimeRange?` vía `Navigator.pop` (`null` si se cancela).
- Sigue el shell de diálogo estándar
  (`Dialog → Column → [buildTitle, contenido, buildActionButtons]`) como
  [new_account.dialog.dart](../../../lib/views/accounts/new_account.dialog.dart).
- Dos campos "Desde" y "Hasta": cada uno es un `CupertinoButton` que abre un
  `CupertinoDatePicker` (`mode: CupertinoDatePickerMode.date`) en el bottom sheet de 216px,
  reutilizando el patrón de
  [new_movement.dialog.dart:387-407](../../../lib/views/movements/new_movement.dialog.dart#L387-L407).
- Solo fecha: internamente "Desde" queda a las `00:00:00` y "Hasta" a las `23:59:59` del día
  elegido, para que el rango sea inclusivo.
- Al abrir sin `initialRange`, se precargan el 1° del mes actual (desde) y hoy (hasta).
- Botones de acción: **Cancelar** (`pop(null)`) y **Aplicar** (`pop(rango)`). "Aplicar" se
  deshabilita cuando "Hasta" < "Desde" (patrón `canSubmit` de la guía de UI).

### 2. Cambio en el repositorio

En [getExpensesByCategory](../../../lib/repositories/movements.repository.dart#L177-L206) se
agrega un parámetro opcional `endDate`:

```dart
Future<List<Map<String, Object?>>> getExpensesByCategory(
    Account? account, MovementType? movementType,
    DateTime? startDate, DateTime? endDate, Currency displayCurrency) async {
  ...
  if (startDate != null) { where += ' AND creationDate >= ?'; whereArgs.add(startDate.toString()); }
  if (endDate != null)   { where += ' AND creationDate <= ?'; whereArgs.add(endDate.toString()); }
  ...
}
```

- El filtro superior es simétrico al inferior existente. La comparación como string es válida
  porque `creationDate` se guarda con `DateTime.toString()` (formato ISO
  `YYYY-MM-DD HH:MM:SS.mmm`), que ordena lexicográficamente igual que cronológicamente.
- El único caller de `getExpensesByCategory` es `expenses_by_category.dart`, así que solo se
  actualiza esa llamada.

### 3. Cambios en la vista `expenses_by_category.dart`

Estado:

- `selectedPeriod` sigue siendo `String?` (se respeta el patrón del archivo), con valores
  `'this-month'`, `'last-month'`, `'month'`, `'custom'`. Default `'this-month'`.
- Nuevo campo `DateTimeRange? customRange;` para guardar el rango elegido.

Selector (`buildPeriodSelect`):

```dart
var options = ['this-month', 'last-month', 'month', 'custom'];
var optionNames = ['Este mes', 'Mes pasado', '1 mes', 'Custom'];  // se corrige "Éste" → "Este"
```

El botón de `Custom` siempre muestra el texto "Custom" y queda resaltado cuando
`selectedPeriod == 'custom'`.

`onSelectionChange`:

- Si la opción es `'custom'` → abre `DateRangeSelectorDialog`
  (`initialRange: customRange`, `lastDate: DateTime.now()`):
  - Devuelve un rango → `selectedPeriod = 'custom'`, `customRange = rango`, recargar.
  - Devuelve `null` (cancelar) → **no cambia nada**: se mantiene el `selectedPeriod` actual
    (y su `customRange` si ya había), sin recargar. Esto hace natural el caso de re-editar un
    rango custom y cancelar.
- Cualquier otra opción → `selectedPeriod = valor`, recargar.

Cálculo de fechas en `getExpensesByCategory()` (ahora produce inicio **y** fin):

| Opción       | startDate                          | endDate                                                        |
|--------------|------------------------------------|----------------------------------------------------------------|
| `this-month` | `DateTime(now.year, now.month)`    | `null` (hasta ahora)                                           |
| `last-month` | `DateTime(now.year, now.month - 1)`| `DateTime(now.year, now.month).subtract(Duration(seconds: 1))` |
| `month`      | `now - 30 días`                    | `null`                                                         |
| `custom`     | `customRange.start` (00:00)        | `customRange.end` (23:59:59)                                   |

Dart normaliza `now.month - 1 == 0` a diciembre del año anterior, así que "Mes pasado"
funciona correctamente en enero.

La llamada al repositorio se actualiza para pasar `endDate`.

### 4. Documentación

Por la regla de docs-in-sync:

- [docs/ui-patterns.md](../../ui-patterns.md) → en "Component choice", agregar una entrada para
  el diálogo genérico de rango de fechas (`DateRangeSelectorDialog`), su propósito y API, junto
  al patrón de date picker en bottom sheet.
- [docs/features/statistics.md](../../features/statistics.md) → actualizar la firma de
  `getExpensesByCategory` (nuevo `endDate`), la nota "optionally from a start date" (ahora
  también fecha de fin) y el bullet "Period options" (nuevas opciones del gráfico de categoría:
  `this-month` / `last-month` / `month` / `custom`).

## Criterios de aceptación

1. El selector de "Gastos por categoría" muestra exactamente: `Este mes`, `Mes pasado`,
   `1 mes`, `Custom`.
2. `Este mes` filtra desde el 1° del mes actual hasta ahora.
3. `Mes pasado` filtra el mes calendario anterior completo (1° al último instante del mes
   anterior).
4. `1 mes` filtra los últimos 30 días.
5. Tocar `Custom` abre `DateRangeSelectorDialog`; al aplicar un rango, el gráfico se actualiza
   y el botón queda marcado como `Custom`.
6. Cancelar el diálogo de rango no altera la selección actual.
7. En el diálogo, "Aplicar" está deshabilitado si "Hasta" es anterior a "Desde".
8. `DateRangeSelectorDialog` es genérico y no tiene dependencias con estadísticas ni con
   `expenses_by_category`.
