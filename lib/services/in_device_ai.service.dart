import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:apple_foundation_models/apple_foundation_models.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/repositories/movements.repository.dart';
import 'package:money/services/ai.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

const String _localeId = 'es_AR';
const Duration _pauseFor = Duration(seconds: 5);
const Duration _listenFor = Duration(seconds: 30);
const Duration _finalResultGrace = Duration(milliseconds: 600);
const Duration _stopTimeout = Duration(seconds: 3);

const int _maxDescriptionWords = 3;
const int _minHintLength = 3;
const String _genericAccountWord = 'cuenta';
const _leadingWords = {'el', 'la', 'los', 'las', 'un', 'una', 'en', 'de', 'del', 'a', 'al', 'con'};

const _currencyWords = {
  Currency.USD: ['dolar', 'dolares', 'usd', 'u\$s'],
  Currency.EUR: ['euro', 'euros', 'eur'],
  Currency.ARS: ['peso', 'pesos', 'ars'],
};

const _numberWords = {
  'un': 1, 'uno': 1, 'una': 1, 'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5, 'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9,
  'diez': 10, 'once': 11, 'doce': 12, 'trece': 13, 'catorce': 14, 'quince': 15, 'dieciseis': 16, 'diecisiete': 17, 'dieciocho': 18, 'diecinueve': 19,
  'veinte': 20, 'veintiuno': 21, 'veintidos': 22, 'veintitres': 23, 'veinticuatro': 24, 'veinticinco': 25, 'veintiseis': 26, 'veintisiete': 27, 'veintiocho': 28, 'veintinueve': 29,
  'treinta': 30, 'cuarenta': 40, 'cincuenta': 50, 'sesenta': 60, 'setenta': 70, 'ochenta': 80, 'noventa': 90,
  'cien': 100, 'ciento': 100, 'doscientos': 200, 'trescientos': 300, 'cuatrocientos': 400, 'quinientos': 500,
  'seiscientos': 600, 'setecientos': 700, 'ochocientos': 800, 'novecientos': 900,
};

final _dotThousandsPattern = RegExp(r'^\d{1,3}(\.\d{3})+(,\d+)?$');
final _commaThousandsPattern = RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$');
final _decimalCommaPattern = RegExp(r'^\d+,\d{1,2}$');
final _plainNumberPattern = RegExp(r'^\d+(\.\d+)?$');
final _timePattern = RegExp(r'\ba las? ([a-z0-9]+)(?::(\d{2}))?');
const _boundaryBefore = r'(^|[^a-z0-9ñ])';
const _boundaryAfter = r'($|[^a-z0-9ñ])';

class _MovementFields {
  final MovementType? type;
  final String? description;
  final String? amountText;
  final String? rateText;
  final String? dateText;
  final String? categoryText;
  final String? categoryName;
  final String? accountName;
  final String? sourceAccountName;
  final String? targetAccountName;

  const _MovementFields({
    this.type,
    this.description,
    this.amountText,
    this.rateText,
    this.dateText,
    this.categoryText,
    this.categoryName,
    this.accountName,
    this.sourceAccountName,
    this.targetAccountName,
  });

  factory _MovementFields.fromJson(Map<String, Object?> json) {
    return _MovementFields(
      type: _parseType(json['type']),
      description: _cleanText(json['description']),
      amountText: _cleanText(json['amountText']),
      rateText: _cleanText(json['rateText']),
      dateText: _cleanText(json['dateText']),
      categoryText: _cleanText(json['categoryText']),
      categoryName: _cleanText(json['categoryName']),
      accountName: _cleanText(json['accountName']),
      sourceAccountName: _cleanText(json['sourceAccountName']),
      targetAccountName: _cleanText(json['targetAccountName']),
    );
  }

  static MovementType? _parseType(Object? value) {
    var normalized = value.toString().trim().toUpperCase();
    return MovementType.values.where((type) => type.name == normalized).firstOrNull;
  }

  static String? _cleanText(Object? value) {
    if (value is num) return value.toString();
    if (value is! String) return null;
    var cleaned = value.split(RegExp(r'```|<\|')).first.trim();
    return cleaned.isEmpty ? null : cleaned;
  }
}

class InDeviceAIService implements AIService {
  var logger = GetIt.instance.get<Logger>();
  var utilsService = GetIt.instance.get<UtilsService>();
  SpeechToText? _speech;
  Completer<String>? _transcript;
  Timer? _completionTimer;
  void Function(String text)? _onPartialTranscript;
  String _lastWords = '';
  int _listenId = 0;

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isIOS) return false;
    try {
      return (await AppleFoundationModels.availability()).isAvailable;
    } catch (_) {
      return false;
    }
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
      var fields = await _parseFields(transcript, context);
      if (listenId != _listenId) throw const AIException(AIFailure.cancelled);
      var movement = _buildMovement(fields, transcript, context);
      logger.d('Voice movement: ${ movement.toString() } category=${ movement.category.toString() } description=${ movement.description.toString() } rate=${ movement.conversionRate.toString() }');
      return movement;
    } on AIException {
      rethrow;
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

  Future<_MovementFields> _parseFields(String transcript, MovementPromptContext context) async {
    var session = await LanguageModelSession.create(instructions: _buildInstructions(context));
    try {
      var json = await session.respondAs(transcript, schema: _buildSchema(context), options: GenerationOptions.deterministic);
      return _MovementFields.fromJson(json);
    } finally {
      await session.dispose();
    }
  }

  Schema _buildSchema(MovementPromptContext context) {
    var categoryNames = ['', ...context.categoriesByType.values.expand((categories) => categories).map((category) => category.name).toSet()];
    var accountNames = ['', ...context.accounts.map((account) => account.name)];
    const accountNameDescription = 'exact account name from the list, empty if none';
    return Schema.object({
      'type': Schema.oneOf(['REMOVE', 'ADD', 'TRANSFER'], description: 'REMOVE when spending, ADD when receiving, TRANSFER between two own accounts', name: 'typeChoice'),
      'amountText': Schema.string(description: 'exact words or digits of the amount in the sentence, empty if none'),
      'rateText': Schema.string(description: 'exact exchange rate number in the sentence, empty if none'),
      'description': Schema.string(description: 'at most 3 words, empty if none'),
      'dateText': Schema.string(description: 'exact words saying when it happened, empty if none'),
      'categoryText': Schema.string(description: 'exact words of the sentence identifying the category, empty if none'),
      'categoryName': Schema.oneOf(categoryNames, description: 'exact category name from the list, empty if none', name: 'categoryNameChoice'),
      'accountName': Schema.oneOf(accountNames, description: accountNameDescription, name: 'accountNameChoice'),
      'sourceAccountName': Schema.oneOf(accountNames, description: accountNameDescription, name: 'sourceAccountNameChoice'),
      'targetAccountName': Schema.oneOf(accountNames, description: accountNameDescription, name: 'targetAccountNameChoice'),
    }, name: 'Movement');
  }

  String _buildInstructions(MovementPromptContext context) {
    var accounts = context.accounts.map((account) => { 'name': account.name, 'currency': account.currency.name }).toList();
    var categories = context.categoriesByType.map((type, list) => MapEntry(type.name, list.map((category) => category.name).toList()));
    return 'You extract ONE money movement from a Spanish (Argentina) sentence. Answer only with the requested fields. '
        'type: REMOVE when the user spends, pays or buys (gasté, pagué, compré, le pagué a alguien); '
        'ADD when the user receives money (cobré, me depositaron, me pagaron, sueldo); '
        'TRANSFER only when money moves or is exchanged between two of the user accounts (transferí, pasé, cambié dólares). Paying a person or a shop is REMOVE, never TRANSFER. '
        'amountText: copy EXACTLY the words or digits that state the amount, as they appear in the sentence. Empty string if the sentence states no amount. Never invent it. '
        'rateText: copy EXACTLY the number that states an exchange rate (for example the number after "a" in "cambié 100 dólares a 1500 pesos"), as it appears in the sentence. Empty string if none. '
        'description: at most $_maxDescriptionWords words naming the shop, person or item, no verbs, empty if none. '
        'dateText: copy EXACTLY the words that say when it happened (for example "ayer", "anteayer", "al mediodía", "a las 3"). Empty string if none. '
        'categoryText: copy EXACTLY the word or words of the sentence that identify the category (a shop, person or item). Empty string if there is none. '
        'categoryName: the exact name, copied from the category list of the movement type, that fits categoryText; empty string when categoryText is empty. '
        'accountName: exact account name from the account list, only if the sentence names that account, else empty. '
        'sourceAccountName and targetAccountName: exact account names, only for TRANSFER, else empty. '
        'Accounts: ${ jsonEncode(accounts) }. Categories by type: ${ jsonEncode(categories) }.';
  }

  Movement _buildMovement(_MovementFields fields, String transcript, MovementPromptContext context) {
    var type = fields.type ?? MovementType.REMOVE;
    var category = _resolveCategory(fields, transcript, type, context);
    var movement = Movement(
      type,
      _resolveDescription(fields.description, category, context.accounts),
      _resolveAmount(fields, transcript),
      category,
      creationDate: _resolveDate(fields, transcript, context),
    );
    if (type == MovementType.TRANSFER) {
      _fillTransferAccounts(movement, fields, transcript, context);
      return movement;
    }
    var account = _resolveSingleAccount(fields, transcript, context);
    if (type == MovementType.REMOVE) {
      movement.source = account;
    } else {
      movement.target = account;
    }
    return movement;
  }

  String _limitWords(String? description) {
    var words = (description ?? '').split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    return words.take(_maxDescriptionWords).join(' ');
  }

  String _descriptionKey(String text) {
    var words = _normalize(text).split(' ').where((word) => word.isNotEmpty).toList();
    while (words.isNotEmpty && _leadingWords.contains(words.first)) {
      words.removeAt(0);
    }
    var key = words.join(' ');
    return key.endsWith('s') ? key.substring(0, key.length - 1) : key;
  }

  String _resolveDescription(String? description, String category, List<Account> accounts) {
    var limited = _limitWords(description);
    var key = _descriptionKey(limited);
    var redundantKeys = [_genericAccountWord, category, ...accounts.map((account) => account.name)].map(_descriptionKey);
    return key.isEmpty || redundantKeys.contains(key) ? '' : limited;
  }

  double? _groundedNumber(String transcript, String? evidence) {
    return _isGrounded(transcript, evidence) ? _parseNumber(evidence!) : null;
  }

  double _resolveAmount(_MovementFields fields, String transcript) {
    var amount = _groundedNumber(transcript, fields.amountText);
    return amount != null && amount > 0 ? amount : 0;
  }

  DateTime _resolveDate(_MovementFields fields, String transcript, MovementPromptContext context) {
    if (!_isGrounded(transcript, fields.dateText)) return context.now;
    return _parseDateTime(fields.dateText!, context.now) ?? context.now;
  }

  String? _findName(Iterable<String> names, String? candidate) {
    if (candidate == null) return null;
    var normalized = _normalize(candidate);
    return names.where((name) => _normalize(name) == normalized).firstOrNull;
  }

  String? _findLearnedCategory(String transcript, MovementType type, List<String> names, List<DescriptionCategoryUsage> hints) {
    var matching = hints.where((hint) {
      return hint.type == type &&
          names.contains(hint.category) &&
          hint.description.trim().length >= _minHintLength &&
          _containsPhrase(transcript, hint.description);
    }).toList();
    if (matching.isEmpty) return null;
    matching.sort((first, second) {
      var byLength = second.description.trim().length.compareTo(first.description.trim().length);
      return byLength != 0 ? byLength : second.uses.compareTo(first.uses);
    });
    return matching.first.category;
  }

  String _resolveCategory(_MovementFields fields, String transcript, MovementType type, MovementPromptContext context) {
    var names = (context.categoriesByType[type] ?? []).map((category) => category.name).toList();
    var mentioned = names.where((name) => _containsPhrase(transcript, name)).toList();
    mentioned.sort((first, second) => second.length.compareTo(first.length));
    if (mentioned.isNotEmpty) return mentioned.first;
    var learned = _findLearnedCategory(transcript, type, names, context.descriptionUsages);
    if (learned != null) return learned;
    var modelName = _findName(names, fields.categoryName);
    return modelName != null && _isGrounded(transcript, fields.categoryText) ? modelName : '';
  }

  Set<Currency> _mentionedCurrencies(String transcript) {
    return _currencyWords.entries
        .where((entry) => entry.value.any((word) => _containsPhrase(transcript, word)))
        .map((entry) => entry.key)
        .toSet();
  }

  Currency? _saidCurrency(String transcript) {
    var currencies = _mentionedCurrencies(transcript);
    return currencies.length == 1 ? currencies.first : null;
  }

  List<Account> _mentionedAccounts(String transcript, List<Account> accounts) {
    var mentioned = accounts.where((account) => _containsPhrase(transcript, account.name)).toList();
    return mentioned.where((account) {
      var name = _normalize(account.name);
      return !mentioned.any((other) => other != account && _normalize(other.name).contains(name));
    }).toList();
  }

  bool _isAccountSupported(Account account, String transcript, List<Account> accounts) {
    if (_mentionedAccounts(transcript, accounts).contains(account)) return true;
    var sameCurrency = accounts.where((other) => other.currency == account.currency);
    return sameCurrency.length == 1 && _mentionedCurrencies(transcript).contains(account.currency);
  }

  Account? _findSupportedAccount(String? name, String transcript, List<Account> accounts) {
    if (name == null) return null;
    var normalized = _normalize(name);
    var account = accounts.where((candidate) => _normalize(candidate.name) == normalized).firstOrNull;
    return account != null && _isAccountSupported(account, transcript, accounts) ? account : null;
  }

  Account? _fallbackAccount(String transcript, MovementPromptContext context) {
    var currency = _saidCurrency(transcript);
    var screenAccount = context.screenAccount;
    if (screenAccount != null && (currency == null || screenAccount.currency == currency)) return screenAccount;
    var accountOfCurrency = context.accounts.where((account) => account.currency == currency).firstOrNull;
    return accountOfCurrency ?? context.accounts.firstOrNull;
  }

  Account? _resolveSingleAccount(_MovementFields fields, String transcript, MovementPromptContext context) {
    var mentioned = _mentionedAccounts(transcript, context.accounts);
    if (mentioned.length == 1) return mentioned.first;
    var fromModel = _findSupportedAccount(fields.accountName, transcript, context.accounts);
    return fromModel ?? _fallbackAccount(transcript, context);
  }

  void _fillTransferAccounts(Movement movement, _MovementFields fields, String transcript, MovementPromptContext context) {
    var source = _findSupportedAccount(fields.sourceAccountName, transcript, context.accounts);
    var target = _findSupportedAccount(fields.targetAccountName, transcript, context.accounts);
    if (source != null && source == target) target = null;
    movement.source = source;
    movement.target = target;
    if (source == null || target == null || source.currency == target.currency) return;
    var rate = _groundedNumber(transcript, fields.rateText);
    if (rate == null || rate <= 0) return;
    movement.conversionRate = utilsService.isRateInverse(source.currency, target.currency) ? 1 / rate : rate;
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _containsPhrase(String text, String phrase) {
    var normalizedPhrase = _normalize(phrase);
    if (normalizedPhrase.isEmpty) return false;
    var pattern = RegExp(_boundaryBefore + RegExp.escape(normalizedPhrase) + _boundaryAfter);
    return pattern.hasMatch(_normalize(text));
  }

  bool _isGrounded(String transcript, String? evidence) {
    return evidence != null && _containsPhrase(transcript, evidence);
  }

  double? _parseNumericToken(String token) {
    if (_dotThousandsPattern.hasMatch(token)) return double.tryParse(token.replaceAll('.', '').replaceAll(',', '.'));
    if (_commaThousandsPattern.hasMatch(token)) return double.tryParse(token.replaceAll(',', ''));
    if (_decimalCommaPattern.hasMatch(token)) return double.tryParse(token.replaceAll(',', '.'));
    if (_plainNumberPattern.hasMatch(token)) return double.tryParse(token);
    return null;
  }

  double? _parseNumber(String text) {
    var tokens = _normalize(text)
        .replaceAll(RegExp(r'[^a-zñ0-9.,\s]'), ' ')
        .split(' ')
        .map((token) => token.replaceAll(RegExp(r'[.,]+$'), ''))
        .where((token) => token.isNotEmpty);
    var total = 0.0;
    var current = 0.0;
    var found = false;
    for (var token in tokens) {
      var value = _parseNumericToken(token) ?? _numberWords[token]?.toDouble();
      if (value != null) {
        current += value;
        found = true;
      } else if (token == 'mil') {
        total += (current == 0 ? 1 : current) * 1000;
        current = 0;
        found = true;
      } else if ((token == 'luca' || token == 'lucas') && current > 0) {
        total += current * 1000;
        current = 0;
      } else if (token == 'millon' || token == 'millones') {
        total += (current == 0 ? 1 : current) * 1000000;
        current = 0;
        found = true;
      }
    }
    return found ? total + current : null;
  }

  int? _parseDayOffset(String normalized) {
    if (_containsPhrase(normalized, 'anteayer') || _containsPhrase(normalized, 'antes de ayer')) return 2;
    if (_containsPhrase(normalized, 'ayer')) return 1;
    if (_containsPhrase(normalized, 'hoy')) return 0;
    return null;
  }

  Duration? _parseClockTime(String normalized) {
    var match = _timePattern.firstMatch(normalized);
    if (match == null) return null;
    var hour = _parseNumber(match.group(1)!)?.toInt();
    var minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    if (hour == null || hour > 23 || minutes > 59) return null;
    var isAfternoon = _containsPhrase(normalized, 'de la tarde') || _containsPhrase(normalized, 'de la noche');
    if (isAfternoon && hour < 12) hour += 12;
    if (_containsPhrase(normalized, 'de la mañana') && hour == 12) hour = 0;
    return Duration(hours: hour, minutes: minutes);
  }

  Duration? _parseTimeOfDay(String normalized) {
    if (_containsPhrase(normalized, 'mediodia')) return const Duration(hours: 12);
    if (_containsPhrase(normalized, 'medianoche')) return Duration.zero;
    return _parseClockTime(normalized);
  }

  DateTime? _parseDateTime(String text, DateTime now) {
    var normalized = _normalize(text);
    var dayOffset = _parseDayOffset(normalized);
    var timeOfDay = _parseTimeOfDay(normalized);
    if (dayOffset == null && timeOfDay == null) return null;
    var day = DateTime(now.year, now.month, now.day - (dayOffset ?? 0));
    var time = timeOfDay ?? Duration(hours: now.hour, minutes: now.minute);
    return DateTime(day.year, day.month, day.day, time.inHours, time.inMinutes % 60);
  }
}
