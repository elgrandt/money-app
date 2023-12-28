
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:money/models/account.model.dart';

class CurrencyMapping {
  Currency from;
  Currency to;
  double multiplier;

  CurrencyMapping({ required this.from, required this.to, required this.multiplier });
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

  static List<CurrencyConfig> currencyConfigs = [
    CurrencyConfig(currency: Currency.ARS, name: 'ARS', icon: Image.asset('icons/currency/ars.png', package: 'currency_icons', width: 24), symbol: '\$'),
    CurrencyConfig(currency: Currency.USD, name: 'USD', icon: Image.asset('icons/currency/usd.png', package: 'currency_icons', width: 24), symbol: 'U\$S'),
    CurrencyConfig(currency: Currency.EUR, name: 'EUR', icon: Image.asset('icons/currency/eur.png', package: 'currency_icons', width: 24), symbol: '€'),
  ];

  UtilsService();

  double convertCurrencies(double amount, Currency from, Currency to) {
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
}