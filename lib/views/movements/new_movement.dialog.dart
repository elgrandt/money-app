
import 'package:events_emitter/events_emitter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/category.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/categories/new_category.dialog.dart';
import 'package:money/views/generics/button_selector.dart';
import 'package:money/views/generics/cupertino_select.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';
import 'package:money/views/generics/loader.dart';


class NewMovementDialog extends StatefulWidget {
  final Account? selectedAccount;
  final Movement? movement;

  const NewMovementDialog({ super.key, this.selectedAccount, this.movement });

  @override
  State<NewMovementDialog> createState() => _NewMovementDialogState();
}

class _NewMovementDialogState extends State<NewMovementDialog> {
  Map<MovementType, List<Category>>? categoriesByType;

  final _formKey = GlobalKey<FormState>();
  MovementType movementType = MovementType.REMOVE;
  double amount = 0;
  double conversionRate = 1;
  String? selectedCategory;
  late Account source;
  late Account target;
  late DateTime creationDate;
  List<Account>? accounts;

  final amountInputController = MoneyMaskedTextController(decimalSeparator: ',', thousandSeparator: '.', precision: 2, initialValue: 0);
  final conversionRateInputController = MoneyMaskedTextController(decimalSeparator: ',', thousandSeparator: '.', precision: 2, initialValue: 1);
  final descriptionInputController = TextEditingController();
  var databaseService = GetIt.instance.get<DatabaseService>();
  var utilsService = GetIt.instance.get<UtilsService>();
  var logger = GetIt.instance.get<Logger>();

  EventListener<TableUpdateEvent<Category>>? categoriesListener;

  get canSubmit {
    return _formKey.currentState != null && _formKey.currentState!.validate() && selectedCategory != null;
  }

  get isEditing {
    return widget.movement != null;
  }

  @override
  void initState() {
    super.initState();
    creationDate = DateTime.now();
    getCategories();
    watchCategories();
    getAccounts();
  }

  @override
  void dispose() {
    super.dispose();
    categoriesListener?.cancel();
  }

  Future<void> submit() async {
    await databaseService.initialized;
    if (isEditing) {
      await databaseService.movementsRepository.remove(widget.movement!);
    }
    var result = await databaseService.movementsRepository.create(
      movementType,
      descriptionInputController.text,
      amount,
      conversionRate,
      selectedCategory!,
      source,
      target,
      creationDate
    );
    if (!context.mounted) return;
    Navigator.of(context).pop(result);
  }

  Future<void> openNewCategoryDialog() async {
    await showDialog<Category?>(context: context, builder: (context) {
      return NewCategoryDialog(movementType: movementType);
    });
  }

  void getCategories({ String? selected }) {
    databaseService.categoriesRepository.getCategoriesByType().then((categoriesByType) {
      setState(() {
        this.categoriesByType = categoriesByType;
        selectedCategory = selected;
      });
    });
  }

  void getAccounts() async {
    await databaseService.initialized;
    try {
      var accounts = await databaseService.accountsRepository.find(orderBy: 'sortIndex ASC');
      setState(() {
        this.accounts = accounts;
      });
      if (isEditing) {
        fillFormDataWithMovement(widget.movement!);
      } else {
        setState(() {
          if (widget.selectedAccount != null) {
            source = widget.selectedAccount!;
            target = widget.selectedAccount!;
          } else {
            source = accounts.first;
            target = accounts.first;
          }
        });
      }
    } catch (error, stackTrace) {
      logger.e('Error getting accounts', error: error, stackTrace: stackTrace);
    }
  }

  void watchCategories() {
    categoriesListener = databaseService.categoriesRepository.events.on<TableUpdateEvent<Category>>('change', (event) {
      if (event.type == TableUpdateEventType.INSERT) {
        getCategories(selected: event.model!.name);
      } else {
        getCategories();
      }
    });
  }

  void _showDialog(Widget child) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: child,
        ),
      ),
    );
  }

  void fillFormDataWithMovement(Movement movement) {
    setState(() {
      movementType = movement.type;
      amountInputController.text = movement.amount.toStringAsFixed(2);
      amount = movement.amount;
      source = movement.source ?? movement.target!;
      target = movement.target ?? movement.source!;
      creationDate = movement.creationDate ?? DateTime.now();
      descriptionInputController.text = movement.description;
      conversionRate = movement.conversionRate ?? 1;
      conversionRateInputController.text = conversionRate.toStringAsFixed(2);
      selectedCategory = movement.category;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(10),
      alignment: Alignment.center,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
          child: Column(
            children: [
              buildTitle(context),
              ...buildContent(context),
              const SizedBox(height: 10),
              buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> buildContent(BuildContext context) {
    if (categoriesByType != null && accounts != null) {
      return [
        const SizedBox(height: 10),
        buildTypeSelect(context),
        const SizedBox(height: 10),
        if (movementType == MovementType.TRANSFER || movementType == MovementType.REMOVE)
          buildSourceSelect(context),
        if (movementType == MovementType.TRANSFER || movementType == MovementType.ADD)
          buildTargetSelect(context),
        buildAmountInput(context),
        if (movementType == MovementType.TRANSFER && source.currency != target.currency)
          ...buildConversionRateSection(context),
        const SizedBox(height: 10),
        buildDescriptionInput(context),
        const SizedBox(height: 10),
        buildCreationDateInput(context),
        buildCategorySelector(context),
      ];
    } else {
      return [const Loader()];
    }
  }

  Widget buildTitle(BuildContext context) {
    if (isEditing) {
      return Text('Editar movimiento', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold));
    } else {
      return Text('Nuevo movimiento', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold));
    }
  }

  Widget buildTypeSelect(BuildContext context) {
    return ButtonSelector(
      options: MovementType.values.map((e) => Text(movementTypeNames[e]!)).toList(),
      selectedIndex: MovementType.values.indexOf(movementType),
      onSelectionChange: (index) {
        setState(() {
          movementType = MovementType.values[index];
          selectedCategory = null;
        });
      },
    );
  }

  Widget buildSourceSelect(BuildContext context) {
    return CupertinoSelect(
      label: 'Desde',
      options: accounts!.map((e) => e.name).toList(),
      selectedIndex: accounts!.indexOf(source),
      onSelectedIndexChange: (index) {
        setState(() {
          source = accounts![index];
        });
      },
    );
  }

  Widget buildTargetSelect(BuildContext context) {
    return CupertinoSelect(
      label: 'Hacia',
      options: accounts!.map((account) => account.name).toList(),
      selectedIndex: accounts!.indexOf(target),
      onSelectedIndexChange: (index) {
        setState(() {
          target = accounts![index];
          if (categoriesByType![movementType]!.isNotEmpty) {
            selectedCategory = categoriesByType![movementType]!.first.name;
          }
        });
      },
    );
  }

  Widget buildAmountInput(BuildContext context) {
    Currency currency = movementType == MovementType.ADD ? target.currency : movementType == MovementType.REMOVE ? source.currency : movementType == MovementType.TRANSFER ? source.currency : Currency.ARS;
    return IntrinsicWidth(
      child: TextFormField(
        autofocus: true,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, height: 1),
        controller: amountInputController,
        decoration: InputDecoration(
          border: InputBorder.none,
          suffix: Text(utilsService.getCurrencySymbol(currency), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.black)),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
        validator: (value) {
          if (value == null) return '';
          value = value.replaceAll('.', '');
          value = value.replaceAll(',', '');
          value = value.replaceAll(' ', '');
          if (value.isEmpty || double.tryParse(value) == null || double.tryParse(value) == 0) {
            return '';
          }
          return null;
        },
        onChanged: (value) {
          setState(() {
            value = value.replaceAll('.', '');
            value = value.replaceAll(',', '');
            value = value.replaceAll(' ', '');
            if (double.tryParse(value) != null) {
              amount = double.tryParse(value)! / 100;
            }
          });
        },
      ),
    );
  }

  List<Widget> buildConversionRateSection(BuildContext context) {
    return [
      Text('Recibís ${utilsService.beautifyCurrency(amount * conversionRate, target.currency)}'),
      IntrinsicWidth(
        child: TextFormField(
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1),
          controller: conversionRateInputController,
          decoration: const InputDecoration(
            border: InputBorder.none,
            prefix: Text('Tasa de conversión ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            suffix: Text('x', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            errorStyle: TextStyle(height: 0, fontSize: 0),
          ),
          validator: (value) {
            if (value == null) return '';
            value = value.replaceAll(',', '');
            value = value.replaceAll('.', '');
            value = value.replaceAll(' ', '');
            if (value.isEmpty || double.tryParse(value) == null || double.tryParse(value) == 0) {
              return '';
            }
            return null;
          },
          onChanged: (value) {
            setState(() {
              value = value.replaceAll(',', '');
              value = value.replaceAll('.', '');
              value = value.replaceAll(' ', '');
              if (double.tryParse(value) != null) {
                conversionRate = double.tryParse(value)! / 100;
              }
            });
          },
        ),
      )
    ];
  }

  Widget buildDescriptionInput(BuildContext context) {
    return TextFormField(
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.sentences,
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

  Widget buildCreationDateInput(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        _showDialog(
          CupertinoDatePicker(
            mode: CupertinoDatePickerMode.dateAndTime,
            initialDateTime: creationDate,
            maximumDate: DateTime.now(),
            use24hFormat: true,
            onDateTimeChanged: (date) {
              setState(() {
                creationDate = date;
              });
            },
          )
        );
      },
      child: Text(DateFormat('dd/MM/yyyy HH:mm').format(creationDate), style: const TextStyle(fontSize: 20)),
    );
  }

  Widget buildCategorySelector(BuildContext context) {
    var categories = categoriesByType![movementType]!;
    return Column(
      children: [
        const Text('Categoría', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ButtonSelector(
          options: categories.map((category) => Text(category.name)).toList(),
          selectedIndex: categories.indexWhere((category) => category.name == selectedCategory),
          wrap: false,
          onSelectionChange: (index) {
            setState(() {
              selectedCategory = categories[index].name;
            });
          },
          onAddButtonPressed: () {
            openNewCategoryDialog();
          }
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
          child: Text(isEditing ? 'Guardar' : 'Crear', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))
        ),
      ],
    );
  }
}
