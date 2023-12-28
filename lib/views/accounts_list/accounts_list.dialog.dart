
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:money/models/account.model.dart';
import 'package:money/repositories/accounts.repository.dart';
import 'package:money/views/generics/currency_selector.dart';
import 'package:money/views/new_account/new_account.dialog.dart';

class AccountsListDialog extends StatefulWidget {
  final List<Account> accounts;

  const AccountsListDialog({ super.key, required this.accounts });

  @override
  State<AccountsListDialog> createState() => _AccountsListDialogState();
}

class _AccountsListDialogState extends State<AccountsListDialog> {

  Future<void> openNewAccountDialog() async {
    var result = await showDialog<Account?>(context: context, builder: (context) {
      return const NewAccountDialog();
    });
    if (result != null) {
      if (!context.mounted) return;
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildTitle(context),
            const SizedBox(height: 20),
            ListView.separated(
              shrinkWrap: true,
              itemBuilder: (context, index) => buildAccountItem(context, widget.accounts[index]),
              separatorBuilder: (context, index) => const Divider(),
              itemCount: widget.accounts.length
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
        IconButton(
          icon: Icon(Icons.delete, color: Colors.red.shade900),
          onPressed: () {
            GetIt.instance.get<AccountsRepository>().delete(account.id!);
            if (!context.mounted) return;
            Navigator.of(context).pop(account);
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
              fixedSize: const Size(150, 30),
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
