import 'package:events_emitter/events_emitter.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/generics/currency_selector.dart';
import 'package:money/views/generics/loader.dart';
import 'package:money/views/home/movements_list.dart';
import 'package:money/views/home/total_viewer.dart';

class AllExpensesChart extends StatefulWidget {
  const AllExpensesChart({super.key});

  @override
  State<AllExpensesChart> createState() => _AllExpensesChartState();
}

class _AllExpensesChartState extends State<AllExpensesChart> {
  var databaseService = GetIt.instance.get<DatabaseService>();
  var logger = GetIt.instance.get<Logger>();
  List<Account>? accounts;
  var initializedCurrencies = false;
  EventListener<TableUpdateEvent<Account>>? accountsListener;
  Currency currency = Currency.ARS;

  @override
  void initState() {
    super.initState();
    getAccounts();
    initializeCurrencies();
    watchAccountChanges();
  }

  @override
  void dispose() {
    super.dispose();
    accountsListener?.cancel();
  }

  Future<void> initializeCurrencies() async {
    await GetIt.instance.get<UtilsService>().updateCurrencyMappings();
    setState(() {
      initializedCurrencies = true;
    });
  }

  Future<void> getAccounts() async {
    await databaseService.initialized;
    try {
      logger.d('Getting accounts');
      var accounts = await databaseService.accountsRepository.find(orderBy: 'sortIndex ASC');
      setState(() {
        this.accounts = accounts;
      });
    } catch (error, stackTrace) {
      logger.e('Error getting accounts', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> watchAccountChanges() async {
    await databaseService.initialized;
    accountsListener = databaseService.accountsRepository.events.on<TableUpdateEvent<Account>>('change', (event) {
      logger.d('Account change: $event');
      getAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return accounts == null ? Loader() : ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 500),
      child: Column(
        children: [
          const SizedBox(height: 10),
          CurrencySelector(selected: currency, onSelectionChange: (newValue) => setState(() { currency = newValue; })),
          const SizedBox(height: 30),
          MovementsList(currency: currency, movementTypeFilter: MovementType.REMOVE,),
        ],
      ),
    );
  }
}