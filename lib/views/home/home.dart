import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/accounts_list/accounts_list.dialog.dart';
import 'package:money/views/generics/currency_selector.dart';
import 'package:money/views/generics/loader.dart';
import 'package:money/views/generics/tabs.dart' as tabs;
import 'package:money/views/home/dashboard.dart';
import 'package:money/views/home/movements_list.dart';
import 'package:money/views/home/total_viewer.dart';
import 'package:money/views/new_account/new_account.dialog.dart';
import 'package:money/views/new_movement/new_movement.dialog.dart';

/*
TODO
- Edit accounts
- Transfer currency exchange rate
- Add account total functionality
*/

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  var databaseService = GetIt.instance.get<DatabaseService>();
  var logger = GetIt.instance.get<Logger>();

  List<Account>? accounts;
  int selectedTabIndex = 0;
  List<GlobalKey<_HomeTabState>> tabKeys = [GlobalKey()];
  var initializedCurrencies = false;

  @override
  void initState() {
    super.initState();
    getAccounts();
    initializeCurrencies();
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
      var accounts = await databaseService.accountsRepository.find();
      setState(() {
        tabKeys = [GlobalKey<_HomeTabState>(), ...accounts.map((e) => GlobalKey<_HomeTabState>()).toList()];
        this.accounts = accounts;
      });
    } catch (error, stackTrace) {
      logger.e('Error getting accounts', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> openNewMovementDialog() async {
    Account? selectedAccount;
    if (selectedTabIndex > 0 && accounts != null) {
      selectedAccount = accounts![selectedTabIndex - 1];
    }
    var result = await showDialog<Movement?>(context: context, builder: (context) {
      return NewMovementDialog(accounts: accounts!, selectedAccount: selectedAccount);
    });
    if (result != null) {
      getAccounts();
    }
  }

  Future<void> openAccountListDialog() async {
    var result = await showDialog<Account?>(context: context, builder: (context) {
      return AccountsListDialog(accounts: accounts!);
    });
    if (result != null) {
      getAccounts();
    }
  }

  Future<void> openNewAccountDialog() async {
    var result = await showDialog<Account?>(context: context, builder: (context) {
      return const NewAccountDialog();
    });
    if (result != null) {
      getAccounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Money'),
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: accounts != null && accounts!.isNotEmpty ? FloatingActionButton(
        onPressed: openNewMovementDialog,
        backgroundColor: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
      body: accounts == null || !initializedCurrencies ? const Loader() : accounts!.isEmpty ? buildWelcomePage(context) : buildTabs(context),
    );
  }

  Widget buildWelcomePage(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Bienvenido a Money', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('Para comenzar, configura tu primer cuenta.', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              openNewAccountDialog();
            },
            child: const Text('Comenzar'),
          ),
        ],
      ),
    );
  }

  Widget buildTabs(BuildContext context) {
    return tabs.Tabs(
      onSelectedTabChange: (index) => setState(() {
        selectedTabIndex = index;
      }),
      tabs: [
        tabs.Tab(name: 'Dashboard', body: Dashboard(accounts: accounts!)),
        ...accounts!.asMap().map((index, account) =>
            MapEntry(index, tabs.Tab(name: account.name, body: HomeTab(account: account, accounts: accounts!, key: tabKeys[index + 1], openAccountListDialog: openAccountListDialog)))
        ).values
      ],
    );
  }
}

class HomeTab extends StatefulWidget {
  final Account? account;
  final List<Account> accounts;
  final Future<void> Function() openAccountListDialog;

  const HomeTab({ super.key, this.account, required this.accounts, required this.openAccountListDialog });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Currency currency;
  var movementsKey = GlobalKey<MovementsListState>();

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      currency = widget.account!.currency;
    } else {
      currency = Currency.ARS;
    }
  }

  @override
  void didUpdateWidget(covariant HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.account != null && widget.account!.currency != oldWidget.account?.currency) {
      setState(() {
        currency = widget.account!.currency;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        drawEditAccountButton(context),
        const SizedBox(height: 10),
        CurrencySelector(selected: currency, onSelectionChange: (newValue) => setState(() { currency = newValue; })),
        TotalViewer(account: widget.account, accounts: widget.accounts, currency: currency, padding: const EdgeInsets.symmetric(vertical: 30)),
        MovementsList(account: widget.account, currency: currency, key: movementsKey),
      ],
    );
  }

  Widget drawEditAccountButton(BuildContext context) {
    return SizedBox(
      height: 30,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: widget.openAccountListDialog,
        child: const Text('Editar cuentas'),
      ),
    );
  }
}
