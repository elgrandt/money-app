# Gráfico "Gastos por categoría históricos"

Fecha: 2026-10-03 (rediseño mensual: 2026-10-04)

## Objetivo

Agregar a la sección de Estadísticas un tercer tipo de gráfico, **"Gastos por categoría
históricos"**, pensado para ver la **varianza mes a mes del gasto de cada categoría** (por
ejemplo: en supermercado gasté 80 USD el mes pasado y 100 USD este mes). Es un gráfico de
líneas con **un punto por mes y por categoría** (eje horizontal = mes, eje vertical = gasto),
más una lista de categorías que permite habilitar/deshabilitar cada línea y que muestra la
variación porcentual contra el mes anterior.

Orden de la vista, de arriba a abajo:

1. Selector de moneda (`CurrencySelector`).
2. Selector de período: `3 meses` / `6 meses` / `1 año` / `Custom`.
3. Gráfico de líneas.
4. Botones "Habilitar todas" / "Deshabilitar todas".
5. Lista de categorías con su color.

### Historia del diseño

La primera versión agrupaba por **día** (una línea diaria por categoría). Funcionó, pero con 30
o más puntos por mes se ve el ruido del día a día y no la comparación entre meses, que es lo
que se quiere ver. Se rediseñó a granularidad **mensual**. El código diario se reemplaza, no
coexiste.

## Contexto actual

- [statistics.dart](../../../lib/views/statistics/statistics.dart) tiene un selector de cuenta y
  un selector de tipo de gráfico (`Ninguno` / `Gastos por categoría` / `Gastos por día` /
  `Gastos por categoría históricos`); cada gráfico es un widget que recibe `Account? account`.
- [historical_expenses_by_category.dart](../../../lib/views/statistics/historical_expenses_by_category.dart)
  ya existe con la versión diaria: selectores, colores estables (`Random(134)`), habilitar y
  deshabilitar categorías, selección de un punto con línea vertical y estados vacíos. El
  rediseño reutiliza todo eso y cambia la granularidad.
- [expenses_by_category.dart](../../../lib/views/statistics/expenses_by_category.dart) es el
  gráfico hermano: mismos colores y mismo criterio para `Custom` (`DateRangeSelectorDialog`).
- `MovementsRepository.getExpensesByCategoryByDay` y `UtilsService.dayIndex` (versión diaria)
  se reemplazan por sus equivalentes mensuales.
- [docs/data-layer.md](../../data-layer.md) documenta el patrón "Typed query results" y usa la
  clase de este gráfico como referencia.

## Alcance

Dentro de alcance:

- Reemplazar el método de repositorio diario por `getExpensesByCategoryByMonth` y el helper
  `dayIndex` por `monthIndex`.
- Reescribir la vista a granularidad mensual, con variación porcentual.
- Docs: `features/statistics.md` y `data-layer.md` (nombre de la clase de referencia).

Fuera de alcance:

- No se tocan modelos, migraciones, el dashboard ni los otros dos gráficos.
- No hay selector de tipo de movimiento: el gráfico es solo de **gastos** (`REMOVE`).
- No hay suavizado, zoom ni agrupación configurable (la granularidad es siempre mensual).
- No se muestra la diferencia en monto, solo el porcentaje.

## Diseño

### 1. Renombres (los hace el usuario con el IDE)

Por la regla del proyecto, los renombres los hace el usuario con el rename del IDE para que
actualice todas las referencias; después se verifica que no quede ninguna sin cambiar:

| Antes | Después |
|-------|---------|
| `CategoryDailyExpenses` | `CategoryMonthlyExpenses` |
| campo `dailyTotals` | `monthlyTotals` |
| `getExpensesByCategoryByDay` | `getExpensesByCategoryByMonth` |

`UtilsService.dayIndex` no se renombra: se **elimina** y se agrega `monthIndex` (ver abajo).

### 2. Repositorio

En `MovementsRepository`, en lugar de `getExpensesByCategoryByDay`:

```dart
Future<List<CategoryMonthlyExpenses>> getExpensesByCategoryByMonth(
    Account? account, DateTime startMonth, DateTime endMonth, Currency displayCurrency)
```

y la clase (sigue el patrón "Typed query results": simple, inmutable, sin `BaseModel`, declarada
en `movements.repository.dart`):

```dart
class CategoryMonthlyExpenses {
  final String category;
  final List<double> monthlyTotals;

  const CategoryMonthlyExpenses({ required this.category, required this.monthlyTotals });

  double get total => monthlyTotals.fold<double>(0, (sum, value) => sum + value);
}
```

- `startMonth` y `endMonth` son fechas cualquiera dentro del mes inicial y del mes final (ambos
  meses incluidos); el método usa solo su año y mes.
- Filtra `type = REMOVE` y, opcionalmente, por cuenta (`sourceId = ? OR targetId = ?`).
- Rango de fechas: `creationDate >= primer día de startMonth` y
  `creationDate < primer día del mes siguiente a endMonth`. El límite superior es **exclusivo**.
  La comparación es de texto, así que los parámetros se pasan con `toIso8601String()`, el mismo
  formato con el que se guarda `creationDate` (las consultas existentes pasan `toString()`, con
  espacio en lugar de `T`, y por eso excluyen el último día; ver
  [tech-debt.md](../../tech-debt.md). Esa deuda no se arregla acá).
- Convierte cada movimiento con `utilsService.convertCurrenciesAt(amount, source.currency,
  displayCurrency, creationDate)`, igual que los otros métodos.
- Agrupa **primero por categoría y luego por mes**. Devuelve un `CategoryMonthlyExpenses` por
  categoría con gasto en el período. `monthlyTotals` tiene siempre el mismo largo para todas las
  categorías, `monthIndex(startMonth, endMonth) + 1`, con `0.0` en los meses sin gasto.
- **Mes de un movimiento**: el de su `creationDate` local (año y mes del valor local; nunca
  `toUtc()`).
- `UtilsService.monthIndex(startMonth, date)` devuelve la cantidad de meses calendario entre
  ambos: `(date.year - startMonth.year) * 12 + date.month - startMonth.month`. Es aritmética
  entera sobre año y mes, sin fechas de por medio, por lo que no hay problema de horario de
  verano.
- No ordena: la vista ordena por `total` de mayor a menor, como "Gastos por categoría".
- Es independiente de `getExpensesByCategory` / `getExpensesByDay`: no se extrae lógica
  compartida.

### 3. Vista `HistoricalExpensesByCategoryChart`

Mismo archivo y mismo contrato (`final Account? account`). Estado (sin cambios salvo lo
marcado):

- `Currency selectedCurrency` — inicial: `widget.account?.currency ?? Currency.USD`.
- `String selectedPeriod` — `'3-months'` (default), `'6-months'`, `'1-year'`, `'custom'`.
- `DateTimeRange? customRange`.
- `List<CategoryMonthlyExpenses>? rows` y `DateTime? rowsStartMonth` (primer mes de los datos
  cargados; `null` = cargando).
- `Set<String> disabledCategories` — vacío = todas activas.
- `int? selectedMonthIndex` — mes marcado en el gráfico (reemplaza a `selectedDayIndex`).
- `final colorSeed = 134`.

Período en **meses calendario**, con dos getters que devuelven el primer día de un mes
(`selectedPeriodStartMonth`, `selectedPeriodEndMonth`), siendo `now` la fecha actual:

| Opción     | `selectedPeriodStartMonth`                                | `selectedPeriodEndMonth`                 |
|------------|-----------------------------------------------------------|------------------------------------------|
| `3-months` | `DateTime(now.year, now.month - 2)`                       | `DateTime(now.year, now.month)`          |
| `6-months` | `DateTime(now.year, now.month - 5)`                       | `DateTime(now.year, now.month)`          |
| `1-year`   | `DateTime(now.year, now.month - 11)`                      | `DateTime(now.year, now.month)`          |
| `custom`   | `DateTime(customRange.start.year, customRange.start.month)` | `DateTime(customRange.end.year, customRange.end.month)` |

Es decir, `3 meses` = mes actual y los 2 anteriores (3 puntos), `6 meses` = 6 puntos,
`1 año` = 12 puntos, y `Custom` se ajusta a los meses **completos** que toca el rango elegido
(un rango del 15/03 al 10/05 muestra marzo, abril y mayo). El **mes en curso está siempre
incluido** y es parcial (ver más abajo).

`Custom` abre `DateRangeSelectorDialog` (`initialRange: customRange`,
`lastDate: DateTime.now()`); si se cancela no cambia nada. Cambiar moneda, período o cuenta
vuelve a consultar el repositorio. En `didUpdateWidget`, si cambia la cuenta, `selectedCurrency`
pasa a `widget.account?.currency ?? Currency.USD`; el período, `customRange` y
`disabledCategories` no se tocan. Cada nueva consulta limpia `selectedMonthIndex`. Se mantiene
la protección contra respuestas fuera de orden (`lastRequestId`).

Cálculos derivados (getters, no se guardan):

- **Categorías**: las de `rows`, ordenadas por `total` descendente. Ese orden alimenta la lista
  y los colores.
- **Colores**: `Random(colorSeed)` recorriendo las categorías en ese orden y eligiendo
  `Colors.primaries[generator.nextInt(Colors.primaries.length)].shade700`, el mismo algoritmo
  que la tabla de "Gastos por categoría". El color de una categoría no cambia al
  habilitar/deshabilitar otras porque se calcula sobre todas.
- **Meses**: el eje X es el índice de mes (0 … n-1); el mes de un índice es
  `DateTime(rowsStartMonth.year, rowsStartMonth.month + índice)`. `n` es el largo común de
  `monthlyTotals`.
- **Mes en curso**: el último índice, cuando el mes final del período es el mes actual.
- **Variación de un mes**: para un mes `i > 0` de una categoría,
  `(monthlyTotals[i] - monthlyTotals[i-1]) / monthlyTotals[i-1] * 100`. Si el mes anterior es
  `0`, o si `i == 0` (no hay mes anterior dentro del período), **no hay variación** y se muestra
  `—`. Se formatea con signo y sin decimales (`+25%`, `-10%`, `0%`).

Gráfico (`SizedBox(height: 300)` + `LineChart`):

- **Series**: por cada categoría **activa**, una línea continua con un `FlSpot(índiceMes,
  monto)` por mes, de color propio, `isCurved: false`. Para el mes en curso se agrega, por
  categoría, una **segunda línea punteada** (`dashArray: [5, 5]`) con solo los dos últimos
  puntos (mes anterior → mes en curso) y la línea continua se corta en el mes anterior; así el
  último tramo se ve como provisional. Si el período tiene un solo mes no hay tramo (ver
  "Estados especiales").
- **Eje X**: una etiqueta `MM/yy` por mes (`DateFormat('MM/yy')`), girada. Para que no se
  amontone con rangos largos en `Custom`, se dibuja una etiqueta cada
  `ceil(cantidadDeMeses / 12)` meses, siempre empezando en el primer mes. Grilla y bordes con el
  estilo de `expenses_by_day.dart` (`Colors.grey.shade300` / `shade400`).
- **Eje Y**: `minY = 0`, `maxY` = máximo entre las series activas (`1` si es `0`), con un
  `interval` explícito (`max(1, (maxY / 5).ceil())`) para que no se repitan etiquetas con
  máximos chicos; títulos izquierdos compactos (`k` / `M`) como en `expenses_by_day.dart`. Sin
  títulos arriba ni a la derecha.
- **Selección de mes (sin tooltip)**: `LineTouchData(handleBuiltInTouches: false)` con
  `touchCallback`. Al tocar o arrastrar (`FlTapUpEvent`, `FlPanUpdateEvent`,
  `FlLongPressMoveUpdate`) se toma el `x` del punto más cercano horizontalmente y se guarda en
  `selectedMonthIndex`. El mes marcado se dibuja con una línea vertical
  (`extraLinesData`). No hay puntos resaltados ni tooltip: los datos del mes se leen en la lista.

Lista de categorías:

- Encima, una fila con dos acciones de texto (`CupertinoButton`, `padding: EdgeInsets.zero`):
  **Habilitar todas** y **Deshabilitar todas**.
- Una fila por categoría: círculo de color de 20×20 en una columna de 50 + nombre a
  `fontSize: 18`, negrita. Tocar la fila alterna habilitada/deshabilitada; las deshabilitadas
  muestran el nombre **tachado** y el círculo atenuado, y no se dibujan.
- **Sin mes seleccionado** las filas no muestran montos. **Con mes seleccionado**, encima de la
  lista aparece un encabezado con el mes (`MM/yyyy`, agregando ` (en curso)` si es el mes en
  curso) y un botón "Quitar selección". Cada fila **activa** muestra a la derecha el monto de
  ese mes (`beautifyCurrency(monto, selectedCurrency)`) y, al lado, la variación porcentual
  contra el mes anterior (`+25%`), coloreada: **rojo** (`Colors.red.shade900`) si el gasto
  subió, **verde** (`Colors.green.shade900`) si bajó, neutro si es `0%` o `—`. Las filas
  deshabilitadas no muestran monto ni variación. El orden de la lista no cambia con la
  selección.

Estados especiales:

- `rows == null` → `Loader`.
- `rows` vacío → `No hay datos` (los selectores siguen visibles).
- Todas las categorías deshabilitadas → se oculta el gráfico y se muestra
  `No hay categorías seleccionadas`; la lista y los botones siguen visibles.
- **Un solo mes** en el período (por ejemplo un `Custom` dentro de un mismo mes): cada línea
  tiene un único punto, que no se dibuja sin marcador; en ese caso se muestran los puntos
  (`FlDotData(show: true)`) y no se agrega línea punteada. La variación es `—`.

Persistencia de la selección:

- `disabledCategories` se conserva al cambiar moneda, período o cuenta (las categorías que ya no
  aparecen en los datos se ignoran) y se descarta al salir del gráfico. Cambiar de cuenta no
  reconstruye el widget (Flutter conserva el `State` y llama a `didUpdateWidget`); lo único que
  se reinicia por la cuenta es la moneda.
- Todas las categorías arrancan activas, sin importar cuántas sean.

Convenciones de código: según [coding-style.md](../../coding-style.md) — orden de miembros,
métodos cortos (un `buildX` por hijo), constantes con nombre, sin comentarios, guard `mounted`
tras `await`, `await databaseService.initialized` y `try`/`catch` con `logger.e` en el fetch.

### 4. `statistics.dart`

Sin cambios: la opción `Gastos por categoría históricos` ya existe.

### 5. Documentación

Por la regla de docs-in-sync:

- [features/statistics.md](../../features/statistics.md): describir el gráfico como mensual;
  reemplazar `getExpensesByCategoryByDay` por `getExpensesByCategoryByMonth`; reemplazar las
  entradas de "Edge cases" de granularidad diaria por las mensuales (período en meses
  calendario, mes en curso incluido y parcial, variación porcentual y sus casos `—`, etiquetas
  del eje X); actualizar los rangos de líneas citados del repositorio.
- [data-layer.md](../../data-layer.md): la clase de referencia pasa a ser
  `CategoryMonthlyExpenses` (con `monthlyTotals`).

## Criterios de aceptación

1. El selector de tipo de gráfico incluye `Gastos por categoría históricos`.
2. La vista muestra, en orden: selector de moneda, selector de período, gráfico, botones
   habilitar/deshabilitar todas, lista de categorías.
3. El período ofrece `3 meses`, `6 meses`, `1 año`, `Custom`. `3 meses` muestra el mes actual y
   los 2 anteriores (3 puntos por línea), `6 meses` 6 puntos y `1 año` 12. `Custom` abre
   `DateRangeSelectorDialog`, cancelar no altera la selección y el rango se ajusta a los meses
   completos que toca.
4. Hay una línea por categoría activa, con el color de su fila; todas arrancan activas.
5. Los datos son mensuales (0 en meses sin gasto) y el eje X muestra una etiqueta `MM/yy` por
   mes (una cada `ceil(meses / 12)` meses si son más de 12).
6. El mes en curso está incluido; su último tramo se dibuja punteado y en el encabezado de la
   selección aparece `(en curso)`.
7. Tocar o arrastrar sobre el gráfico marca una línea vertical en el mes más cercano y la lista
   muestra, por categoría activa, el monto de ese mes y la variación porcentual contra el mes
   anterior (`+25%`, rojo si subió, verde si bajó, `—` si no hay mes anterior o este es `0`);
   "Quitar selección" la limpia.
8. Los montos se convierten a la moneda elegida con la tasa vigente en la fecha de cada
   movimiento.
9. Un movimiento del último día del mes (por ejemplo a las 23:30) cuenta en ese mes.
10. Tocar una categoría la habilita/deshabilita; las deshabilitadas se ven tachadas y no se
    dibujan. "Habilitar todas" y "Deshabilitar todas" actúan sobre todas las categorías.
11. Cambiar moneda, período o cuenta recalcula el gráfico sin perder la selección de categorías;
    cambiar la cuenta además reinicia la moneda a la de la cuenta (USD si es "Todas").
12. Sin datos se muestra `No hay datos`; con todas deshabilitadas, `No hay categorías
    seleccionadas`; con un solo mes, los puntos se ven.
13. `flutter analyze` sin errores nuevos.
