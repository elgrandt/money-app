import 'dart:async';
import 'package:events_emitter/events_emitter.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/currency_rates.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';

class ExchangeRatesTable extends StatefulWidget {
  const ExchangeRatesTable({ super.key });

  @override
  State<ExchangeRatesTable> createState() => _ExchangeRatesTableState();
}

class _ExchangeRatesTableState extends State<ExchangeRatesTable> {
  var databaseService = GetIt.instance.get<DatabaseService>();
  var utilsService = GetIt.instance.get<UtilsService>();
  var logger = GetIt.instance.get<Logger>();
  EventListener<TableUpdateEvent<CurrencyRates>>? ratesListener;
  CurrencyRates? latestRates;
  bool loaded = false;

  final List<Currency> currencies = [Currency.USD, Currency.EUR];

  @override
  void initState() {
    super.initState();
    loadLatestRates();
    watchRatesChanges();
  }

  @override
  void dispose() {
    super.dispose();
    ratesListener?.cancel();
  }

  Future<void> watchRatesChanges() async {
    await databaseService.initialized;
    ratesListener = databaseService.currencyRatesRepository.events.on<TableUpdateEvent<CurrencyRates>>('change', (event) {
      logger.d('Currency rates change: $event');
      loadLatestRates();
    });
  }

  Future<void> loadLatestRates() async {
    await databaseService.initialized;
    try {
      var rates = await databaseService.currencyRatesRepository.findLatest();
      if (!mounted) return;
      setState(() {
        latestRates = rates;
        loaded = true;
      });
    } catch (error, stackTrace) {
      logger.e('Error loading currency rates', error: error, stackTrace: stackTrace);
    }
  }

  String lastUpdateText() {
    if (!loaded) return '—';
    if (latestRates == null) return 'Nunca';
    return DateFormat('dd/MM/yyyy HH:mm').format(latestRates!.updatedAt);
  }

  (double, double)? ratesFor(Currency currency) {
    if (latestRates == null) return null;
    switch (currency) {
      case Currency.USD:
        return (latestRates!.usdBuy, latestRates!.usdSell);
      case Currency.EUR:
        return (latestRates!.eurBuy, latestRates!.eurSell);
      case Currency.ARS:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: IntrinsicColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: currencies.map((currency) => buildRateRow(context, currency)).toList(),
          ),
          const SizedBox(height: 15),
          Text('Última actualización: ${ lastUpdateText() }', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  TableRow buildRateRow(BuildContext context, Currency currency) {
    var pair = ratesFor(currency);
    var text = pair == null
      ? '—/—'
      : '${ utilsService.beautifyCurrency(pair.$1, Currency.ARS) }/${ utilsService.beautifyCurrency(pair.$2, Currency.ARS) }';
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              utilsService.getCurrencyIcon(currency),
              const SizedBox(width: 10),
              Text(currency.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
