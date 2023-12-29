
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/generics/button_selector.dart';
import 'package:money/views/generics/cupertino_select.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';


class NewMovementDialog extends StatefulWidget {
  final List<Account> accounts;
  final Account? selectedAccount;

  const NewMovementDialog({ super.key, required this.accounts, this.selectedAccount });

  @override
  State<NewMovementDialog> createState() => _NewMovementDialogState();
}

class _NewMovementDialogState extends State<NewMovementDialog> {
  static var movementTypeNames = {
    MovementType.ADD: 'Ingreso',
    MovementType.REMOVE: 'Gasto',
    MovementType.TRANSFER: 'Transferencia',
  };

  Map<MovementType, List<String>>? categoriesByType = {
    MovementType.ADD: ['Sueldo', 'Préstamo', 'Otro'],
    MovementType.REMOVE: ['Comida', 'Transporte', 'Casa', 'Limpieza', 'Gasto fijo', 'Otro'],
    MovementType.TRANSFER: ['Movimiento', 'Cambio de moneda', 'Otro'],
  };

  final _formKey = GlobalKey<FormState>();
  MovementType movementType = MovementType.REMOVE;
  double amount = 0;
  String category = 'Otro';
  late Account source;
  late Account target;

  final amountInputController = MoneyMaskedTextController(decimalSeparator: '', thousandSeparator: '.', precision: 0);
  final descriptionInputController = TextEditingController();
  var databaseService = GetIt.instance.get<DatabaseService>();

  get canSubmit {
    return _formKey.currentState != null && _formKey.currentState!.validate();
  }

  @override
  void initState() {
    super.initState();
    if (widget.selectedAccount != null) {
      source = widget.selectedAccount!;
      target = widget.selectedAccount!;
    } else {
      source = widget.accounts.first;
      target = widget.accounts.first;
    }
  }

  Future<void> submit() async {
    var movement = Movement(
      movementType,
      descriptionInputController.text,
      amount,
      category,
      source: movementType == MovementType.REMOVE || movementType == MovementType.TRANSFER ? source : null,
      target: movementType == MovementType.ADD || movementType == MovementType.TRANSFER ? target : null,
    );
    await databaseService.initialized;
    var result = await databaseService.movementsRepository.insert(movement);
    if (!context.mounted) return;
    Navigator.of(context).pop(result);
  }

  void reset() {
    setState(() {
      amountInputController.text = '0';
      descriptionInputController.text = '';
      category = 'Otro';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.center,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
          child: Column(
            children: [
              buildTitle(context),
              const SizedBox(height: 10),
              buildTypeSelect(context),
              const SizedBox(height: 10),
              if (movementType == MovementType.TRANSFER || movementType == MovementType.REMOVE)
                buildSourceSelect(context),
              if (movementType == MovementType.TRANSFER || movementType == MovementType.ADD)
                buildTargetSelect(context),
              buildAmountInput(context),
              const SizedBox(height: 10),
              buildDescriptionInput(context),
              const SizedBox(height: 10),
              buildCategorySelector(context),
              const SizedBox(height: 10),
              buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTitle(BuildContext context) {
    return Text('Nuevo movimiento', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold));
  }

  Widget buildTypeSelect(BuildContext context) {
    return ButtonSelector(
      options: MovementType.values.map((e) => Text(movementTypeNames[e]!)).toList(),
      selectedIndex: MovementType.values.indexOf(movementType),
      onSelectionChange: (index) {
        setState(() {
          movementType = MovementType.values[index];
        });
        reset();
      },
    );
  }

  Widget buildSourceSelect(BuildContext context) {
    return CupertinoSelect(
      label: 'Desde',
      options: widget.accounts.map((e) => e.name).toList(),
      selectedIndex: widget.accounts.indexOf(source),
      onSelectedIndexChange: (index) {
        setState(() {
          source = widget.accounts[index];
        });
        reset();
      },
    );
  }

  Widget buildTargetSelect(BuildContext context) {
    return CupertinoSelect(
      label: 'Hacia',
      options: widget.accounts.map((account) => account.name).toList(),
      selectedIndex: widget.accounts.indexOf(target),
      onSelectedIndexChange: (index) {
        setState(() {
          target = widget.accounts[index];
        });
        reset();
      },
    );
  }

  Widget buildAmountInput(BuildContext context) {
    Currency currency = movementType == MovementType.ADD ? target.currency : movementType == MovementType.REMOVE ? source.currency : movementType == MovementType.TRANSFER ? target.currency : Currency.ARS;
    return IntrinsicWidth(
      child: TextFormField(
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        controller: amountInputController,
        decoration: InputDecoration(
          border: InputBorder.none,
          suffix: Text(GetIt.instance.get<UtilsService>().getCurrencySymbol(currency), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.black)),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
        validator: (value) {
          if (value == null || value.isEmpty || double.tryParse(value) == null || double.tryParse(value) == 0) {
            return '';
          }
          return null;
        },
        onChanged: (value) {
          setState(() {
            value = value.replaceAll('.', '');
            value = value.replaceAll(' ', '');
            if (double.tryParse(value) != null) {
              amount = double.tryParse(value)!;
            }
          });
        },
      ),
    );
  }

  Widget buildDescriptionInput(BuildContext context) {
    return TextFormField(
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        labelText: 'Descripción',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(),
        floatingLabelAlignment: FloatingLabelAlignment.center,
        contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 0),
      ),
      controller: descriptionInputController,
    );
  }

  Widget buildCategorySelector(BuildContext context) {
    if (categoriesByType == null) return Container();
    var categories = categoriesByType![movementType]!;
    return Column(
      children: [
        const Text('Categoría', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ButtonSelector(
          options: categories.map((category) => Text(category)).toList(),
          selectedIndex: categories.indexOf(category),
          onSelectionChange: (index) {
            setState(() {
              category = categories[index];
            });
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
