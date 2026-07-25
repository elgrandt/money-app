# Diseño: tasas de cambio históricas para movimientos

**Fecha:** 2026-07-25
**Estado:** Aprobado (pendiente de revisión del spec)
**Branch:** `feature/movement-historical-rates`

## Problema

Toda cifra multi-moneda de la app se calcula con una única **tasa viva global**
(`UtilsService.currencyMappings`, derivada de la última tasa "blue" de bluelytics y cacheada en una
tabla `currency_rates` de una sola fila). Las conversiones no tienen temporalidad: un movimiento
creado hace dos años se muestra/agrega a la tasa de *hoy*, lo que tergiversa cuánto valía cuando
ocurrió.

**Objetivo:** valuar cada movimiento a la tasa de cambio vigente **al momento en que fue creado**, y
usar esa tasa en todo lugar donde el movimiento se muestre o agregue en otra moneda. Es aceptable
completar los movimientos viejos con la tasa actual.

## Alcance

Las tasas históricas aplican **solo a conversiones a nivel de movimiento**:

- Lista de movimientos (`movements_list.dart`)
- Agregaciones de estadísticas — gastos por categoría y por día (`movements.repository.dart`)

**Fuera de alcance (se mantiene la tasa viva):** el patrimonio total y el gráfico de tortas de
totales por cuenta (`total_viewer.dart`, `dashboard.dart`). Estos convierten *saldos actuales de las
cuentas*, que son cifras "al día de hoy" sin una fecha de creación única, así que la tasa viva es la
elección correcta. `movement_details.dialog.dart` muestra los importes en la moneda nativa de las
cuentas del movimiento (sin conversión FX) y no se ve afectado.

## Enfoque: búsqueda por fecha contra un historial de tasas (sin FK por movimiento)

En vez de guardar una foto de la tasa (o una foreign key) en cada movimiento, la tasa de un
movimiento se **deriva** de su `creationDate` contra una tabla de historial de tasas. Se eligió esto
por sobre una FK/foto por movimiento porque:

- No cambia la tabla `movements` ni el modelo `Movement`.
- No hay nada que setear en `create`; editar la fecha de un movimiento lo re-valúa correctamente de
  forma automática.
- La tabla de tasas se mantiene compacta gracias al dedup-on-change (ver abajo).

Trade-off aceptado: las conversiones son derivadas, no congeladas por movimiento — extender o
corregir el historial de forma retroactiva desplaza los valores mostrados del pasado. Esto es
aceptable para una app de finanzas personales de un solo usuario y es justamente lo que hace que la
edición de fechas "funcione sola".

## Modelo de datos y esquema

`currency_rates` pasa a ser una **tabla de historial que agrega filas al cambiar** (append-on-change):

- Agregar una columna `createdAt` DATE: cuándo apareció por primera vez este conjunto distinto de
  cuatro tasas.
- Mantener `updatedAt`: la última vez que se observó que las mismas cuatro tasas seguían vigentes
  (también alimenta el texto de "última actualización" del dashboard).
- Semántica de la fila: *estas cuatro tasas rigieron desde `createdAt` hasta el `createdAt` de la
  fila siguiente.*

Agregar `createdAt` a:

- `CurrencyRatesRepository.currencyRatesColumns` (definición de DB fresca).
- El modelo `CurrencyRates` (campo `createdAt`, constructor, `toString`).

**No cambia** la tabla `movements` ni el modelo `Movement`.

## Registro de tasas (dedup-on-change)

Reemplazar `CurrencyRatesRepository.saveLatest` (upsert de una sola fila) por
`record(CurrencyRates rates)`:

1. Cargar la última fila (`findLatest`).
2. Si existe **y los cuatro valores (`usdBuy`, `usdSell`, `eurBuy`, `eurSell`) son iguales** →
   actualizar su `updatedAt = now`.
3. En caso contrario → **insertar** una fila nueva con `createdAt = now`, `updatedAt = now`.

Se crea una fila nueva solo cuando un valor efectivamente cambia, manteniendo la tabla chica.
`findLatest()` no cambia, así que `exchange_rates.dart` y `loadCachedMappings()` siguen funcionando
tal cual.

## Capa de conversión (`UtilsService`)

- Extraer un builder puro del cuerpo actual de `applyRates`:
  `List<CurrencyMapping> buildMappings({required double usdBuy, required double usdSell, required
  double eurBuy, required double eurSell})`. `applyRates` pasa a ser
  `currencyMappings = buildMappings(...)`.
- Mantener `currencyMappings` + `convertCurrencies(amount, from, to)` como el camino **vivo** (saldos
  / totales) — comportamiento sin cambios, sigue disparando el `updateCurrencyMappings()` con
  throttle.
- Agregar una `List<CurrencyRates> rateHistory` en memoria, ordenada por `createdAt` ascendente. Se
  carga en `loadCachedMappings()` y se refresca después de cada `record(...)`.
- Agregar **`convertCurrenciesAt(double amount, Currency from, Currency to, DateTime date)`**:
  1. `from == to` → devolver `amount`.
  2. Resolver la fila aplicable: la última fila con `createdAt <= date`; si no hay ninguna, la fila
     **más antigua**; si `rateHistory` está vacío, caer a los **mappings por defecto (1:1)**.
  3. Construir los mappings desde la fila resuelta (`buildMappings`) y convertir.

  `convertCurrenciesAt` **no** dispara un fetch de red (el camino vivo ya refresca en el init y en las
  conversiones de saldos), evitando una estampida de requests al iterar muchos movimientos en las
  estadísticas.

## Frescura de tasas al crear/editar movimientos

Al abrir el diálogo de crear/editar movimiento (`new_movement.dialog.dart`, en `initState`) se dispara
un `updateCurrencyMappings()` **unawaited y respetando el throttle de 1h**. Así, mientras el usuario
completa los datos, el historial se refresca en segundo plano y un movimiento con `creationDate = now`
resuelve a la tasa más reciente disponible.

- No bloquea el guardado: si el usuario guarda muy rápido o está offline, el movimiento usa la última
  tasa conocida (nunca se espera a la red).
- El throttle de 1h hace que la llamada coalesca con el resto de los refreshes y evita pegarle a la API
  si ya hubo un fetch hace poco; el blue se mueve lento, así que 1h es fresco suficiente.
- Con el dedup-on-change, abrir/cerrar el diálogo repetidamente no infla la tabla (si el rate no
  cambió, solo se toca `updatedAt`).

## Cambios en los call-sites de lectura/visualización

Pasar estas conversiones a nivel de movimiento de `convertCurrencies(...)` a
`convertCurrenciesAt(..., movement.creationDate)`:

- `movements_list.dart` — getter `MovementListItem.amount`.
- `movements.repository.dart` — `getExpensesByCategory` y `getExpensesByDay`.

### Estadísticas: eliminar la doble conversión

Hoy `getExpensesByCategory`/`getExpensesByDay` convierten cada movimiento a una moneda base, y el
toggle de la tabla en `expenses_by_category.dart` re-expresa el **agregado** con la tasa viva. Con
tasas históricas ese segundo paso volvería a introducir pérdida de temporalidad a nivel del agregado.

Fix (enfoque totalmente correcto, elegido):

- Darles a `getExpensesByCategory`/`getExpensesByDay` un parámetro `Currency displayCurrency` y
  convertir **cada movimiento directamente a esa moneda a su propio `creationDate`**, sumando por
  categoría / por día.
- En `expenses_by_category.dart`, el toggle de moneda re-ejecuta la query con la nueva moneda
  seleccionada (una re-query local y rápida) en vez de convertir el agregado ya cargado. El modo
  `PERCENT` calcula los ratios desde el agregado actualmente cargado (los ratios son consistentes
  dentro de una misma agregación), así que no necesita conversión.
- `expenses_by_day.dart` no tiene toggle de moneda; que el repo convierta cada movimiento
  históricamente a la moneda de la cuenta (o USD cuando no hay cuenta seleccionada) es el fix
  completo ahí.

### Sin cambios (tasa viva, por diseño)

- `total_viewer.dart` (totales de una cuenta y del patrimonio total).
- `dashboard.dart` `buildTotalsChart` (torta de totales por cuenta).
- `movement_details.dialog.dart` (importes en moneda nativa, sin FX).

## Migración

Nueva `lib/migrations/add_created_at_to_currency_rates.migration.dart`, agregada a
`migrationDefinitions` en `migrations_list.dart`:

- `ALTER TABLE currency_rates ADD createdAt ...` protegida por el patrón de idempotencia establecido
  para columnas duplicadas.
- Completar el `createdAt` de la fila existente a partir de su `updatedAt`.
- Efecto sobre los datos existentes: los movimientos existentes son anteriores a ese `createdAt`, así
  que resuelven por la regla de la "fila más antigua" a la tasa actual/última conocida — el
  comportamiento aceptado de "los valores viejos usan la tasa actual". No se traen tasas históricas de
  la red.

## Casos borde

- **Historial disperso / gaps offline:** un movimiento creado durante un gap resuelve a la última
  tasa conocida antes de él — lo mejor disponible; aceptado.
- **Historial vacío (instalación fresca, offline antes del primer fetch):** `convertCurrenciesAt` cae
  a los defaults 1:1, coincidiendo con el comportamiento de seed actual. Se autocorrige en cuanto el
  primer fetch registra una fila.
- **Derivado, no congelado:** corregir/extender el historial ajusta retroactivamente los valores
  mostrados del pasado — es intencional (app de un solo usuario; habilita la edición correcta de
  fechas).
- **Transferencias:** el `conversionRate` ingresado manualmente sigue gobernando el crédito
  origen→destino y la visualización del importe recibido; `convertCurrenciesAt` solo gobierna
  re-expresar el importe de un movimiento en una moneda de visualización *distinta*.

## Docs a actualizar (en el mismo cambio, por la regla de mantenimiento de docs)

- `docs/features/currency.md` — tabla de historial, dedup-on-change, `convertCurrenciesAt`,
  `rateHistory`, regla de resolución.
- `docs/features/statistics.md` — conversión histórica por movimiento y el toggle con re-query.
- `docs/features/movements.md` — aclarar que las conversiones de visualización/agregación son por
  fecha, y el refresh de tasas (throttled) al abrir el diálogo de crear/editar.
- `docs/migrations.md` — la entrada de la nueva migración (vía la receta).
