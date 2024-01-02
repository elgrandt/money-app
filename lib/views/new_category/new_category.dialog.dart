
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/services/database.service.dart';

class NewCategoryDialog extends StatefulWidget {
  final MovementType movementType;

  const NewCategoryDialog({ super.key, required this.movementType });

  @override
  State<NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<NewCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final nameInputController = TextEditingController();
  var databaseService = GetIt.instance.get<DatabaseService>();

  get canSubmit {
    return _formKey.currentState != null && _formKey.currentState!.validate();
  }

  Future<void> submit() async {
    await databaseService.initialized;
    var result = await databaseService.categoriesRepository.create(widget.movementType, nameInputController.text);
    if (!context.mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 25),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 25),
        child: Form(
          key: _formKey,
          onChanged: () => setState(() { }),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildTitle(context),
              const SizedBox(height: 20),
              buildNameField(context),
              const SizedBox(height: 10),
              buildActionButtons(context),
            ],
          ),
        ),
      )
    );
  }

  Widget buildTitle(BuildContext context) {
    return Text('Nueva categoría', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold));
  }

  Widget buildNameField(BuildContext context) {
    return TextFormField(
      autofocus: true,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        labelText: 'Nombre',
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

  Widget buildActionButtons(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          style: ButtonStyle(fixedSize: MaterialStateProperty.all(const Size(100, 30))),
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancelar', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor))
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: canSubmit ? Theme.of(context).primaryColor : Theme.of(context).disabledColor,
            foregroundColor: Colors.white,
            fixedSize: const Size(100, 30),
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