
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/services/database.service.dart';
import 'package:money/views/generics/loader.dart';
import 'package:money/views/new_account/new_account.dialog.dart';

class AccountsListDialog extends StatefulWidget {
  const AccountsListDialog({ super.key });

  @override
  State<AccountsListDialog> createState() => _AccountsListDialogState();
}

class _AccountsListDialogState extends State<AccountsListDialog> {

  List<Account>? accounts;
  var databaseService = GetIt.instance.get<DatabaseService>();
  var logger = GetIt.instance.get<Logger>();

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
        this.accounts = accounts;
      });
    } catch (error, stackTrace) {
      logger.e('Error getting accounts', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> openNewAccountDialog() async {
    var result = await showDialog<bool?>(context: context, builder: (context) {
      return const NewAccountDialog();
    });
    if (result != null) {
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildTitle(context),
            const SizedBox(height: 20),
            if (accounts == null)
              const Loader(),
            if (accounts != null)
              ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 25),
                itemBuilder: (context, index) => buildAccountItem(context, accounts![index]),
                separatorBuilder: (context, index) => const Divider(),
                itemCount: accounts!.length
              ),
            const SizedBox(height: 20),
            buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget buildTitle(BuildContext context) {
    return Text('Cuentas', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold));
  }

  Widget buildAccountItem(BuildContext context, Account account) {
    return Row(
      children: [
        Expanded(
          child: Text(account.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        if (accounts!.length > 1)
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red.shade900),
            onPressed: () {
              databaseService.accountsRepository.delete(account.id!);
              if (!context.mounted) return;
              Navigator.of(context).pop(true);
            },
          ),
      ],
    );
  }

  Widget buildActionButtons(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
            style: ButtonStyle(fixedSize: MaterialStateProperty.all(const Size(110, 30))),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancelar', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor))
        ),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              fixedSize: const Size(170, 30),
            ),
            onPressed: () {
              openNewAccountDialog();
            },
            child: const Text('Nueva cuenta', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))
        ),
      ],
    );
  }
}
