import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get_it/get_it.dart';
import 'package:googleai_dart/googleai_dart.dart' as gemini;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/services/ai.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
const String _model = String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-3.8-flash');
const Duration _requestTimeout = Duration(seconds: 15);
const Duration _totalTimeout = Duration(seconds: 25);
const int _maxHistoryPerCategory = 40;
const String _none = 'NONE';
const _weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

const String _localeId = 'es_AR';
const Duration _pauseFor = Duration(seconds: 5);
const Duration _listenFor = Duration(seconds: 30);
const Duration _finalResultGrace = Duration(milliseconds: 600);
const Duration _stopTimeout = Duration(seconds: 3);

const String _systemInstruction = '''
You are the voice-entry engine of a personal finance app used in Argentina (Spanish, es_AR). The user dictates ONE money movement. The sentence you receive comes from speech recognition: it may contain recognition mistakes, has no reliable punctuation, and writes numbers as digits or as words. Return ONE JSON object that follows the response schema. Never add commentary.

MOVEMENT TYPES
- REMOVE (expense): the user spends, pays, buys or loses money (gasté, pagué, compré, le pagué a alguien, me cobraron). Paying a person or a shop is always REMOVE.
- ADD (income): the user receives money (cobré, me pagaron, me depositaron, me devolvieron, sueldo).
- TRANSFER: money moves between two of the user's own accounts, or one currency is exchanged for another (transferí, pasé, mandé, cambié dólares, compré dólares con pesos).
- If you are unsure between REMOVE and TRANSFER choose REMOVE, unless two of the user's own accounts are involved. When nothing says otherwise the type is REMOVE.

AMOUNT
- "amount" is a positive number in the currency of the account involved, and 0 when the sentence states no amount. Never invent an amount.
- Argentine numbers use "." for thousands and "," for decimals. Speech recognition often writes thousands with a comma, so a comma followed by exactly three digits ("150,000", "1,500") is a thousands separator (150000, 1500). "2,50" is 2.5.
- Number words: "cien" 100, "mil" 1000, "cincuenta mil" 50000, "dos millones" 2000000. Slang: "lucas" are thousands ("3 lucas" is 3000, "una luca" is 1000, "lucas" alone is NOT an amount); "un palo" is 1000000; "mangos" and "pe" are pesos; "verdes", "dólares", "usd", "u\$s" are US dollars; "euros" are euros.
- The amount is what leaves the source account (for a transfer, the amount in the source currency).

CURRENCY
- "currency" is the currency of the amount as the sentence states or implies it: "pesos", "mangos" mean ARS; "dólares", "verdes", "usd" mean USD; "euros" mean EUR. For a TRANSFER it is the currency of the source amount. Use NONE when the sentence states no currency.

ACCOUNTS
- Use only names from the ACCOUNTS list, copied exactly. Speech recognition may distort a name ("a mano" probably means "En mano"): match by sound and meaning. When one name is contained in another ("Santander" and "Santander USD") pick the one the user said.
- A currency word ("pesos", "dólares", "usd", "euros") states the CURRENCY, not an account. Never choose "Cuenta en pesos" or "Cuenta en dólares" just because the sentence says "pesos" or "dólares". An account is named only when the sentence says its name or its distinctive part ("en Santander", "con Ualá", "de la cuenta exterior", "de la cuenta en dólares", "en mano").
- If a name is a prefix of another account name ("Santander" and "Santander USD"), the plain name means the plain account; "Santander USD" is chosen only when the user says "Santander USD" (or "Santander dólares").
- REMOVE: "account" is the account the money leaves. ADD: the account that receives it. Fill it ONLY when the sentence names an account; otherwise NONE. Never choose an account just to complete the answer: the app applies its own defaults using "currency".
- TRANSFER: "sourceAccount" is where the money leaves and "targetAccount" where it arrives; "account" is NONE. Fill each only when the user names it, or when exactly one account has the currency the user mentioned for that side; otherwise NONE (the app will ask the user). Never pick between several accounts of the same currency. When the user exchanges currencies ("dólares a pesos", a conversion rate) the two accounts have DIFFERENT currencies: "pasé 200 dólares de la cuenta exterior a Santander" ends in the peso account "Santander", not "Santander USD".
- "conversionRate" (only a TRANSFER between different currencies): the exchange rate exactly as the user said it (1550 in "cambié 500 dólares a 1550 pesos"). 0 if not said. Do not invert it and do not compute it.

CATEGORY
- Use only names from the CATEGORIES list of the chosen type, copied exactly, or NONE.
- Decide in this order: (1) the sentence names a category or says its words ("gym" is GYM, "le pagué a Silvia" is Silvia); (2) HISTORY: if the sentence mentions a shop, person or item that appears in the HISTORY list (ignore case and accents, the longest match wins), use the category it was used with most; (3) the meaning makes one category of the user's list obvious; (4) otherwise NONE.
- A category whose name starts with "Otro" or "Otros" ("Otros gastos", "Otros ingresos", "Otro") is a catch-all: NEVER choose it unless the user says that name. When in doubt use NONE: a wrong category is worse than a missing one.

DESCRIPTION
- At most 3 words naming the shop, person or thing paid ("Carrefour", "Farma City"). No verbs, amounts or dates.
- When the shop or item matches an entry of HISTORY, write it with the same spelling the user has there (capitalized naturally).
- It must NOT repeat the category or the name of any account: if the only useful word is the category ("gym" with category GYM) leave it empty. Use an empty string when there is nothing more to say.

DATE
- "dateTime" is a local timestamp "yyyy-MM-ddTHH:mm" resolved from NOW (given in the context).
- Fill it only when the sentence says a day or a time: "ayer", "anteayer", "el lunes" (the most recent past Monday), "hace dos días", "al mediodía" (12:00), "a la medianoche" (00:00), "a las 3 de la tarde" (15:00). If only a day is said keep the time of day of NOW; if only a time is said use today.
- Use an empty string when the sentence says no day or time.

OUTPUT RULES
- Use the text NONE for an account or category with no value, an empty string for empty text, and 0 for an unknown number.

EXAMPLES (illustrative; the user's real names are in the lists)
- "gasté cien pesos en carrefour" with HISTORY carrefour -> Supermercado: {"type":"REMOVE","amount":100,"description":"Carrefour","dateTime":"","category":"Supermercado","currency":"ARS","account":"NONE","sourceAccount":"NONE","targetAccount":"NONE","conversionRate":0}
- "ayer al mediodía le pagué a Silvia cincuenta mil pesos" with a category Silvia: {"type":"REMOVE","amount":50000,"description":"","dateTime":"<yesterday>T12:00","category":"Silvia","currency":"ARS","account":"NONE","sourceAccount":"NONE","targetAccount":"NONE","conversionRate":0}
- "me depositaron el sueldo doscientos mil pesos en Santander": {"type":"ADD","amount":200000,"description":"","dateTime":"","category":"<the salary category>","currency":"ARS","account":"Santander","sourceAccount":"NONE","targetAccount":"NONE","conversionRate":0}
- "gasté mil pesos": {"type":"REMOVE","amount":1000,"description":"","dateTime":"","category":"NONE","currency":"ARS","account":"NONE","sourceAccount":"NONE","targetAccount":"NONE","conversionRate":0}
- "transferí cien mil pesos de Santander a En mano": {"type":"TRANSFER","amount":100000,"description":"","dateTime":"","category":"NONE","currency":"ARS","account":"NONE","sourceAccount":"Santander","targetAccount":"En mano","conversionRate":0}
''';

class GeminiAIService implements AIService {
  var logger = GetIt.instance.get<Logger>();
  var utilsService = GetIt.instance.get<UtilsService>();
  final gemini.GoogleAIClient _client = gemini.GoogleAIClient(
    config: gemini.GoogleAIConfig.googleAI(authProvider: gemini.ApiKeyProvider(_apiKey, placement: gemini.AuthPlacement.header), timeout: _requestTimeout, retryPolicy: const gemini.RetryPolicy(maxRetries: 1, initialDelay: Duration(milliseconds: 500), maxDelay: Duration(seconds: 2))),
  );
  SpeechToText? _speech;
  Completer<String>? _transcript;
  Timer? _completionTimer;
  void Function(String text)? _onPartialTranscript;
  String _lastWords = '';
  int _listenId = 0;

  @override
  Future<bool> isAvailable() async {
    return Platform.isIOS && _apiKey.isNotEmpty;
  }

  @override
  Future<Movement> listen(
    MovementPromptContext context, {
    required void Function(String text) onPartialTranscript,
    required void Function() onListeningFinished,
  }) async {
    await cancel();
    var listenId = ++_listenId;
    _onPartialTranscript = onPartialTranscript;
    String transcript;
    try {
      transcript = await _capture(context);
    } finally {
      onListeningFinished();
    }
    logger.d('Voice transcript: ${ transcript.trim() }');
    if (transcript.trim().isEmpty) throw const AIException(AIFailure.nothingHeard);
    try {
      var movement = await _interpret(transcript, context).timeout(_totalTimeout);
      if (listenId != _listenId) throw const AIException(AIFailure.cancelled);
      logger.d('Voice movement: ${ movement.toString() } category=${ movement.category.toString() } description=${ movement.description.toString() } rate=${ movement.conversionRate.toString() }');
      return movement;
    } on AIException {
      rethrow;
    } on SocketException {
      throw const AIException(AIFailure.offline);
    } on http.ClientException {
      throw const AIException(AIFailure.offline);
    } on TimeoutException {
      throw const AIException(AIFailure.offline);
    } on gemini.TimeoutException {
      throw const AIException(AIFailure.offline);
    } on gemini.GoogleAIException catch (error) {
      logger.e('Gemini request failed: ${ error.message }');
      throw const AIException(AIFailure.interpretationFailed);
    } catch (error, stackTrace) {
      logger.e('Error interpreting voice movement', error: error, stackTrace: stackTrace);
      throw const AIException(AIFailure.interpretationFailed);
    }
  }

  @override
  Future<void> stop() async {
    var speech = _speech;
    if (speech != null && speech.isListening) await speech.stop();
    _scheduleCompletion(_stopTimeout);
  }

  @override
  Future<void> cancel() async {
    _listenId++;
    var speech = _speech;
    var wasAvailable = speech?.isAvailable ?? false;
    _fail(AIFailure.cancelled);
    if (speech != null && wasAvailable) await speech.cancel();
  }

  Future<String> _capture(MovementPromptContext context) {
    var transcript = Completer<String>();
    _transcript = transcript;
    _lastWords = '';
    _startRecognition(transcript, _contextualPhrases(context));
    return transcript.future;
  }

  List<String> _contextualPhrases(MovementPromptContext context) {
    var accountNames = context.accounts.map((account) => account.name);
    var categoryNames = context.categoriesByType.values.expand((categories) => categories).map((category) => category.name);
    return [...accountNames, ...categoryNames];
  }

  Future<void> _startRecognition(Completer<String> transcript, List<String> contextualPhrases) async {
    var speech = SpeechToText();
    _speech = speech;
    try {
      var available = await speech.initialize(onError: _handleError, onStatus: _handleStatus);
      if (transcript.isCompleted) {
        if (available) await speech.cancel();
        return;
      }
      if (!available) return _fail(AIFailure.permissionDenied);
      await speech.listen(
        onResult: _handleResult,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          onDevice: true,
          localeId: _localeId,
          pauseFor: _pauseFor,
          listenFor: _listenFor,
          contextualPhrases: contextualPhrases,
        ),
      );
    } catch (_) {
      _fail(AIFailure.interpretationFailed);
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    var transcript = _transcript;
    if (transcript == null || transcript.isCompleted) return;
    _lastWords = result.recognizedWords;
    _onPartialTranscript?.call(_lastWords);
    if (result.finalResult) _complete();
  }

  void _handleStatus(String status) {
    if (status == 'done') _scheduleCompletion(_finalResultGrace);
  }

  void _handleError(SpeechRecognitionError error) {
    if (error.errorMsg.contains('permission')) return _fail(AIFailure.permissionDenied);
    _scheduleCompletion(_finalResultGrace);
  }

  void _scheduleCompletion(Duration delay) {
    _completionTimer?.cancel();
    _completionTimer = Timer(delay, _complete);
  }

  void _complete() {
    var transcript = _transcript;
    if (transcript == null || transcript.isCompleted) return;
    _completionTimer?.cancel();
    transcript.complete(_lastWords);
  }

  void _fail(AIFailure failure) {
    var transcript = _transcript;
    if (transcript == null || transcript.isCompleted) return;
    _completionTimer?.cancel();
    transcript.completeError(AIException(failure));
  }

  Future<Movement> _interpret(String transcript, MovementPromptContext context) async {
    var response = await _client.models.generateContent(
      model: _model,
      request: gemini.GenerateContentRequest(
        systemInstruction: gemini.Content.text(_systemInstruction),
        contents: [gemini.Content.text(_buildUserPrompt(transcript, context))],
        generationConfig: gemini.GenerationConfig(
          temperature: 0,
          responseMimeType: 'application/json',
          responseSchema: _buildSchema(context),
        ),
      ),
    );
    var text = response.text;
    logger.d('Gemini response: $text');
    if (text == null) throw const AIException(AIFailure.interpretationFailed);
    return _buildMovement(jsonDecode(text) as Map<String, Object?>, context);
  }

  String _buildUserPrompt(String transcript, MovementPromptContext context) {
    var now = context.now;
    var offset = now.timeZoneOffset;
    var offsetText = '${ offset.isNegative ? '-' : '+' }${ offset.inHours.abs().toString().padLeft(2, '0') }:${ (offset.inMinutes.abs() % 60).toString().padLeft(2, '0') }';
    var accounts = context.accounts.map((account) => '- ${ account.name } (${ account.currency.name })').join('\n');
    var categories = MovementType.values.map((type) {
      var names = (context.categoriesByType[type] ?? []).map((category) => category.name).join(', ');
      return '- ${ type.name }: $names';
    }).join('\n');
    return 'NOW: ${ DateFormat("yyyy-MM-dd'T'HH:mm").format(now) } (${ _weekdays[now.weekday - 1] }), UTC$offsetText\n'
        'CURRENT SCREEN ACCOUNT (the app uses it as the default account): ${ context.screenAccount?.name ?? 'none (the dashboard is open)' }\n\n'
        'ACCOUNTS (name and currency, in the user\'s order):\n$accounts\n\n'
        'CATEGORIES by movement type:\n$categories\n\n'
        'HISTORY (descriptions the user has used for each category, with how many times, most used first):\n${ _buildHistory(context) }\n\n'
        'SENTENCE (speech recognition result): "${ transcript.trim() }"';
  }

  String _buildHistory(MovementPromptContext context) {
    var lines = <String>[];
    for (var type in MovementType.values) {
      for (var category in context.categoriesByType[type] ?? []) {
        var usages = context.descriptionUsages.where((usage) => usage.type == type && usage.category == category.name).toList();
        if (usages.isEmpty) continue;
        usages.sort((first, second) => second.uses.compareTo(first.uses));
        var descriptions = usages.take(_maxHistoryPerCategory).map((usage) => '${ usage.description } (${ usage.uses })').join(', ');
        lines.add('- ${ type.name } / ${ category.name }: $descriptions');
      }
    }
    return lines.isEmpty ? '(no history yet)' : lines.join('\n');
  }

  Map<String, dynamic> _buildSchema(MovementPromptContext context) {
    var categoryNames = [_none, ...context.categoriesByType.values.expand((categories) => categories).map((category) => category.name).toSet()];
    var accountNames = [_none, ...context.accounts.map((account) => account.name)];
    Map<String, dynamic> choice(List<String> values, String description) => {'type': 'STRING', 'enum': values, 'description': description};
    var properties = <String, dynamic>{
      'type': choice(MovementType.values.map((type) => type.name).toList(), 'REMOVE spends, ADD receives, TRANSFER moves money between the user own accounts'),
      'amount': {'type': 'NUMBER', 'description': 'positive amount in the account currency, 0 if the sentence states none'},
      'currency': choice([...Currency.values.map((currency) => currency.name), _none], 'currency of the amount as stated or implied, NONE if the sentence states none'),
      'description': {'type': 'STRING', 'description': 'at most 3 words, never the category or an account name, empty if nothing to add'},
      'dateTime': {'type': 'STRING', 'description': 'local yyyy-MM-ddTHH:mm only when the sentence says a day or time, else empty'},
      'category': choice(categoryNames, 'category name of the movement type or NONE'),
      'account': choice(accountNames, 'REMOVE: account the money leaves. ADD: account that receives it. Only when the sentence names it, else NONE. NONE for TRANSFER'),
      'sourceAccount': choice(accountNames, 'TRANSFER only: account the money leaves, else NONE'),
      'targetAccount': choice(accountNames, 'TRANSFER only: account the money arrives to, else NONE'),
      'conversionRate': {'type': 'NUMBER', 'description': 'exchange rate exactly as said by the user, 0 if not said'},
    };
    return {'type': 'OBJECT', 'properties': properties, 'required': properties.keys.toList(), 'propertyOrdering': properties.keys.toList()};
  }

  Movement _buildMovement(Map<String, Object?> json, MovementPromptContext context) {
    var type = MovementType.values.where((value) => value.name == json['type']).firstOrNull ?? MovementType.REMOVE;
    var categoryNames = (context.categoriesByType[type] ?? []).map((category) => category.name);
    var category = json['category'];
    var amount = (json['amount'] as num?)?.toDouble() ?? 0;
    var movement = Movement(
      type,
      (json['description'] as String?)?.trim() ?? '',
      amount > 0 ? amount : 0,
      category is String && categoryNames.contains(category) ? category : '',
      creationDate: DateTime.tryParse('${ json['dateTime'] }') ?? context.now,
    );
    if (type == MovementType.TRANSFER) {
      _fillTransferAccounts(movement, json, context);
      return movement;
    }
    var account = _resolveAccount(json, context);
    if (type == MovementType.REMOVE) {
      movement.source = account;
    } else {
      movement.target = account;
    }
    return movement;
  }

  Account? _resolveAccount(Map<String, Object?> json, MovementPromptContext context) {
    var named = _findAccount(json['account'], context.accounts);
    if (named != null) return named;
    var currency = Currency.values.where((value) => value.name == json['currency']).firstOrNull;
    var screenAccount = context.screenAccount;
    if (screenAccount != null && (currency == null || screenAccount.currency == currency)) return screenAccount;
    return context.accounts.where((account) => account.currency == currency).firstOrNull ?? context.accounts.firstOrNull;
  }

  Account? _findAccount(Object? name, List<Account> accounts) {
    return accounts.where((account) => account.name == name).firstOrNull;
  }

  void _fillTransferAccounts(Movement movement, Map<String, Object?> json, MovementPromptContext context) {
    var source = _findAccount(json['sourceAccount'], context.accounts);
    var target = _findAccount(json['targetAccount'], context.accounts);
    if (source != null && source == target) target = null;
    movement.source = source;
    movement.target = target;
    var rate = (json['conversionRate'] as num?)?.toDouble() ?? 0;
    if (source == null || target == null || source.currency == target.currency || rate <= 0) return;
    movement.conversionRate = utilsService.isRateInverse(source.currency, target.currency) ? 1 / rate : rate;
  }
}
