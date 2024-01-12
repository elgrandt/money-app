
import 'package:events_emitter/events_emitter.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:money/services/database.service.dart';
import 'package:money/views/accounts/new_account.dialog.dart';
import 'package:money/views/generics/loader.dart';
import 'package:money/views/generics/navbar.dart';

class AccountList extends StatefulWidget {
  const AccountList({super.key});

  @override
  State<AccountList> createState() => _AccountListState();
}

class _AccountListState extends State<AccountList> {

  List<Account>? accounts;
  var databaseService = GetIt.instance.get<DatabaseService>();
  var logger = GetIt.instance.get<Logger>();
  EventListener<TableUpdateEvent<Account>>? accountsListener;
  bool disableAccountUpdate = false;

  @override
  void initState() {
    super.initState();
    getAccounts();
    watchAccountChanges();
  }

  @override
  void dispose() {
    super.dispose();
    accountsListener?.cancel();
  }

  Future<void> getAccounts() async {
    if (disableAccountUpdate) return;
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

  Future<void> openNewAccountDialog() async {
    await showDialog<bool?>(context: context, builder: (context) {
      return const NewAccountDialog();
    });
  }

  Future<void> updateAccountsOrder() async {
    if (accounts == null) {
      return;
    }
    disableAccountUpdate = true;
    for (var i = 0; i < accounts!.length; i++) {
      var account = accounts![i];
      account.sortIndex = i;
      await databaseService.accountsRepository.update(account);
    }
    disableAccountUpdate = false;
  }

  @override
  Widget build(BuildContext context) {
    return Navbar(
      title: 'Cuentas',
      floatingActionButton: accounts != null && accounts!.isNotEmpty ? FloatingActionButton(
        onPressed: openNewAccountDialog,
        backgroundColor: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
      body: accounts == null ? const Loader() : buildAccountList(context),
    );
  }

  Widget buildAccountList(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
      itemBuilder: (context, index) => buildAccountItem(context, accounts![index], index),
      itemCount: accounts!.length,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        var account = accounts!.removeAt(oldIndex);
        accounts!.insert(newIndex, account);
        updateAccountsOrder();
        setState(() { });
      },
    );
  }

  Widget buildAccountItem(BuildContext context, Account account, int index) {
    return Container(
      key: ValueKey(index),
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.only(top: 5, bottom: 5, left: 10),
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 7,
            offset: const Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child: ListTile(
        title: Text(account.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (accounts!.length > 1)
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red.shade900),
                onPressed: () {
                  databaseService.accountsRepository.delete(account.id!);
                },
              ),
            if (accounts!.length > 1)
              const SizedBox(width: 5),
            ReorderableDragStartListener(
              key: ValueKey<int>(account.id!),
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
          ],
        ),
      ),
    );
  }
}
