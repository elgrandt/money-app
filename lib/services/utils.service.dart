
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:http/http.dart' as http;

class CurrencyMapping {
  Currency from;
  Currency to;
  double multiplier;

  CurrencyMapping({ required this.from, required this.to, required this.multiplier });

  @override
  String toString() {
    return '${from.name} -> ${to.name}: ${multiplier.toStringAsFixed(2)}';
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
  var logger = GetIt.instance.get<Logger>();

  static List<CurrencyConfig> currencyConfigs = [
    CurrencyConfig(currency: Currency.ARS, name: 'ARS', icon: Image.asset('icons/currency/ars.png', package: 'currency_icons', width: 24), symbol: '\$'),
    CurrencyConfig(currency: Currency.USD, name: 'USD', icon: Image.asset('icons/currency/usd.png', package: 'currency_icons', width: 24), symbol: 'U\$S'),
    CurrencyConfig(currency: Currency.EUR, name: 'EUR', icon: Image.asset('icons/currency/eur.png', package: 'currency_icons', width: 24), symbol: '€'),
  ];

  UtilsService();

  Future<void> updateCurrencyMappings() async {
    // Update currency mappings every hour
    var diff = DateTime.now().millisecondsSinceEpoch - lastCurrencyMappingUpdate.millisecondsSinceEpoch;
    if (diff < 1000 * 60 * 60) return; // 1 hour
    logger.d('Updating currency mappings');
    lastCurrencyMappingUpdate = DateTime.now();
    // Get currency mappings from API
    var url = Uri.parse('https://api.bluelytics.com.ar/v2/latest');
    var response = await http.get(url);
    var json = response.body;
    var body = jsonDecode(json);
    // Update currency mappings
    double USDtoARS = body['blue']['value_buy'];
    double EURtoARS = body['blue_euro']['value_buy'];
    double EURtoUSD = 1.11;
    currencyMappings = [
      CurrencyMapping(from: Currency.ARS, to: Currency.EUR, multiplier: 1 / EURtoARS),
      CurrencyMapping(from: Currency.ARS, to: Currency.USD, multiplier: 1 / USDtoARS),
      CurrencyMapping(from: Currency.USD, to: Currency.ARS, multiplier: USDtoARS),
      CurrencyMapping(from: Currency.USD, to: Currency.EUR, multiplier: 1 / EURtoUSD),
      CurrencyMapping(from: Currency.EUR, to: Currency.ARS, multiplier: EURtoARS),
      CurrencyMapping(from: Currency.EUR, to: Currency.USD, multiplier: EURtoUSD),
    ];
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

  String beautifyCurrency(double number, Currency currency) {
    var formatter = NumberFormat.currency(locale: 'es_AR', name: currency.name, symbol: getCurrencySymbol(currency));
    formatter.minimumIntegerDigits = 1;
    formatter.minimumFractionDigits = 0;
    formatter.maximumFractionDigits = 2;
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
              style: ButtonStyle(fixedSize: MaterialStateProperty.all(const Size(100, 30))),
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