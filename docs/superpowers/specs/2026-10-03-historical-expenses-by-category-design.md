# Gráfico "Gastos por categoría históricos"

Fecha: 2026-10-03

## Objetivo

Agregar a la sección de Estadísticas un tercer tipo de gráfico, **"Gastos por categoría
históricos"**, que muestra cómo evoluciona en el tiempo el gasto de cada categoría: un gráfico de
líneas (eje horizontal = fecha, eje vertical = gasto) con una línea por categoría, más una lista
de categorías que permite habilitar/deshabilitar cada línea.

Orden de la vista, de arriba a abajo:

1. Selector de moneda (`CurrencySelector`).
2. Selector de período: `3 meses` / `6 meses` / `1 año` / `Custom`.
3. Gráfico de líneas.
4. Botones "habilitar todas" / "deshabilitar todas".
5. Lista de categorías con su color, sin montos.

## Contexto actual

- [statistics.dart](../../../lib/views/statistics/statistics.dart) tiene un selector de cuenta y
  un selector de tipo de gráfico (`Ninguno` / `Gastos por categoría` / `Gastos por día`); cada
  gráfico es un widget que recibe `Account? account`.
- [expenses_by_category.dart](../../../lib/views/statistics/expenses_by_category.dart) es el
  gráfico hermano: `ButtonSelector` para el período (con `Custom` →
  `DateRangeSelectorDialog`), colores generados con `Random(colorSeed)` (`colorSeed = 134`) sobre
  la lista ordenada por total descendente, y una tabla con el círculo de color y el nombre.
- [expenses_by_day.dart](../../../lib/views/statistics/expenses_by_day.dart) ya usa `fl_chart`
  (`BarChart`) con títulos de ejes compactos (`k` / `M`) y la convención de grilla/bordes grises.
- [getExpensesByCategory](../../../lib/repositories/movements.repository.dart#L177-L206)
  agrega por categoría convirtiendo cada movimiento con `convertCurrenciesAt` (tasa vigente en
  la `creationDate` del movimiento). No existe una agregación por categoría **y** por día.
- [CurrencySelector](../../../lib/views/generics/currency_selector.dart) ya existe como widget
  genérico (`selected` + `onSelectionChange`).

## Alcance

Dentro de alcance:

- Nuevo método de repositorio `getExpensesByCategoryByDay`.
- Nueva vista `historical_expenses_by_category.dart`.
- Nueva opción en el selector de tipo de gráfico de `statistics.dart`.
- Docs: `features/statistics.md`, `data-layer.md` (patrón de resultados tipados) y
  `tech-debt.md` (los dos métodos existentes que siguen devolviendo mapas).

Fuera de alcance:

- No se tocan modelos, migraciones, el dashboard ni los otros dos gráficos.
- No hay selector de tipo de movimiento: el gráfico es solo de **gastos** (`REMOVE`).
- No hay suavizado, zoom ni agrupación configurable del eje X.

## Diseño

### 1. Repositorio

Nuevo método en `MovementsRepository`, junto a `getExpensesByCategory`:

```dart
Future<List<CategoryDailyExpenses>> getExpensesByCategoryByDay(
    Account? account, DateTime startDate, DateTime endDate, Currency displayCurrency)
```

El resultado es una clase propia, no un mapa genérico (patrón "Typed query results" de
[data-layer.md](../../data-layer.md)). Se declara en `movements.repository.dart`, encima de
`MovementsRepository`; es simple e inmutable y no extiende `BaseModel` (no tiene id ni tabla):

```dart
class CategoryDailyExpenses {
  final String category;
  final List<double> dailyTotals;

  const CategoryDailyExpenses({ required this.category, required this.dailyTotals });

  double get total => dailyTotals.fold<double>(0, (sum, value) => sum + value);
}
```

- Filtra `type = REMOVE`, opcionalmente por cuenta (`sourceId = ? OR targetId = ?`), y por
  rango de días calendario: `creationDate >= medianoche(startDate)` y
  `creationDate < medianoche(día siguiente a endDate)`. El límite superior es **exclusivo** sobre
  el día siguiente, así el último día entra completo sin depender de milisegundos.
  La comparación es de texto, así que los parámetros deben tener el **mismo formato** que lo
  guardado: `creationDate` se persiste con `toIso8601String()` (separador `T`), por lo que el
  método nuevo pasa `toIso8601String()`. Las consultas existentes pasan `toString()` (separador
  espacio); como `'T'` (0x54) es mayor que `' '` (0x20), con `<= endDate` dejan afuera los
  movimientos del propio día de fin (ej. `2026-10-03T10:00:00.000 <= 2026-10-03 23:59:59.000` es
  falso). Ese defecto existente queda fuera de alcance de esta feature y se registra en
  `docs/tech-debt.md`.
- Convierte cada movimiento con `utilsService.convertCurrenciesAt(amount, source.currency,
  displayCurrency, creationDate)`, igual que los otros métodos.
- Agrupa **primero por categoría y luego por día**, porque el gráfico y la lista consumen una
  serie por categoría. Devuelve un `CategoryDailyExpenses` por categoría con gasto en el
  período.
- `dailyTotals` tiene siempre el mismo largo para todas las categorías: un valor por cada día
  calendario entre `startDate` y `endDate` (ambos inclusive), con `0.0` en los días sin gasto.
  Su largo es `dayIndex(startDate, endDate) + 1`.
- **Día de un movimiento.** `creationDate` se guarda con `toIso8601String()` de un `DateTime`
  local (sin zona horaria) y se lee con `DateTime.tryParse`, que lo interpreta como local. El
  día de un movimiento es el de su hora de pared local: se toman `year` / `month` / `day` del
  valor local y se descarta la hora. **Nunca** se llama `toUtc()` sobre `creationDate` (un
  movimiento de las 22:00 en UTC-3 cambiaría de día).
- **Índice de día.** Vive en `UtilsService.dayIndex(startDate, date)` (lo usan el repositorio y la
  vista). El índice de un día respecto de `startDate` es la cantidad de días
  calendario entre ambos. Se calcula con componentes locales y `DateTime.utc` solo como
  herramienta para contar: la diferencia entre dos fechas UTC siempre es un múltiplo exacto de
  24 h, mientras que entre fechas locales un cambio de horario de verano puede dar 23 o 25 h y
  `inDays` perder un día.

  ```dart
  int dayIndex(DateTime startDate, DateTime date) =>
      DateTime.utc(date.year, date.month, date.day)
          .difference(DateTime.utc(startDate.year, startDate.month, startDate.day))
          .inDays;
  ```
- No ordena: la vista ordena por `total` (getter de la clase) de mayor a menor, como hace hoy
  "Gastos por categoría".
- `startDate` y `endDate` son obligatorios (el período siempre está acotado).
- No se extrae lógica compartida con `getExpensesByCategory` / `getExpensesByDay`: el método es
  independiente, como los otros dos.

### 2. Vista `HistoricalExpensesByCategoryChart`

Nuevo archivo `lib/views/statistics/historical_expenses_by_category.dart`, `StatefulWidget` con
`final Account? account` (mismo contrato que los otros gráficos).

Estado:

- `Currency selectedCurrency` — inicial: `widget.account?.currency ?? Currency.USD`.
- `String selectedPeriod` — valores `'3-months'`, `'6-months'`, `'1-year'`, `'custom'`; default
  `'3-months'`.
- `DateTimeRange? customRange`.
- `List<CategoryDailyExpenses>? rows` — resultado del repositorio (`null` = cargando).
- `Set<String> disabledCategories` — categorías deshabilitadas (vacío = todas activas).
- `int? selectedDayIndex` — índice del día marcado en el gráfico (`null` = ninguno).
- `final colorSeed = 134`.

Fechas del período (getters separados, convención del proyecto):

| Opción     | `selectedPeriodStartDate`                     | `selectedPeriodEndDate`     |
|------------|-----------------------------------------------|-----------------------------|
| `3-months` | `DateTime(now.year, now.month - 3, now.day)`  | hoy a las 23:59:59          |
| `6-months` | `DateTime(now.year, now.month - 6, now.day)`  | hoy a las 23:59:59          |
| `1-year`   | `DateTime(now.year - 1, now.month, now.day)`  | hoy a las 23:59:59          |
| `custom`   | `customRange.start` (00:00)                   | `customRange.end` (23:59:59)|

El botón `Custom` abre `DateRangeSelectorDialog` (`initialRange: customRange`,
`lastDate: DateTime.now()`); si se cancela no cambia nada, igual que en "Gastos por categoría".
Cambiar moneda, período o cuenta vuelve a consultar el repositorio. En `didUpdateWidget`, si
cambia la cuenta, `selectedCurrency` pasa a `widget.account?.currency ?? Currency.USD`; el
período, `customRange` y `disabledCategories` no se tocan. Cada nueva consulta limpia
`selectedDayIndex`.

Cálculos derivados (getters/métodos, no se guardan):

- **Categorías**: las categorías presentes en `rows`, ordenadas por total del período
  descendente. Ese orden alimenta tanto la lista como los colores.
- **Colores**: `Random(colorSeed)` recorriendo las categorías en ese orden y eligiendo
  `Colors.primaries[generator.nextInt(Colors.primaries.length)].shade700`, el mismo algoritmo de
  `buildTable` en "Gastos por categoría" (mismo período y moneda → mismos colores). El color de
  una categoría **no cambia** al habilitar/deshabilitar otras, porque se calcula sobre todas las
  categorías, no solo las activas.
- **Días**: todos los días calendario entre `selectedPeriodStartDate` y
  `selectedPeriodEndDate`. El eje X es el índice de día (0 … n-1). La fecha de un índice se
  obtiene por calendario, no sumando `Duration(days: n)` (que arrastra el problema del horario
  de verano): `DateTime(start.year, start.month, start.day + índice)`, que Dart normaliza. La
  cantidad de días es `dayIndex(start, end) + 1`, con el mismo `UtilsService.dayIndex`.
- **Series**: una `LineChartBarData` por categoría **activa**, con un `FlSpot(índiceDía, valor)`
  por cada elemento de su `dailyTotals` (ya trae 0 en los días sin gasto), `color` de la
  categoría, `dotData` oculto, `isCurved: false`.

Gráfico (`buildChart`, `SizedBox(height: 300)` + `LineChart`):

- **Eje X**: los datos están a nivel día, pero solo se dibuja label en el **primer día de cada
  mes** del rango (día 1), con formato `MM/yy`. Los demás días no muestran label. Grilla y bordes
  con el estilo de `expenses_by_day.dart` (`Colors.grey.shade300` / `shade400`).
- **Eje Y**: `minY = 0`, `maxY` = máximo valor entre las series activas; títulos izquierdos
  compactos (`k` / `M`) como en `expenses_by_day.dart`. Sin títulos arriba ni a la derecha.
- **Selección de día (sin tooltip)**: `LineTouchData(handleBuiltInTouches: false)` con un
  `touchCallback`. Al tocar o arrastrar (`FlTapUpEvent`, `FlPanUpdateEvent`,
  `FlLongPressMoveUpdate`) sobre el gráfico se toma el `x` del punto más cercano
  horizontalmente (el `distanceCalculator` por defecto mide solo distancia horizontal, así que
  no hace falta precisión vertical ni importa que las líneas se crucen) y se guarda en
  `selectedDayIndex`. El día marcado se dibuja con una línea vertical
  (`extraLinesData: ExtraLinesData(verticalLines: [VerticalLine(x: selectedDayIndex)])`). No
  hay puntos resaltados ni tooltip: los montos de ese día se leen en la lista de categorías.

Lista de categorías:

- Encima de la lista, una fila con dos acciones de texto (`CupertinoButton` con
  `padding: EdgeInsets.zero`): **Habilitar todas** (vacía `disabledCategories`) y
  **Deshabilitar todas** (`disabledCategories` = todas las categorías actuales).
- Luego una fila por categoría, con el mismo layout que la tabla de "Gastos por categoría"
  (círculo de color de 20×20 en una columna de 50 + nombre a `fontSize: 18`, negrita).
- **Sin día seleccionado** las filas no muestran montos. **Con día seleccionado**, encima de la
  lista aparece un encabezado con la fecha (`dd-MM-yyyy`) y un botón de texto "Quitar
  selección" (`selectedDayIndex = null`), y cada fila **activa** muestra a la derecha el monto
  de ese día (`dailyTotals[selectedDayIndex]`) con
  `utilsService.beautifyCurrency(monto, selectedCurrency)`. Las filas deshabilitadas no
  muestran monto. El orden de la lista no cambia con la selección.
- Tocar una fila alterna la categoría entre habilitada y deshabilitada. Las deshabilitadas se
  muestran con el nombre **tachado** (`TextDecoration.lineThrough`) y el círculo de color
  atenuado (opacidad reducida); no se dibuja su línea.

Estados especiales:

- `rows == null` → `Loader`.
- `rows` vacío → `No hay datos` (mismo estilo que los otros gráficos); el selector de moneda y
  el de período siguen visibles.
- Todas las categorías deshabilitadas → se oculta el gráfico y en su lugar se muestra el texto
  `No hay categorías seleccionadas`; la lista y los botones siguen visibles.

Persistencia de la selección:

- `disabledCategories` se conserva al cambiar moneda, período o cuenta (las categorías que ya no
  aparecen en los datos simplemente se ignoran). Se descarta al salir del gráfico (el widget se
  destruye al cambiar de tipo de gráfico). Cambiar de cuenta no reconstruye el widget (el tipo
  de gráfico no cambia, Flutter conserva el `State` y llama a `didUpdateWidget`), por eso el
  período y la selección sobreviven; lo único que se reinicia por la cuenta es la moneda.
- Por defecto, todas las categorías arrancan activas, sin importar cuántas sean; el usuario es
  responsable de seleccionar las que quiere ver.

Convenciones de código: orden de miembros, `buildX`, `getX`, guard `mounted` tras `await`,
`await databaseService.initialized`, y try/catch con `logger.e` en el fetch, según
[coding-style.md](../../coding-style.md). Si el archivo supera ~500 líneas se evalúa extraer
la lista de categorías a un widget propio.

### 3. `statistics.dart`

- `buildChartTypeSelector`: agregar `'Gastos por categoría históricos'` a `options`.
- `buildChart`: nueva rama que devuelve `HistoricalExpensesByCategoryChart(account: account)`.

### 4. Documentación

Por la regla de docs-in-sync, en [docs/features/statistics.md](../../features/statistics.md):

- "What it does": pasar de "Two chart views" a tres y describir el nuevo gráfico.
- "Key repository methods": agregar `getExpensesByCategoryByDay`.
- "Views involved": agregar `historical_expenses_by_category.dart`.
- "Edge cases": opciones de período del nuevo gráfico, agrupación diaria con labels mensuales,
  colores estables, selección persistente dentro del gráfico.

## Criterios de aceptación

1. El selector de tipo de gráfico incluye `Gastos por categoría históricos`.
2. La vista muestra, en orden: selector de moneda, selector de período, gráfico, botones
   habilitar/deshabilitar todas, lista de categorías.
3. El período ofrece `3 meses`, `6 meses`, `1 año`, `Custom`; `Custom` abre
   `DateRangeSelectorDialog` y cancelar no altera la selección.
4. Hay una línea por categoría activa, con el color de su fila en la lista; todas arrancan
   activas.
5. Los datos del gráfico son diarios (0 en días sin gasto) y el eje X solo muestra labels en el
   primer día de cada mes.
6. Tocar o arrastrar sobre el gráfico marca una línea vertical en el día más cercano y la
   lista muestra el monto de ese día por categoría activa; "Quitar selección" la limpia.
7. Los montos se convierten a la moneda elegida con la tasa vigente en la fecha de cada
   movimiento.
8. Tocar una categoría la habilita/deshabilita; las deshabilitadas se ven tachadas y no se
   dibujan.
9. "Habilitar todas" y "Deshabilitar todas" actúan sobre todas las categorías de la lista.
10. Cambiar moneda, período o cuenta recalcula el gráfico sin perder la selección de categorías.
   Cambiar la cuenta además reinicia la moneda a la de la cuenta (USD si es "Todas").
11. Sin datos se muestra `No hay datos`; con todas deshabilitadas, `No hay categorías
    seleccionadas`.
12. `flutter analyze` sin errores nuevos.
