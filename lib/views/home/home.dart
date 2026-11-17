import 'package:events_emitter/events_emitter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/services/ai.service.dart';
import 'package:money/views/accounts/new_account.dialog.dart';
import 'package:money/views/generics/currency_selector.dart';
import 'package:money/views/generics/loader.dart';
import 'package:money/views/generics/navbar.dart';
import 'package:money/views/generics/tabs.dart' as tabs;
import 'package:money/views/home/dashboard.dart';
import 'package:money/views/home/movements_list.dart';
import 'package:money/views/home/total_viewer.dart';
import 'package:money/views/movements/new_movement.dialog.dart';
import 'package:money/views/movements/voice_listening.dialog.dart';
import 'package:money/views/movements/voice_movement_summary.dialog.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  var databaseService = GetIt.instance.get<DatabaseService>();
  var utilsService = GetIt.instance.get<UtilsService>();
  var logger = GetIt.instance.get<Logger>();
  var aiService = GetIt.instance.get<AIService>();

  List<Account>? accounts;
  int selectedTabIndex = 0;
  bool voiceAssistantAvailable = false;
  List<GlobalKey<_HomeTabState>> tabKeys = [GlobalKey()];
  var initializedCurrencies = false;
  EventListener<TableUpdateEvent<Account>>? accountsListener;

  Account? get currentAccount {
    if (selectedTabIndex > 0 && accounts != null) return accounts![selectedTabIndex - 1];
    return null;
  }

  @override
  void initState() {
    super.initState();
    loadVoiceAssistantAvailability();
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
    await utilsService.loadCachedMappings();
    if (!mounted) return;
    setState(() {
      initializedCurrencies = true;
    });
    await utilsService.updateCurrencyMappings();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> getAccounts() async {
    await databaseService.initialized;
    try {
      logger.d('Getting accounts');
      var accounts = await databaseService.accountsRepository.find(orderBy: 'sortIndex ASC');
      if (!mounted) return;
      setState(() {
        tabKeys = [GlobalKey<_HomeTabState>(), ...accounts.map((e) => GlobalKey<_HomeTabState>())];
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

  Future<void> loadVoiceAssistantAvailability() async {
    var available = await aiService.isAvailable();
    if (!mounted) return;
    setState(() {
      voiceAssistantAvailable = available;
    });
  }

  Future<void> openNewMovementDialog() async {
    await showDialog<Movement?>(context: context, builder: (context) {
      return NewMovementDialog(selectedAccount: currentAccount);
    });
  }

  Future<MovementPromptContext> buildPromptContext() async {
    var categoriesByType = await databaseService.categoriesRepository.getCategoriesByType();
    var descriptionUsages = await databaseService.movementsRepository.getDescriptionCategoryUsages();
    return MovementPromptContext(now: DateTime.now(), accounts: accounts!, categoriesByType: categoriesByType, screenAccount: currentAccount, descriptionUsages: descriptionUsages);
  }

  bool isIncomplete(Movement movement) {
    if (movement.amount <= 0 || movement.category.isEmpty) return true;
    switch (movement.type) {
      case MovementType.ADD:
        return movement.target == null;
      case MovementType.REMOVE:
        return movement.source == null;
      case MovementType.TRANSFER:
        return movement.source == null || movement.target == null || (movement.source!.currency != movement.target!.currency && movement.conversionRate == null);
    }
  }

  Future<void> openPrefilledMovementDialog(Movement movement) async {
    await showDialog<Movement?>(context: context, builder: (context) {
      return NewMovementDialog(selectedAccount: currentAccount, movement: movement);
    });
  }

  Future<void> openVoiceMovementFlow() async {
    var promptContext = await buildPromptContext();
    if (!mounted) return;
    var movement = await showDialog<Movement?>(context: context, barrierDismissible: false, builder: (context) {
      return VoiceListeningDialog(promptContext: promptContext);
    });
    if (movement == null || !mounted) return;
    if (isIncomplete(movement)) return openPrefilledMovementDialog(movement);
    var result = await showDialog<VoiceSummaryResult?>(context: context, builder: (context) {
      return VoiceMovementSummaryDialog(movement: movement);
    });
    if (result == VoiceSummaryResult.modify && mounted) await openPrefilledMovementDialog(movement);
  }

  Future<void> openNewAccountDialog() async {
    await showDialog<bool?>(context: context, builder: (context) {
      return const NewAccountDialog();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Navbar(
      floatingActionButton: accounts != null && accounts!.isNotEmpty ? buildFloatingActionButtons(context) : null,
      body: accounts == null || !initializedCurrencies ? const Loader() : accounts!.isEmpty ? buildWelcomePage(context) : buildTabs(context),
    );
  }

  Widget buildFloatingActionButtons(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (voiceAssistantAvailable) ...[
          FloatingActionButton.small(
            heroTag: 'voice-movement',
            onPressed: openVoiceMovementFlow,
            backgroundColor: Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          heroTag: 'new-movement',
          onPressed: openNewMovementDialog,
          backgroundColor: Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ],
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
            MapEntry(index, tabs.Tab(name: account.name, body: HomeTab(account: account, accounts: accounts!, key: tabKeys[index + 1])))
        ).values
      ],
    );
  }
}

class HomeTab extends StatefulWidget {
  final Account? account;
  final List<Account> accounts;

  const HomeTab({ super.key, this.account, required this.accounts });

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
        const SizedBox(height: 10),
        CurrencySelector(selected: currency, onSelectionChange: (newValue) => setState(() { currency = newValue; })),
        TotalViewer(account: widget.account, accounts: widget.accounts, currency: currency, padding: const EdgeInsets.symmetric(vertical: 30)),
        MovementsList(account: widget.account, currency: currency, key: movementsKey),
      ],
    );
  }
}
