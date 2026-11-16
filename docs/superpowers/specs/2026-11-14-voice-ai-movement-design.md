# Crear movimientos hablando (asistente de IA on-device)

Fecha: 2026-11-14

## Objetivo

Permitir crear un movimiento diciendo una frase en lenguaje natural, por ejemplo *"Gasté cien
pesos en Carrefour"* o *"ayer al mediodía le pagué a Silvia cincuenta mil pesos"*. Un modelo de
IA **que corre en el teléfono (sin API paga)** interpreta la frase y devuelve los datos del
movimiento; la app muestra un resumen para crearlo o modificarlo.

El caso de uso es el de un único usuario con un iPhone 17 Pro (Apple Intelligence). Otras
personas pueden usar la app; si su teléfono no tiene IA local, simplemente **no ven el botón**.

Ejemplos esperados (con las categorías y cuentas del usuario):

- *"Gasté cien pesos en Carrefour"* → Gasto, 100, categoría `Supermercados` (o la más cercana
  que exista), descripción `Carrefour`, fecha y hora actuales, cuenta por fallback.
- *"Ayer al mediodía le pagué a Silvia cincuenta mil pesos"* → Gasto, 50.000, ayer 12:00,
  categoría `Silvia`, sin descripción.

## Objetivos, no-objetivos y anti-objetivos

Objetivos:

- Cero costo por uso (todo on-device) y sin enviar datos financieros a terceros.
- Interfaz genérica que permita cambiar de proveedor (otro modelo on-device, una API en la nube,
  un modelo que reciba audio directo) **sin tocar la UI**.
- Poder comparar dos combinaciones de paquetes (POC) cambiando una constante.

No-objetivos:

- No hay UI para elegir proveedor en runtime (solo constantes de compilación).
- No hay soporte Android en esta iteración (la interfaz lo permite; los paquetes candidatos
  también, pero no se valida ni se promete).
- No se crean categorías ni cuentas nuevas desde la voz.
- No hay historial de frases ni "deshacer" propio (se usa el flujo normal de borrar movimiento).

Anti-objetivos (fallaría aunque "funcione"):

- Crear un movimiento con monto o categoría inventados. Lo obligatorio que no se entendió
  **nunca** se adivina.
- Que un error o la falta de IA rompa el flujo manual existente (el botón `+` queda intacto).

## Contexto actual

- Los botones `+` son `FloatingActionButton` sueltos en [home.dart](../../../lib/views/home/home.dart)
  (dashboard y pestañas de cuenta) y en [account_list.dart](../../../lib/views/accounts/account_list.dart)
  (este último es para cuentas, no movimientos). Abren `NewMovementDialog`.
- [new_movement.dialog.dart](../../../lib/views/movements/new_movement.dialog.dart) recibe
  `selectedAccount` y `movement` (edición). `fillFormDataWithMovement(Movement)` ya precarga el
  formulario desde un `Movement`; el monto arranca en `0`, `selectedCategory` es `String?` y
  `canSubmit` exige un monto válido y una categoría.
- [movement.model.dart](../../../lib/models/movement.model.dart): `Movement` no tiene moneda;
  tiene `source` / `target` (`Account`) según el tipo. La moneda sale de la cuenta.
- La tasa de conversión se ingresa siempre en la dirección ≥ 1 (ver
  [movements.md](../../features/movements.md)); `isRateInverse` decide cómo se guarda.
- Flutter 3.27 / Dart ≥ 3.2, sin tests por política, sin codegen, iOS deployment target 12.
- No existe código nativo propio ni patrón de proveedores intercambiables: este diseño define
  ambos y debe documentarse (meta-regla del CLAUDE.md).

## Enfoques considerados

Paquetes verificados en pub.dev el 2026-11-14:

| Paquete | Rol | Madurez |
|---|---|---|
| `apple_foundation_models` 0.5.2 | LLM Apple, salida estructurada con esquema Dart, chequeo de disponibilidad | Nuevo (~960 descargas) |
| `speech_to_text` 7.5.0 | Voz a texto iOS/Android | Estándar (1.63k likes, 934k descargas) |
| `system_llm` 0.2.0 | LLM del sistema (Apple y Android) + voz on-device, `generateObject` | Muy nuevo (~690 descargas) |
| `google_mlkit_genai_prompt` | Gemini Nano en Android | No evaluado a fondo |

Los modelos on-device **solo aceptan texto**: hoy el flujo real es voz → texto → modelo.

- **A. `system_llm` solo.** Una dependencia, ya cubre Android. Es el paquete más inmaduro; en
  Android el JSON se valida pero no se restringe en la generación; voz con `SFSpeechRecognizer`.
- **B. `apple_foundation_models` + `speech_to_text`.** La salida estructurada se restringe en la
  generación y la voz usa el paquete más probado. Dos dependencias; el LLM es solo iOS.
- **C. Wrappers multi-backend** (`flutter_local_ai`, `flutter_edge_ai`): descartados, sin ventaja
  clara sobre A y B.

**Decisión (del usuario): implementar A y B detrás de la misma interfaz y elegir con una
constante**, como POC para comparar cuál interpreta mejor. Al terminar la comparación se borra
la implementación perdedora; la interfaz queda.

## Diseño

### Interfaz genérica: del audio al movimiento

Una sola interfaz, a nivel "voz → movimiento", para no atarse a "transcribir y después
interpretar" (un modelo que recibe audio directo, o uno que no transcribe en vivo, también
encajan):

```
MovementVoiceAssistant
  isAvailable()                    -> Future<bool>   // decide si se muestra el botón
  start(MovementPromptContext)     -> VoiceSession

VoiceSession
  partialTranscripts : Stream<String>   // opcional; puede no emitir nada
  result             : Future<Movement> // movimiento ya con defaults/fallbacks aplicados
  stop()                                // "Listo" o silencio
  cancel()
```

- `MovementPromptContext`: categorías por tipo, cuentas (nombre y moneda), fecha y hora
  actuales, cuenta de la pantalla actual (si hay) y valores por defecto.
- La **implementación compuesta** (`TranscribeThenParseAssistant`) usa internamente un
  `SpeechProvider` (voz → texto) y un `AiProvider` (texto → datos). Esas dos piezas son detalle
  interno de esa implementación, no parte del contrato. Una implementación futura de audio
  directo graba por su cuenta y no emite transcripción parcial.
- La UI no asume transcripción en vivo: si el stream no emite, la hoja muestra "Escuchando…" con
  una animación. El botón "Listo" siempre existe (no se depende de detectar silencio).

### Constantes del POC

Un único archivo de configuración con una constante por pieza (por ejemplo
`aiProviderChoice` y `speechProviderChoice`), para combinar libremente:
`system_llm` para el LLM con `speech_to_text` para la voz, etc. `isAvailable()` de la
combinación elegida decide si aparece el botón.

### Resultado: un `Movement` real, sin tipo "borrador" aparte

Dart no tiene `Partial<T>` ni reflexión, y el proyecto no usa codegen. En lugar de duplicar
`Movement` con todo opcional, el asistente devuelve un **`Movement` real**. Lo no interpretado
queda en el valor "vacío" que el diálogo ya entiende (`amount = 0`, `category = ''`). Un getter
(extensión sobre `Movement`) calcula si el movimiento está **incompleto**. Si se agrega un
campo a `Movement`, no hay un segundo tipo que mantener.

Lo único que no se puede eliminar es el **esquema que se le pasa al modelo**, porque describe
la frase en lenguaje natural y no el modelo de datos (moneda como código, fecha como texto,
cuenta por nombre). Vive en **un solo archivo** junto con el mapeo a `Movement`, y se anota en
[movements.md](../../features/movements.md): "si cambiás `Movement`, revisá este archivo".

### Reglas de campos

El modelo recibe categorías por tipo y cuentas (nombre y moneda).

| Campo | Si se interpreta | Si no se interpreta |
|---|---|---|
| Tipo | el dicho | `REMOVE` (Gasto) |
| Fecha y hora | la interpretada | ahora |
| Descripción | hasta 3 palabras, simple | vacía |
| Cuenta (Gasto/Ingreso) | la mencionada, si existe | **Fallback:** cuenta de la pantalla actual, si no la primera cuenta con la moneda dicha, si no la primera cuenta |
| Monto | el interpretado | **incompleto** |
| Categoría | una de las existentes (validada en Dart contra la lista) | **incompleto** |
| Transferencia: cuentas origen y destino | las dos mencionadas | **incompleto**; sin fallback |
| Transferencia entre monedas distintas: tipo de cambio | el dicho | **incompleto** |

- Representación de "no interpretado" en `Movement` (verificado en el modelo): `source` y
  `target` son `Account?` (nulos si faltan), `conversionRate` es `double?` (nulo si falta),
  `amount = 0` y `category = ''`. El getter de "incompleto" también mira que una transferencia
  tenga ambas cuentas y, si las monedas difieren, `conversionRate`.
- Tipo de cambio: el usuario lo nombra siempre en la dirección más grande ("cambié quinientos
  dólares a 1550 pesos"). La IA devuelve solo las cuentas origen y destino y el número tal cual
  se dijo; **no decide si se multiplica o se divide** (es aritmética, débil en el modelo chico).
  Dart decide la dirección de forma determinista con la misma lógica que el diálogo
  (`isRateInverse`, según qué moneda es más fuerte), y guarda `conversionRate` en consecuencia.
- Cuentas y categorías se le pasan al modelo como JSON con `id` (cuentas: `{id, name,
  currency}`; categorías: `{id, name}` por tipo) y **el modelo devuelve el `id`**, no el nombre.
  Dart traduce el id de categoría a su nombre (`Movement.category` guarda el nombre). Un id que
  no existe se trata como no interpretado: en Gasto/Ingreso activa el fallback de cuenta (el
  resumen muestra siempre la cuenta elegida, así se nota si fue fallback); en Transferencia y en
  la categoría es "incompleto".
- *(Decisión del diseño)* Orden del fallback de cuenta en Gasto/Ingreso: cuenta mencionada >
  cuenta de la pantalla actual **si su moneda coincide con la dicha (o no se dijo moneda)** >
  primera cuenta con la moneda dicha > primera cuenta. La moneda dicha gana sobre la pantalla.
- Las fechas relativas ("ayer al mediodía") se resuelven pasando al modelo la fecha y hora
  actuales. Si el spike muestra que el modelo calcula mal, el modelo devuelve el día relativo y
  la hora como campos y Dart hace la cuenta.

### Experiencia de usuario

1. Sobre el `+` aparece un segundo botón con ícono de IA (solo si `isAvailable()`), en el
   dashboard y en las pantallas de cuenta que hoy tienen el `+` de movimientos.
2. Al tocarlo se abre una **hoja "Te escucho…"**: empieza a escuchar, muestra la transcripción en
   vivo si hay, y tiene "Listo" y "Cancelar". Termina al tocar "Listo" o por silencio.
3. Se procesa (estado de carga) y:
   - **Movimiento completo** → diálogo de resumen (descripción legible del movimiento, estilo
     [movement_details.dialog.dart](../../../lib/views/movements/movement_details.dialog.dart))
     con **Crear** y **Modificar**. *Modificar* abre `NewMovementDialog(movement: ...)`
     precargado.
   - **Movimiento incompleto** → no se muestra resumen: se abre directo `NewMovementDialog`
     precargado, con monto, categoría o cuentas faltantes vacíos.
4. Errores (permiso de micrófono denegado, sin reconocimiento, el modelo falla): mensaje claro
   y el usuario queda en la pantalla de origen; el flujo manual no se ve afectado.

### Crear desde el resumen

El diálogo de resumen llama directo a `movementsRepository.create(...)` con los datos del
`Movement` (es exactamente lo que hace `submit()` hoy en `NewMovementDialog`, no hay lógica
extra que extraer). El resumen solo se muestra con un movimiento completo, así que no hace falta
repetir las validaciones del formulario.

### Dónde va el botón

En todos los lugares de [home.dart](../../../lib/views/home/home.dart) donde hoy está el `+` de
movimientos (dashboard y pestañas de cuenta; es el mismo `FloatingActionButton`). No va en
`account_list.dart`, cuyo `+` crea cuentas.

### Cambios en `NewMovementDialog`

Un único parámetro nuevo, o reutilizar `movement` distinguiendo "editar existente" de
"precargar nuevo" (por ejemplo con un parámetro `prefill`), para que **Modificar** no dispare la
lógica de edición (remove + create). Tratar `category == ''` como sin categoría
(`selectedCategory = null`).

Trampa a cuidar: `getCategories()` hace `selectedCategory = selected` (null por defecto) cada
vez que llegan las categorías, y `getAccounts()` precarga el formulario de forma asíncrona. La
precarga desde la IA tiene que aplicarse **después** de que carguen cuentas y categorías, o la
categoría precargada se pisa con `null`.

## Plataforma

- iOS: agregar `NSMicrophoneUsageDescription` y `NSSpeechRecognitionUsageDescription` al
  `Info.plist` (textos en español). Los paquetes de IA requieren Xcode 26 / iOS 26 con Apple
  Intelligence activado y el modelo descargado; el deployment target puede tener que subir según
  lo que pidan los paquetes (verificar en el spike).
- Contexto limitado (~4.096 tokens): el prompt lleva solo categorías, cuentas y la frase.
- Una sola generación a la vez; `speech_to_text` corta en 1 minuto en iOS (irrelevante para
  frases cortas).

## Regla de versiones

Ante **cualquier** cambio de versión (Flutter, Dart, Xcode, deployment target de iOS o versión
de un paquete), quien construye **frena y avisa al usuario antes de hacerlo**, con el motivo y el
impacto, para que lo valide. Subir el deployment target hasta iOS 26 es aceptable para el
usuario siempre que lo valide; subir Flutter o Dart también, con la misma validación. Si una de
las dos combinaciones A/B no compila, se sigue con la que funcione (la comparación queda en una).

## Spike previo (descartable)

Antes de implementar, un spike corto en el iPhone 17 Pro para validar:

1. Que el proyecto compila con los paquetes (Flutter 3.27, Dart ≥ 3.2, Xcode 26).
2. Qué tan bien interpreta español rioplatense ("lucas", "mil", "ayer al mediodía").
3. Fechas relativas: si el modelo las calcula bien o hay que resolverlas en Dart.
4. Que el esquema estructurado se respeta en ambas combinaciones (A y B).
5. La disponibilidad (`isAvailable`) en un teléfono sin la feature (o simulándolo).

## Resultados del spike

Hecho el 2026-11-14 en un iPhone 17 Pro (iOS 27.0), con Flutter 3.50.0 / Dart 3.14, 12 frases
por prueba y las dos combinaciones. Datos: ambos paquetes compilan y corren; el modelo de Apple
y el de `system_llm` (que usa el mismo modelo del sistema) reportan disponible y soportan
`es-Latn-419`. El simulador **no** sirve: la generación falla con `ModelManagerError 1001`.

**Versiones (aprobadas por el usuario).** `speech_to_text` 7.5.0 y `system_llm` 0.2.0 exigen
Flutter ≥ 3.44, así que se subió Flutter a 3.50.0 y todas las dependencias directas a su última
versión (commit aparte `d0e5884`). Flutter migró el proyecto iOS: deployment target 12 → 15.

**Voz.**
- `speech_to_text` con `onDevice: true`: arranca en ~1,6 s, entrega parciales en vivo, dígitos
  ("Gasté 100 pesos en Carrefour") y **corta solo** a los ~3 s de silencio (`pauseFor`). La primera
  sesión tras abrir la app puede tardar ~3 s y terminar con `error_no_match`: hay que manejarlo.
  `es_AR` no figura en `locales()` pero transcribe bien.
- `system_llm.listen`: devuelve el texto final con dígitos, **sin parciales** y **sin detectar el
  fin del habla** (con silencio tardó 47,7 s; con "Sys stop" volvió enseguida, 5,1 s en total).
  Sirve solo con un botón "Listo".

**Modelos.** ~1,4 a 3 s por frase (la primera de Apple en frío, 5 s). Los dos son comparables;
Apple restringe los valores (`oneOf`) durante la generación y alucinó menos cuentas.
Hallazgos sobre el prompt (tres iteraciones):
1. Los ejemplos con valores concretos **contaminan**: el modelo copió montos y tasas del ejemplo.
   No se usan ejemplos con valores.
2. Pedir números directamente produce montos inventados ("gasté lucas" → 20), tasas inventadas y,
   en `system_llm`, montos en letras. **Solución adoptada: campos de evidencia.** El modelo copia
   las palabras exactas de la frase (`amountText`, `rateText`, `categoryText`, `dateText`) y Dart
   verifica que estén en la transcripción y convierte "cincuenta mil" a número. Lo que no está
   en la frase se toma como no entendido (monto 0, categoría vacía).
3. Pedir **ids** de categoría salió mal (casi todo cayó en un mismo id); pedir el **nombre** exacto
   de la lista funcionó mucho mejor, y en Apple queda restringido a la lista real.
4. La fecha relativa ("ayer", "anteayer") la calcula bien o mal según el prompt: no es confiable.
   Se resuelve en Dart a partir de `dateText`.
5. El tipo (gasto/ingreso/transferencia) salió bien en las 12 frases con reglas explícitas en el
   prompt y sin ejemplos.

**Decisión de diseño que sale del spike: el modelo extrae y clasifica, Dart resuelve y valida.**
- Monto y tasa: `parseSpanishNumber(evidencia)` sobre texto verificado. "lucas" sin número delante
  no es un monto.
- Fecha: `dateText` → parser en Dart (hoy, ayer, anteayer, mediodía, "a las N"…); sin `dateText`, ahora.
- Categoría: si la frase nombra exactamente una categoría del tipo, gana esa (determinista); si
  no, el nombre que devuelve el modelo, solo si es de la lista **y** su `categoryText` está en la
  frase. Si no, vacía (incompleto). Esto cumple "no adivinar lo obligatorio".
- Cuentas: si la frase nombra una cuenta, esa; si dice una moneda con una sola cuenta de esa
  moneda, esa; en transferencias la dirección la da el modelo. Una cuenta que el modelo "adivinó"
  sin que la frase la mencione no vale (en transferencia queda incompleto; en gasto/ingreso se
  usa el fallback del diseño).
- Combinación POC: la voz usa `speech_to_text` (`onDevice: true`, `pauseFor` ~1,5–2 s); `system_llm`
  queda como segundo proveedor de voz y de LLM detrás de las mismas interfaces.

Errores que el spike no resolvió y quedan para la comparación final: algunas categorías
equivocadas con confianza en `system_llm`, la tasa cuando se dice "a 1480" (a veces cita "a pesos"
como evidencia) y la elección de cuenta en ingresos.

## Documentación a actualizar (misma entrega que el código)

- `docs/architecture.md` o doc nuevo del patrón de proveedores intercambiables.
- `docs/features/movements.md`: asistente de voz, esquema de IA y aviso "si cambiás `Movement`".
- `docs/ui-patterns.md`: segundo FAB y hoja de voz, si define un patrón nuevo.
- `docs/conventions.md`: dependencias nativas/permisos en `Info.plist`, si corresponde.

## Qué queda a criterio de quien construye

- Nombres de archivos y carpetas (siguiendo [conventions.md](../../conventions.md)).
- Estilo visual del segundo FAB y de la hoja (siguiendo [ui-patterns.md](../../ui-patterns.md)).
- Textos exactos de los mensajes de error y de las descripciones de permisos.
- Detección de silencio (umbral) y duración máxima de escucha.
- Redacción del prompt de sistema e instrucciones al modelo (iterar durante el POC).
- Cómo se cablea `isAvailable()` a la UI sin parpadeo del botón al abrir la pantalla.
