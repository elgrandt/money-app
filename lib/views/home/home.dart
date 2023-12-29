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
import 'package:money/views/generics/navbar.dart';
import 'package:money/views/generics/tabs.dart' as tabs;
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

  @override
  void initState() {
    super.initState();
    getAccounts();
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
      tabKeys[selectedTabIndex].currentState?.movementsKey.currentState?.getMovements();
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
    return Navbar(
      floatingActionButton: accounts != null && accounts!.isNotEmpty ? FloatingActionButton(
        onPressed: openNewMovementDialog,
        backgroundColor: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
      body: accounts == null ? const Loader() : accounts!.isEmpty ? buildWelcomePage(context) : buildTabs(context),
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
        tabs.Tab(name: 'Todas las cuentas', body: HomeTab(accounts: accounts!, key: tabKeys[0], openAccountListDialog: openAccountListDialog)),
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
  var movementsKey = GlobalKey<_MovementsListState>();

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
        TotalViewer(account: widget.account, accounts: widget.accounts, currency: currency),
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

class TotalViewer extends StatelessWidget {
  final Account? account;
  final List<Account> accounts;
  final Currency currency;

  const TotalViewer({ super.key, this.account, required this.accounts, required this.currency });

  String totalString() {
    var utilsService = GetIt.instance.get<UtilsService>();
    double total = 0;
    if (account != null) {
      total = utilsService.convertCurrencies(account!.total, account!.currency, currency);
    } else {
      total = 0;
      for (var account in accounts) {
        total += utilsService.convertCurrencies(account.total, account.currency, currency);
      }
    }
    return GetIt.instance.get<UtilsService>().beautifyCurrency(total, currency);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      height: 140,
      child: Text(totalString(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
    );
  }
}

class MovementsList extends StatefulWidget {
  final Account? account;
  final Currency currency;

  const MovementsList({ super.key, required this.currency, this.account });

  @override
  State<MovementsList> createState() => _MovementsListState();
}

class _MovementsListState extends State<MovementsList> {
  List<Movement>? movements;
  int page = 0;
  int itemsPerPage = 10;
  var databaseService = GetIt.instance.get<DatabaseService>();

  @override
  void initState() {
    super.initState();
    getMovements();
  }

  @override
  didUpdateWidget(MovementsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (movements == null || widget.account?.name != oldWidget.account?.name) {
      getMovements();
    }
  }

  Future<void> getMovements() async {
    await databaseService.initialized;
    try {
      var movements = await databaseService.movementsRepository.getLastMovements(widget.account, page, itemsPerPage);
      setState(() {
        this.movements = movements;
      });
    } catch (error, stackTrace) {
      GetIt.instance.get<Logger>().e('Error getting movements', error: error, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return movements == null ? const Loader() :
      movements!.isEmpty ? buildEmptyMessage(context) :
      Expanded(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: movements!.length,
          scrollDirection: Axis.vertical,
          itemBuilder: (BuildContext context, int index) => MovementListItem(movement: movements![index], currency: widget.currency, account: widget.account),
          separatorBuilder: (BuildContext context, int index) => const Divider(),
        ),
      );
  }

  Widget buildEmptyMessage(BuildContext context) {
    return const Text('No se encontaron movimientos');
  }
}

class MovementListItem extends StatelessWidget {
  final Movement movement;
  final Currency currency;
  final Account? account;

  const MovementListItem({ super.key, required this.movement, required this.currency, this.account });

  Color getMovementTypeColor(MovementType movementType) {
    if (movementType == MovementType.ADD) {
      return Colors.green.shade900;
    } else if (movementType == MovementType.REMOVE) {
      return Colors.red.shade900;
    } else if (movementType == MovementType.TRANSFER) {
      if (account == null) {
        return Colors.yellow.shade900;
      } else {
        if (movement.source != null && movement.source!.id == account!.id) {
          return Colors.red.shade900;
        }
        if (movement.target != null && movement.target!.id == account!.id) {
          return Colors.green.shade900;
        }
        return Colors.yellow.shade900;
      }
    } else {
      return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(movement.description, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(width: 20),
              Text(
                GetIt.instance.get<UtilsService>().beautifyCurrency(movement.amount, currency),
                overflow: TextOverflow.visible,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: getMovementTypeColor(movement.type))
              )
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(movement.category),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  movement.source != null ? Row(
                    children: [
                      Text(movement.source!.name, overflow: TextOverflow.ellipsis),
                      Icon(CupertinoIcons.arrow_down_right, size: 18, color: Colors.red.shade900),
                    ],
                  ) : Container(),
                  movement.target != null ? Row(
                    children: [
                      Text(movement.target!.name, overflow: TextOverflow.ellipsis),
                      Icon(CupertinoIcons.arrow_up_right, size: 18, color: Colors.green.shade900),
                    ],
                  ) : Container(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
