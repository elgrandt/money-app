# Voice AI Movement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user create a movement by speaking a natural-language sentence; an on-device model interprets it, and the app shows a summary to create or modify it.

**Architecture:** A single `MovementVoiceAssistant` interface ("voice in, `Movement` out") hides the pipeline. Today's only implementation, `TranscribeThenParseAssistant`, composes a `SpeechProvider` and an `AiProvider`; each has two implementations (package A `system_llm`, package B `apple_foundation_models` + `speech_to_text`) picked by constants for the POC. The result is a real `Movement` with defaults and fallbacks applied; "not understood" is encoded as empty values the existing dialog already understands.

**Tech Stack:** Flutter 3.27 / Dart ≥ 3.2.2, `get_it`, `apple_foundation_models` 0.5.2, `speech_to_text` 7.5.0, `system_llm` 0.2.0 (versions verified on pub.dev on 2026-11-14; the spike may change them).

**Spec:** [2026-11-14-voice-ai-movement-design.md](../specs/2026-11-14-voice-ai-movement-design.md)

## Global Constraints

- **Version rule (spec):** before changing **any** version (Flutter, Dart, Xcode, iOS deployment target, any package) **stop and tell the user** the reason and impact, and wait for their validation. Raising the iOS target up to 26 is acceptable to the user only after they validate it. If one of the two combinations does not compile, continue with the one that does.
- **Language:** code identifiers, logs and plans in English; UI strings in Spanish (`es_AR`); chat with the user in Spanish.
- **No tests by policy:** do not create test files. Verification = `flutter analyze` (baseline: **79 issues** after the Flutter 3.50 upgrade, all pre-existing; this work must add none) + manual check on the user's iPhone with `flutter run` + throwaway scripts under `/tmp` (never committed).
- **Git:** never commit to `master`; work on `feature/voice-ai-movement` (confirm with `git branch --show-current` before each commit). Commit only when the user says so. Commit messages: imperative, capitalized, no type prefix, ~50 chars, ending with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- **Meta-rule:** new patterns (providers folder `lib/services/voice_assistant/`, the `*.sheet.dart` suffix) are documented in the same change. If something is not covered by the spec or an existing pattern, stop and ask.
- **Code style ([coding-style.md](../../coding-style.md)):** 2-space indent, single quotes, no leading blank line, `${ expr }` with inner spaces, `{ a, b }` brace spacing for named params, **no code comments**, member order attributes → getters → constructor → lifecycle → logic → `build` → `buildX`, short methods, no magic numbers, imports always at the top.
- **Scope (spec):** iOS only; no runtime provider picker; no creation of categories or accounts from voice; the `+` buttons stay intact; the AI button is hidden when `isAvailable()` is false.
- **Field rules (spec):** model receives accounts `{id, name, currency}` and categories `{id, name}` per type and **returns exact names** (the spike showed ids are unreliable) plus **evidence text** copied from the sentence (`amountText`, `rateText`, `dateText`, `categoryText`); Dart verifies the evidence is in the transcript and resolves numbers, dates, categories and accounts itself. Defaults: type `REMOVE`, date now, description empty (max 3 words). `amount` and `category` are never guessed. Expense/Income account fallback order: named account → screen account **if** its currency matches the said currency (or none said) → first account with the said currency → first account. Transfer: both accounts and (if currencies differ) the rate are mandatory, no account fallback. The model returns the rate as spoken; **Dart** decides multiply/divide with `isRateInverse`.
- **Copy (exact, plan's call):** sheet `Te escucho…`, `Escuchando…`, `Interpretando…`, buttons `Listo`, `Cancelar`; summary title `Resumen del movimiento`, buttons `Crear`, `Modificar`; errors `No escuché nada. Intentá de nuevo.`, `Necesito permiso de micrófono y de reconocimiento de voz.`, `No pude interpretar el movimiento.`; Info.plist: microphone `Money usa el micrófono para crear movimientos con tu voz.`, speech `Money usa el reconocimiento de voz para entender el movimiento que dictás.`

## Review Focus

- A model id that exists but belongs to a category of another movement type, or to an account that does not exist, must be treated as not understood (never crash). Pinned in Task 2 Step 2.
- A transfer with the same account as source and target, or a cross-currency transfer without a rate, must end up incomplete. Pinned in Task 2 Step 2.
- Garbage input: empty transcript, zero or negative amount, unparsable date, description longer than 3 words. Pinned in Task 2 Step 2 (mapper) and Task 5 Step 5 (empty transcript).
- Prefilled category/accounts must survive the dialog's asynchronous loading. Pinned in Task 4 Step 3.
- Permission denied, user cancelling mid-listening, and the assistant being unavailable must leave the app usable with the manual `+` flow intact. Pinned in Task 5 Step 5.

---

### Task 1: Spike and version gate (throwaway code)

**Files:**
- Modify: `pubspec.yaml`, `ios/Podfile`/`ios/Runner.xcodeproj/project.pbxproj` (only if the user approves a version change), `ios/Runner/Info.plist`
- Create then delete: `lib/spike_voice.dart` (throwaway, never committed)
- Modify: [the spec](../specs/2026-11-14-voice-ai-movement-design.md) (new section `## Resultados del spike`)

**Interfaces:**
- Produces: written findings that later tasks rely on: exact working package versions, required iOS target, the real API calls of each package, and the date strategy (ISO string vs relative day + time).

- [x] **Step 1: Create the branch.** Run `git checkout -b feature/voice-ai-movement`; confirm with `git branch --show-current`.
- [x] **Step 2: Read each package's requirements** (Dart/Flutter SDK constraints, iOS minimum in the podspec, required Xcode) for the three packages and compare with Flutter 3.27 / Dart ≥ 3.2.2 / iOS 12 / the Xcode installed (`xcodebuild -version`). **Stop and report this table to the user in Spanish and wait for their decision before changing anything.**
- [x] **Step 3: After approval, add the dependencies** with the approved versions to `pubspec.yaml`, run `flutter pub get` and `pod install` in `ios/`. Report any resolution failure to the user instead of working around it.
- [x] **Step 4: Add the two Info.plist keys** `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` with the exact copy above.
- [x] **Step 5: Build the throwaway `lib/spike_voice.dart`** (a screen reachable by temporarily replacing `/` in `main.dart` routes) with buttons to run: (a) package B availability + `respondAs` on typed text, (b) package A `availability` + `generateObject` on typed text, (c) each package's speech recognition with partial results and `es_AR`. Use the two example sentences from the spec plus `"cambié quinientos dólares a 1550 pesos"` and `"gasté lucas en el súper"`.
- [x] **Step 6: Run on the user's iPhone** (`flutter run -d <device>`) and answer the five spike questions of the spec (compiles, Rioplatense Spanish quality, relative dates, structured schema respected in A and B, availability on an unsupported device or simulated).
- [x] **Step 7: Record findings** in the spec's `## Resultados del spike`, including the final date strategy: ISO local string `yyyy-MM-ddTHH:mm` (default assumed by Task 2) or a relative-day + time pair. Delete `lib/spike_voice.dart` and restore `main.dart` routes. Verify `flutter analyze` reports **79 issues** and `git status` shows only `pubspec.*`, iOS files and the spec.
- [ ] **Step 8: Present findings to the user and wait for go/no-go.** If the date strategy is not ISO, adapt `AiMovementFields.dateTime` in Task 2 accordingly before starting it.
- [ ] **Step 9: Commit** (when the user says so) the dependency, iOS and spec changes.

### Task 2: Contracts, schema and mapper (pure logic)

**Files:**
- Create: `lib/services/voice_assistant/movement_prompt_context.dart`, `lib/services/voice_assistant/movement_ai_schema.dart`, `lib/services/voice_assistant/spanish_text_parsing.dart` (added after the spike: the model extracts evidence text and Dart resolves it)
- Modify: [movement.model.dart](../../../lib/models/movement.model.dart) (extension), [utils.service.dart](../../../lib/services/utils.service.dart), [new_movement.dialog.dart:59-62](../../../lib/views/movements/new_movement.dialog.dart#L59-L62) (getter delegates), [movements.md](../../features/movements.md)

**Interfaces:**
- Produces:
  - `class MovementPromptContext { final DateTime now; final List<Account> accounts; final Map<MovementType, List<Category>> categoriesByType; final Account? screenAccount; }` (`accounts` ordered by `sortIndex`, non-deleted).
  - `class AiMovementFields { MovementType? type; Currency? currency; String? description; String? amountText; String? rateText; String? dateText; String? categoryText; String? categoryName; String? accountName; String? sourceAccountName; String? targetAccountName; factory AiMovementFields.fromJson(Map<String, Object?> json); }` (tolerant: wrong types, `NONE` and empty strings become null; trailing garbage in text values is ignored).
  - `const Map<String, Object?> movementJsonSchema` (JSON Schema describing `AiMovementFields`, field descriptions in English, enum values `REMOVE|ADD|TRANSFER`, `ARS|USD|EUR|NONE`; all fields are strings because `system_llm` has no decimals or enums, and package B narrows `categoryName`/`accountName`/`sourceAccountName`/`targetAccountName` to `oneOf` the real names plus empty).
  - `String buildMovementInstructions(MovementPromptContext context)` (system prompt validated in the spike: rules for `type`, evidence fields copied exactly from the sentence and empty when absent, names copied from the lists, `description` max 3 words, current date-time, accounts and categories JSON; **no examples with concrete values**, they contaminate the answer).
  - `int? parseSpanishNumber(String text)`, `bool isGrounded(String transcript, String evidence)` (accent- and case-insensitive substring, empty evidence is not grounded), `DateTime? parseSpanishDateTime(String text, DateTime now)` (hoy, ayer, anteayer/antes de ayer, mediodía, medianoche, `a las N`, de la mañana/tarde/noche), all in `spanish_text_parsing.dart`. `parseSpanishNumber` handles digits with `.`/`,` separators, words up to millions, `mil`, `N lucas`; a bare `lucas` is not a number.
  - `Movement buildMovementFromAi(AiMovementFields fields, String transcript, MovementPromptContext context, bool Function(Currency source, Currency target) isRateInverse)`.
  - Extension `MovementCompleteness on Movement` with `bool get isIncomplete`.
  - `bool UtilsService.isRateInverse(Currency source, Currency target)`.
- Consumes: `Movement`, `Account`, `Category`, `Currency` models.

- [ ] **Step 1: Implement `UtilsService.isRateInverse`** as `source != target && convertCurrencies(1, source, target) < 1` and make the dialog's `isRateInverse` getter call it. The mapper file must stay pure Dart (no Flutter imports) so it can run under `dart run`.
- [ ] **Step 2: Write the throwaway check `/tmp/voice_mapper_check.dart`** (not committed) with assertions, using accounts `En mano` ARS (id 1, sortIndex 0), `Santander` ARS (id 2), `Cuenta en dolares` USD (id 3), and categories `Supermercados` (REMOVE), `Silvia` (REMOVE), `Transporte` (REMOVE), `Sueldo` (ADD), `Cambio` (TRANSFER). `parseSpanishNumber` (all must hold; validated in the spike): `cien`→100, `50 mil`→50000, `cincuenta mil`→50000, `doscientos mil`→200000, `3500`→3500, `1.550`→1550, `1550 pesos`→1550, `dos mil quinientos`→2500, `treinta y dos mil`→32000, `3 lucas`→3000, `mil`→1000, `un millón`→1000000, `veinticinco`→25, empty and `lucas`→null. `isGrounded('Gasté cien pesos','cien')` true, with `'cincuenta'` or `''` false. `parseSpanishDateTime` with `now` 2026-11-14 21:00: `ayer`→2026-11-13 (time kept), `ayer al mediodía`→2026-11-13 12:00, `anteayer`→2026-11-12, `hoy a las 15`→2026-11-14 15:00, empty or `basura`→null. Then `buildMovementFromAi` and `isIncomplete`:
  - `Gasté cien pesos en Carrefour` with `{type REMOVE, amountText 'cien pesos', currency ARS, description 'Carrefour', categoryText 'Carrefour', categoryName 'Supermercados'}` → `REMOVE`, amount 100, description `Carrefour`, category `Supermercados`, source = account 1, `creationDate` within 1 s of `now`, `isIncomplete == false`.
  - `Ayer al mediodía le pagué a Silvia cincuenta mil pesos` with the model wrongly answering `categoryName 'Supermercados'` and `categoryText 'Silvia'` → category `Silvia` (an exact mention of a category name in the transcript wins), amount 50000, `creationDate == DateTime(2026, 11, 13, 12)`, type `REMOVE`.
  - Not grounded evidence is dropped: `amountText '50 pesos'` on a transcript without it → amount 0 and `isIncomplete`; `Gasté mil pesos` with `categoryText 'Supermercados'` → category `''` and `isIncomplete`; `Gasté lucas en el súper` with `amountText 'lucas'` → amount 0.
  - Category `categoryName` not in the list for the type (for example `Sueldo` while type is `REMOVE`, or an unknown name) → `category == ''` and `isIncomplete`.
  - Accounts for expense/income: a name mentioned in the transcript wins (`Santander`); `dólares` with a single USD account → account 3; otherwise the fallback chain (screen account if its currency matches, first account of the said currency, first account). An `accountName` the model returns that is not in the list or not mentioned in the transcript is ignored. Type `ADD` fills `target`, not `source`.
  - `description 'uno dos tres cuatro'` → `'uno dos tres'`; an unparsable `dateText` → within 1 s of `now`.
  - `TRANSFER` `Cambié quinientos dólares a 1550 pesos` with `sourceAccountName 'Cuenta en dolares'`, `rateText '1550 pesos'`, `targetAccountName 'En mano'` (not mentioned, two ARS accounts) → `target == null`, `isIncomplete`. With the model's `targetAccountName` equal to a name that is mentioned (`Transferí cien mil pesos de Santander a En mano`) → source 2, target 1, same currency, not incomplete.
  - `TRANSFER` USD→ARS with `isRateInverse` false and `rateText '1550'` → `conversionRate == 1550`; with `isRateInverse` true → `conversionRate == 1 / 1550`. Cross-currency without grounded `rateText` (for example the model cites `a pesos`) → `conversionRate == null`, `isIncomplete`; missing source → `source == null`, `isIncomplete`; same account for source and target → `target == null`, `isIncomplete`.
- [ ] **Step 3: Run it to see it fail:** `dart run --packages=.dart_tool/package_config.json /tmp/voice_mapper_check.dart` → fails (symbols missing).
- [ ] **Step 4: Implement** the context, `AiMovementFields.fromJson`, `movementJsonSchema`, `buildMovementInstructions`, the three parsing helpers, `buildMovementFromAi` and the extension, following the Global Constraints field rules and the spec's "Resultados del spike" (the model extracts and classifies, Dart resolves and validates: category exact mention first, then the model's name only if it is in the list and its `categoryText` is grounded; accounts by mention or by a unique account of the said currency). `isIncomplete` is true when `amount <= 0`, or `category.isEmpty`, or a `TRANSFER` lacks `source`/`target`, or its currencies differ and `conversionRate == null`.
- [ ] **Step 5: Run the check again** → all assertions pass; `flutter analyze` → 79 issues.
- [ ] **Step 6: Document** in `docs/features/movements.md`: voice assistant overview, the encoding of "not understood" values, and "if you change `Movement`, review `movement_ai_schema.dart`".
- [ ] **Step 7: Commit** (when the user says so).

### Task 3: Providers, composed assistant and configuration

**Files:**
- Create: `lib/services/voice_assistant/movement_voice_assistant.dart`, `speech_provider.dart`, `ai_provider.dart`, `transcribe_then_parse_assistant.dart`, `apple_foundation_models_ai_provider.dart`, `system_llm_ai_provider.dart`, `speech_to_text_provider.dart`, `system_llm_speech_provider.dart`, `voice_assistant_config.dart` (all in `lib/services/voice_assistant/`)
- Modify: [main.dart:30-33](../../../lib/main.dart#L30-L33), [architecture.md](../../architecture.md), [conventions.md](../../conventions.md)

**Interfaces:**
- Consumes: Task 2 contracts.
- Produces:
  - `abstract class MovementVoiceAssistant { Future<bool> isAvailable(); VoiceSession start(MovementPromptContext context); }`
  - `abstract class VoiceSession { Stream<String> get partialTranscripts; Future<Movement> get result; Future<void> stop(); Future<void> cancel(); }`
  - `enum VoiceAssistantFailure { permissionDenied, nothingHeard, interpretationFailed }` and `class VoiceAssistantException implements Exception { final VoiceAssistantFailure failure; }`; `result` completes with this exception on failure.
  - `abstract class SpeechProvider { Future<bool> isAvailable(); SpeechSession start(); }`, `abstract class SpeechSession { Stream<String> get partialTranscripts; Future<String> get transcript; Future<void> stop(); Future<void> cancel(); }`
  - `abstract class AiProvider { Future<bool> isAvailable(); Future<AiMovementFields> parse(String text, MovementPromptContext context); }`
  - `class TranscribeThenParseAssistant implements MovementVoiceAssistant` with constructor `({ required SpeechProvider speech, required AiProvider ai, required bool Function(Currency, Currency) isRateInverse })`; available only if both providers are.
  - `enum AiProviderChoice { appleFoundationModels, systemLlm }`, `enum SpeechProviderChoice { speechToText, systemLlm }`, `const AiProviderChoice aiProviderChoice`, `const SpeechProviderChoice speechProviderChoice`, `MovementVoiceAssistant buildMovementVoiceAssistant()`.

- [ ] **Step 1: Write the interfaces and `VoiceAssistantException`** with the exact signatures above.
- [ ] **Step 2: Implement `TranscribeThenParseAssistant`:** the session forwards the speech partials, and on `stop()` waits for `transcript`; an empty/blank transcript fails with `nothingHeard`; otherwise calls `ai.parse` and maps with `buildMovementFromAi(fields, transcript, context, isRateInverse)`; any provider error becomes `interpretationFailed` (or `permissionDenied` if the speech provider reports it). `cancel()` cancels the speech session and completes `result` with no further work.
- [ ] **Step 3: Implement the four providers** using the API calls recorded in the spike findings (Task 1 Step 7). The AI providers adapt `movementJsonSchema` to their package format, pass `buildMovementInstructions` as system instructions, check `isAvailable()` through the package's availability call, and never throw from `isAvailable()` (return false). The speech providers request `es_AR`, and map denied permissions to `permissionDenied`. Spike-validated settings: `speech_to_text` with `SpeechListenOptions(partialResults: true, onDevice: true, localeId: 'es_AR', pauseFor: ~1.5-2 s, listenFor: 30 s)`, `error_no_match` mapped to `nothingHeard`, and `contextualPhrases` fed with category and account names; `system_llm` speech returns only the final text, has no partials and **never ends by itself** (45 s cap), so its session must end on `stop()` via `stopListening()`.
- [ ] **Step 4: Write `voice_assistant_config.dart`** with the constants set to package B (`appleFoundationModels` + `speechToText`) and a `switch`-based `buildMovementVoiceAssistant()` wiring `UtilsService.isRateInverse` from `GetIt`. Register it in `initializeServices()` as `GetIt.instance.registerSingleton<MovementVoiceAssistant>(buildMovementVoiceAssistant())` after `UtilsService`.
- [ ] **Step 5: Document** the provider pattern in `docs/architecture.md` (new "Voice assistant" section: interface, composed implementation, constants, how to add a provider) and the new folder in `docs/conventions.md`.
- [ ] **Step 6: Verify:** `flutter analyze` → 79 issues; `flutter run` starts the app and the existing flows still work (no runtime use of the assistant yet).
- [ ] **Step 7: Commit** (when the user says so).

### Task 4: Prefill support in the new-movement dialog

**Files:**
- Create: `lib/views/movements/movement_sentence.dart`
- Modify: [new_movement.dialog.dart](../../../lib/views/movements/new_movement.dialog.dart), [movement_details.dialog.dart](../../../lib/views/movements/movement_details.dialog.dart)

**Interfaces:**
- Produces:
  - `NewMovementDialog({ super.key, this.selectedAccount, this.movement, this.prefill })` where `final Movement? prefill`; `isEditing` stays `movement != null`, so `prefill` never triggers remove + create.
  - `class MovementSentence extends StatelessWidget { final Movement movement; }` (the bold-span sentence now private to the details dialog, extracted so the summary can reuse it).

- [ ] **Step 1: Extract `MovementSentence`** from `getText()` and `buildText()` of `MovementDetailsDialog` without changing text or styling; the details dialog uses it.
- [ ] **Step 2: Verify the refactor manually:** open details of an expense, an income, a same-currency transfer and a cross-currency transfer; sentences are identical to before.
- [ ] **Step 3: Add `prefill`.** Keep it in a field and apply it **once**, only after both accounts and categories have loaded (the dialog sets `selectedCategory = selected` on every categories load, which would overwrite an earlier prefill). Applying: type, amount (controller and field), description, `creationDate ?? now`, category (`''` → `null`), `source`/`target` (null side falls back to the screen account or the first account; a null `conversionRate` leaves the rate field at `0`, otherwise derived like `fillFormDataWithMovement`). `canSubmit` already blocks submission without amount/category.
- [ ] **Step 4: Verify manually** by temporarily opening `NewMovementDialog(prefill: ...)` from the `+` handler with (a) a complete movement and (b) one with `amount 0`, `category ''` and a null `target`; fields appear filled, the category survives, missing fields are empty, editing an existing movement still works. Remove the temporary code; `flutter analyze` → 79 issues.
- [ ] **Step 5: Commit** (when the user says so).

### Task 5: Voice sheet, summary dialog and wiring

**Files:**
- Create: `lib/views/movements/voice_listening.sheet.dart`, `lib/views/movements/voice_movement_summary.dialog.dart`
- Modify: [navbar.dart:7-10](../../../lib/views/generics/navbar.dart#L7-L10) (`floatingActionButton` becomes `Widget?`), [home.dart](../../../lib/views/home/home.dart), [ui-patterns.md](../../ui-patterns.md), [conventions.md](../../conventions.md) (`*.sheet.dart` suffix), [movements.md](../../features/movements.md)

**Interfaces:**
- Consumes: `MovementVoiceAssistant`, `VoiceSession`, `VoiceAssistantException`, `MovementPromptContext`, `isIncomplete`, `MovementSentence`, `NewMovementDialog(prefill:)`.
- Produces:
  - `VoiceListeningSheet({ super.key, required MovementPromptContext promptContext })` shown with `showModalBottomSheet<Movement?>`; pops the interpreted `Movement` or `null`.
  - `enum VoiceSummaryResult { created, modify }`; `VoiceMovementSummaryDialog({ super.key, required Movement movement })` shown with `showDialog<VoiceSummaryResult?>`.

- [ ] **Step 1: Write `VoiceListeningSheet`:** title `Te escucho…`; starts the session in `initState`; shows `Escuchando…` with an animation and the live partial transcript when the stream emits; `Listo` calls `stop()` and shows `Interpretando…`; `Cancelar` and sheet dismissal call `cancel()`; on `VoiceAssistantException` it shows the matching error copy in the sheet with a `Cerrar` action and pops `null`. Guard every `setState` with `mounted`.
- [ ] **Step 2: Write `VoiceMovementSummaryDialog`** following the dialog shell pattern: title `Resumen del movimiento`, `MovementSentence`, description and date blocks like the details dialog, `Crear` (calls `databaseService.movementsRepository.create(...)` with the movement's fields, `conversionRate ?? 0`, then pops `created`) and `Modificar` (pops `modify`).
- [ ] **Step 3: Change `Navbar.floatingActionButton` to `Widget?`.** In `home.dart` build a `Column(mainAxisSize: MainAxisSize.min)` with the AI button (`Icons.auto_awesome`, same style as the `+`, `FloatingActionButton.small`, distinct `heroTag`s on both buttons) above the `+`, shown only when `accounts` is non-empty and the assistant's `isAvailable()` (loaded once in `initState`, stored in a `bool`) is true.
- [ ] **Step 4: Write `openVoiceMovementFlow()` in `home.dart`:** build the `MovementPromptContext` (now, non-deleted accounts by `sortIndex`, `categoriesByType`, current tab's account) → sheet → if result is `null` stop; if `isIncomplete` open `NewMovementDialog(prefill: movement, selectedAccount: ...)`; otherwise open the summary and on `modify` open `NewMovementDialog(prefill: movement, selectedAccount: ...)`.
- [ ] **Step 5: Manual end-to-end on the iPhone with package B, then switch the constants to package A and repeat:**
  - `"Gasté cien pesos en Carrefour"` → summary: Gasto, 100, `Carrefour`, category `Supermercados` (or the closest), now; `Crear` shows the movement in the list and updates the balance.
  - Same sentence → `Modificar` → dialog prefilled; submitting creates exactly one movement.
  - `"Ayer al mediodía le pagué a Silvia cincuenta mil pesos"` → 50.000, yesterday 12:00, category `Silvia`, no description.
  - `"Gasté en el súper"` (no amount) → straight to the dialog with category filled and amount empty.
  - `"Pasé cien dólares a pesos"` (no rate) → straight to the dialog, rate empty; `"Cambié quinientos dólares a 1550 pesos"` → summary with the correct converted amount; the reverse direction (pesos → dólares) shows the inverse conversion correctly.
  - Silence then `Listo` → `No escuché nada. Intentá de nuevo.`; deny the permission in Settings → permission message; `Cancelar` mid-listening leaves the screen intact.
  - Temporarily make the assistant's `isAvailable()` return false → the AI button disappears and `+` still works; revert.
  - `flutter analyze` → 79 issues.
- [ ] **Step 6: Document** the second FAB and the voice sheet in `ui-patterns.md`, the `*.sheet.dart` suffix in `conventions.md`, and the flow in `movements.md`.
- [ ] **Step 7: Commit** (when the user says so).

### Task 6: POC comparison

**Files:**
- Modify: the spec (new section `## Resultados de la comparación`)

**Interfaces:**
- Consumes: the configuration constants of Task 3 and the flow of Task 5.
- Produces: a comparison table and a recommendation for the user to decide which implementation to keep.

- [ ] **Step 1: Run each combination** (A: `systemLlm` + `systemLlm`; B: `appleFoundationModels` + `speechToText`; mixed: `appleFoundationModels` + `systemLlm`, `systemLlm` + `speechToText`) against at least eight phrases covering expense, income, transfer same-currency, transfer cross-currency in both directions, relative dates, missing amount, missing category, and a named account.
- [ ] **Step 2: Record** per combination and phrase whether fields were correct, the incomplete cases routed correctly, and the perceived latency, in the spec.
- [ ] **Step 3: Present the table and a recommendation to the user in Spanish.** Removing the losing implementation is a separate decision for the user and is not part of this plan.
- [ ] **Step 4: Commit** (when the user says so).
