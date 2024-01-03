
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:money/models/account.model.dart';
import 'package:money/services/database.service.dart';
import 'package:money/views/generics/currency_selector.dart';

class NewAccountDialog extends StatefulWidget {
  const NewAccountDialog({super.key});

  @override
  State<NewAccountDialog> createState() => _NewAccountDialogState();
}

class _NewAccountDialogState extends State<NewAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  Currency currency = Currency.ARS;
  final nameInputController = TextEditingController();
  var databaseService = GetIt.instance.get<DatabaseService>();

  get canSubmit {
    return _formKey.currentState != null && _formKey.currentState!.validate();
  }

  Future<void> submit() async {
    var account = Account(
      name: nameInputController.text,
      total: 0,
      currency: currency,
    );
    await databaseService.initialized;
    var result = await databaseService.accountsRepository.insert(account);
    if (!context.mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.center,
      child: Form(
        key: _formKey,
        onChanged: () => setState(() { }),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
          child: Column(
            children: [
              buildTitle(context),
              const SizedBox(height: 20),
              buildNameInput(context),
              const SizedBox(height: 10),
              buildCurrencySelector(context),
              const SizedBox(height: 20),
              buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTitle(BuildContext context) {
    return Text('Nueva cuenta', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold));
  }

  Widget buildNameInput(BuildContext context) {
    return TextFormField(
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Nombre de la cuenta',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(),
        floatingLabelAlignment: FloatingLabelAlignment.center,
        contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 0),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor ingrese un nombre';
        }
        return null;
      },
      controller: nameInputController,
    );
  }

  Widget buildCurrencySelector(BuildContext context) {
    return Column(
      children: [
        const Text('Moneda', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
        const SizedBox(height: 5),
        CurrencySelector(selected: currency, onSelectionChange: (newValue) => setState(() { currency = newValue; })),
      ],
    );
  }

  Widget buildActionButtons(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
            style: ButtonStyle(fixedSize: MaterialStateProperty.all(const Size(120, 30))),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancelar', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor))
        ),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? Theme.of(context).primaryColor : Theme.of(context).disabledColor,
              foregroundColor: Colors.white,
              fixedSize: const Size(120, 30),
            ),
            onPressed: canSubmit ? () {
              submit();
            } : null,
            child: const Text('Crear', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))
        ),
      ],
    );
  }
}
