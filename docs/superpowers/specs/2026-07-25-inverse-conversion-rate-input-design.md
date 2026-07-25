# Entrada inversa de la tasa de conversión (1 ÷ X)

## Contexto y problema

En el diálogo de crear/editar movimiento, las transferencias entre cuentas de distinta
moneda muestran un campo de tasa de conversión. La semántica guardada es
`target = amount * conversionRate` (`conversionRate` es un `double` en `Movement`).

Con el peso alrededor de `1 USD/EUR ≈ 1500 ARS`, la tasa directa es cómoda en una dirección
pero incómoda en la otra:

| Transferencia | `conversionRate` directo | Número a tipear hoy |
|---|---|---|
| USD → ARS | ~1485 | 1485 (cómodo) |
| ARS → USD | ~0,000673 | incómodo |
| ARS → EUR | ~0,000633 | incómodo |
| USD → EUR | ~0,92 | incómodo |
| EUR → USD | ~1,08 | 1,08 (cómodo) |

Hoy el campo usa 6 decimales (`precision: 6`) para que ambas direcciones sean "razonables",
pero eso es incómodo y no tiene sentido: en la dirección hacia una moneda más fuerte el número
se vuelve minúsculo (`0,000673`).

## Objetivo

Cuando el destino es una moneda más fuerte que el origen, que el usuario ingrese el **cambio
inverso** (el precio de la moneda fuerte, ej. `1485,23`), la UI muestre `Tasa de conversión
1 ÷ X`, e internamente se guarde `conversionRate = 1/X` con toda la precisión del `double`.
En la dirección natural (destino más débil) todo sigue igual: entrada directa, label
`Tasa de conversión X x`.

En ambos modos el usuario termina tipeando el mismo número (~1485 = "el dólar/euro a X"), que
es la forma natural de cotizar en Argentina.

## Decisiones de diseño

1. **Alcance: regla general por fuerza de moneda.** El modo inverso aplica siempre que el
   destino sea más fuerte que el origen — cubre ARS→USD, ARS→EUR y también USD→EUR — no solo
   los pares con ARS.
2. **Determinación según la tasa en vivo.** Se invierte cuando
   `utilsService.convertCurrencies(1, source.currency, target.currency) < 1`. No hay ranking
   hardcodeado de monedas.
3. **Precisión 2** en el campo (antes 6). Como el número ingresado siempre queda ≥ 1, dos
   decimales alcanzan (`1485,23`); para USD↔EUR queda algo grueso (`1,08`) y se acepta.
4. **Sin cambios de persistencia.** No cambia el modelo, el repositorio ni hay migración: la
   semántica de `conversionRate` guardado (`target = amount * conversionRate`, `double` de
   precisión completa) es la misma. Es un cambio puramente de entrada/visualización de UI.

## Alcance

- **Archivo único:** [new_movement.dialog.dart](../../../lib/views/movements/new_movement.dialog.dart).
- Actualización de docs en el mismo cambio (ver sección Docs).

## Diseño detallado

Todo ocurre en `_NewMovementDialogState`.

### Detección de dirección (getter derivado)

```dart
bool get isRateInverse =>
    source.currency != target.currency &&
    utilsService.convertCurrencies(1, source.currency, target.currency) < 1;
```

Se evalúa en cada `build`, así que cambiar las cuentas (y con ello la dirección) ajusta el modo
automáticamente. El chequeo `source.currency != target.currency` es defensivo (la sección solo
se muestra en ese caso, y `convertCurrencies` devuelve el monto sin cambios cuando `from == to`).

### Estado: una sola fuente de verdad

Se reemplaza el campo mutable `conversionRate` por el **valor crudo tipeado** (siempre ≥ 1) y se
deriva el rate efectivo mediante un getter:

```dart
double rawConversionRate = 1;

double get conversionRate =>
    rawConversionRate == 0 ? 0 : (isRateInverse ? 1 / rawConversionRate : rawConversionRate);
```

- `onChanged` del campo de tasa solo setea `rawConversionRate` (parseando el masked input y
  dividiendo por `100`).
- `submit()` y el preview "Recibís …" siguen usando `conversionRate`, que ahora es el getter y
  refleja el modo vigente. Al invertir la dirección no hay que recalcular nada a mano.
- La guarda `rawConversionRate == 0` evita `1/0` en el preview mientras el campo está vacío/en
  cero (el validator igual bloquea el submit).

### Campo y label dinámicos

- Controller: `MoneyMaskedTextController(... precision: 6 ...)` → `precision: 2`, con
  `initialValue: 1`. El `onChanged` pasa de dividir por `1000000` a dividir por `100`.
- **Modo directo** (destino más débil, ej. USD→ARS): prefix `Tasa de conversión `, suffix `x`
  (como hoy).
- **Modo inverso** (destino más fuerte, ej. ARS→USD): prefix `Tasa de conversión 1 ÷ `, sin
  suffix `x`.

### Edición

`fillFormDataWithMovement` (se ejecuta después de setear `source`/`target`, así que
`isRateInverse` ya es válido):

```dart
var storedRate = movement.conversionRate ?? 1;
rawConversionRate = isRateInverse ? 1 / storedRate : storedRate;
conversionRateInputController.text = rawConversionRate.toStringAsFixed(2);
```

Para movimientos sin `conversionRate` (no cross-currency), `storedRate` es `1` e `isRateInverse`
es `false` (misma moneda), así que `rawConversionRate` queda en `1` como hoy.

(Se mantiene el patrón existente de asignar `.text` con `toStringAsFixed`, igual que el campo de
monto.) La dirección para editar se decide con el mismo getter `isRateInverse` (tasa en vivo);
como la fuerza relativa de las monedas es estable, coincide con la dirección con que se cargó el
movimiento originalmente.

## Edge cases

- **Tasas sin cargar (offline en primer arranque, mappings = seed `1`):**
  `convertCurrencies(1, ARS, USD)` devuelve `1` (no `< 1`), así que `isRateInverse` es `false` y
  ARS→USD caería en modo directo (número chico). Es el mismo escenario donde la app ya muestra
  conversiones 1:1; se autocorrige cuando cargan las tasas. Limitación aceptada, coherente con
  los edge cases de currency.
- **Campo vacío / cero:** el validator ya bloquea el submit (no vacío, parseable, ≠ 0). El getter
  devuelve `0` cuando `rawConversionRate == 0` para no propagar `1/0` al preview.
- **USD↔EUR (derivado vía ARS):** exactamente una de las dos direcciones da `< 1`
  (`usdBuy/eurSell` para USD→EUR, `eurBuy/usdSell` para EUR→USD), así que el par queda
  consistente: una dirección directa, la otra inversa.

## Docs a actualizar (mismo cambio)

- [docs/features/movements.md](../../features/movements.md) — edge case "Currency conversion on
  transfer": aclarar que el input de tasa se ingresa en la dirección ≥ 1 y que, para destino más
  fuerte, la UI muestra `1 ÷ X` y guarda `1/X` como `conversionRate`.
- [docs/features/currency.md](../../features/currency.md) — nota breve: el diálogo de movimiento
  decide la dirección del input con `convertCurrencies(1, origen, destino) < 1`.

## Fuera de alcance

- Prellenar el campo con la cotización de mercado actual (hoy el default es `1`; se mantiene).
- Cambios de esquema/migración.
- Cualquier cambio en cómo se convierten balances/estadísticas (usan `conversionRate` guardado,
  que no cambia de semántica).
