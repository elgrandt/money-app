import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/currency_rates.model.dart';
import 'package:money/services/database.service.dart';
import 'package:http/http.dart' as http;

class CurrencyMapping {
  Currency from;
  Currency to;
  double multiplier;

  CurrencyMapping({ required this.from, required this.to, required this.multiplier });

  @override
  String toString() {
    return '${ from.name } -> ${ to.name }: ${ multiplier.toStringAsFixed(2) }';
  }
}

class CurrencyConfig {
  Currency currency;
  String name;
  Widget icon;
  String symbol;

  CurrencyConfig({ required this.currency, required this.name, required this.icon, required this.symbol });
}

class UtilsService {
  static var currencyMappings = [
    CurrencyMapping(from: Currency.ARS, to: Currency.EUR, multiplier: 1),
    CurrencyMapping(from: Currency.ARS, to: Currency.USD, multiplier: 1),
    CurrencyMapping(from: Currency.USD, to: Currency.ARS, multiplier: 1),
    CurrencyMapping(from: Currency.USD, to: Currency.EUR, multiplier: 1),
    CurrencyMapping(from: Currency.EUR, to: Currency.ARS, multiplier: 1),
    CurrencyMapping(from: Currency.EUR, to: Currency.USD, multiplier: 1),
  ];
  var lastCurrencyMappingUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  var rateHistory = <CurrencyRates>[];
  var logger = GetIt.instance.get<Logger>();

  static List<CurrencyConfig> currencyConfigs = [
    CurrencyConfig(currency: Currency.ARS, name: 'ARS', icon: Image.asset('icons/currency/ars.png', package: 'currency_icons', width: 24), symbol: '\$'),
    CurrencyConfig(currency: Currency.USD, name: 'USD', icon: Image.asset('icons/currency/usd.png', package: 'currency_icons', width: 24), symbol: 'U\$S'),
    CurrencyConfig(currency: Currency.EUR, name: 'EUR', icon: Image.asset('icons/currency/eur.png', package: 'currency_icons', width: 24), symbol: '€'),
  ];

  UtilsService();

  DatabaseService get _databaseService => GetIt.instance.get<DatabaseService>();

  List<CurrencyMapping> buildMappings({ required double usdBuy, required double usdSell, required double eurBuy, required double eurSell }) {
    return [
      CurrencyMapping(from: Currency.ARS, to: Currency.EUR, multiplier: 1 / eurSell),
      CurrencyMapping(from: Currency.ARS, to: Currency.USD, multiplier: 1 / usdSell),
      CurrencyMapping(from: Currency.USD, to: Currency.ARS, multiplier: usdBuy),
      CurrencyMapping(from: Currency.USD, to: Currency.EUR, multiplier: usdBuy / eurSell),
      CurrencyMapping(from: Currency.EUR, to: Currency.ARS, multiplier: eurBuy),
      CurrencyMapping(from: Currency.EUR, to: Currency.USD, multiplier: eurBuy / usdSell),
    ];
  }

  void applyRates({ required double usdBuy, required double usdSell, required double eurBuy, required double eurSell }) {
    currencyMappings = buildMappings(usdBuy: usdBuy, usdSell: usdSell, eurBuy: eurBuy, eurSell: eurSell);
  }

  Future<void> loadRateHistory() async {
    await _databaseService.initialized;
    rateHistory = await _databaseService.currencyRatesRepository.findAllSorted();
  }

  Future<void> loadCachedMappings() async {
    try {
      await _databaseService.initialized;
      var cached = await _databaseService.currencyRatesRepository.findLatest();
      if (cached != null) {
        applyRates(usdBuy: cached.usdBuy, usdSell: cached.usdSell, eurBuy: cached.eurBuy, eurSell: cached.eurSell);
        logger.d('Loaded cached currency mappings: $cached');
      }
      await loadRateHistory();
    } catch (error, stackTrace) {
      logger.e('Error loading cached currency mappings', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> updateCurrencyMappings() async {
    var diff = DateTime.now().millisecondsSinceEpoch - lastCurrencyMappingUpdate.millisecondsSinceEpoch;
    if (diff < const Duration(hours: 1).inMilliseconds) return;
    logger.d('Updating currency mappings');
    lastCurrencyMappingUpdate = DateTime.now();
    try {
      var url = Uri.parse('https://api.bluelytics.com.ar/v2/latest');
      var response = await http.get(url);
      var json = response.body;
      var body = jsonDecode(json);
      double usdBuy = body['blue']['value_buy'];
      double usdSell = body['blue']['value_sell'];
      double eurBuy = body['blue_euro']['value_buy'];
      double eurSell = body['blue_euro']['value_sell'];
      applyRates(usdBuy: usdBuy, usdSell: usdSell, eurBuy: eurBuy, eurSell: eurSell);
      await _databaseService.currencyRatesRepository.record(CurrencyRates(
        usdBuy: usdBuy,
        usdSell: usdSell,
        eurBuy: eurBuy,
        eurSell: eurSell,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await loadRateHistory();
      logger.d('Currency mappings updated successfully');
    } catch (error, stackTrace) {
      logger.e('Error updating currency mappings', error: error, stackTrace: stackTrace);
    }
  }

  double convertCurrencies(double amount, Currency from, Currency to) {
    updateCurrencyMappings();
    if (from == to) return amount;
    for (var mapping in currencyMappings) {
      if (mapping.from == from && mapping.to == to) {
        return amount * mapping.multiplier;
      }
    }
    return amount;
  }

  double convertCurrenciesAt(double amount, Currency from, Currency to, DateTime date) {
    if (from == to) return amount;
    var rates = _resolveRatesAt(date);
    if (rates == null) return amount;
    var mappings = buildMappings(usdBuy: rates.usdBuy, usdSell: rates.usdSell, eurBuy: rates.eurBuy, eurSell: rates.eurSell);
    for (var mapping in mappings) {
      if (mapping.from == from && mapping.to == to) {
        return amount * mapping.multiplier;
      }
    }
    return amount;
  }

  CurrencyRates? _resolveRatesAt(DateTime date) {
    if (rateHistory.isEmpty) return null;
    CurrencyRates? resolved;
    for (var rates in rateHistory) {
      if (!rates.createdAt.isAfter(date)) {
        resolved = rates;
      } else {
        break;
      }
    }
    return resolved ?? rateHistory.first;
  }

  String beautifyCurrency(double number, Currency currency) {
    var formatter = NumberFormat.currency(locale: 'es_AR', name: currency.name, symbol: getCurrencySymbol(currency));
    formatter.minimumIntegerDigits = 1;
    formatter.minimumFractionDigits = 0;
    formatter.maximumFractionDigits = 0;
    return formatter.format(number);
  }

  Widget getCurrencyIcon(Currency currency) {
    return currencyConfigs.firstWhere((config) => config.currency == currency).icon;
  }

  String getCurrencySymbol(Currency currency) {
    return currencyConfigs.firstWhere((config) => config.currency == currency).symbol;
  }

  Future<bool> confirm(BuildContext context, { String? title, String? message, String confirmText = 'Confirmar', String cancelText = 'Cancelar' }) async {
    return await showDialog<bool?>(context: context, builder: (context) {
      return AlertDialog(
        title: title != null ? Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)) : null,
        content: message != null ? Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18)) : null,
        actions: [
          TextButton(
              style: ButtonStyle(fixedSize: WidgetStateProperty.all(const Size(100, 30))),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor))
          ),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                fixedSize: const Size(140, 30),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))
          ),
        ],
      );
    }) ?? false;
  }

  List<T> filterList<T>(List<T> list, String query, String Function(T) key) {
    if (query.isEmpty) return list;
    return list.where((element) {
      var field = key(element);
      return normalizeString(field).contains(normalizeString(query));
    }).toList();
  }

  String normalizeString(String string) {
    return string
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
  }
}
