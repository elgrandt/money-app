
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/movements/new_movement.dialog.dart';

class MovementDetailsDialog extends StatefulWidget {
  final Movement movement;

  const MovementDetailsDialog({ super.key, required this.movement });

  @override
  State<MovementDetailsDialog> createState() => _MovementDetailsDialogState();
}

class _MovementDetailsDialogState extends State<MovementDetailsDialog> {
  var utilsService = GetIt.instance.get<UtilsService>();
  var databaseService = GetIt.instance.get<DatabaseService>();

  List<TextSpan> getText() {
    if (widget.movement.type == MovementType.ADD) {
      return [
        const TextSpan(text: 'Se ingresaron '),
        TextSpan(text: utilsService.beautifyCurrency(widget.movement.amount, widget.movement.target!.currency), style: const TextStyle(fontWeight: FontWeight.bold)),
        const TextSpan(text: ' en '),
        TextSpan(text: widget.movement.target?.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        const TextSpan(text: ' bajo el concepto de '),
        TextSpan(text: widget.movement.category, style: const TextStyle(fontWeight: FontWeight.bold)),
        const TextSpan(text: '.'),
      ];
    } else if (widget.movement.type == MovementType.REMOVE) {
      return [
        const TextSpan(text: 'Se gastaron '),
        TextSpan(text: utilsService.beautifyCurrency(widget.movement.amount, widget.movement.source!.currency), style: const TextStyle(fontWeight: FontWeight.bold)),
        const TextSpan(text: ' de '),
        TextSpan(text: widget.movement.source?.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        const TextSpan(text: ' bajo el concepto de '),
        TextSpan(text: widget.movement.category, style: const TextStyle(fontWeight: FontWeight.bold)),
        const TextSpan(text: '.'),
      ];
    } else if (widget.movement.type == MovementType.TRANSFER) {
      if (widget.movement.conversionRate != null) {
        return [
          const TextSpan(text: 'Se transfirieron '),
          TextSpan(text: utilsService.beautifyCurrency(widget.movement.amount, widget.movement.source!.currency), style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: ' desde '),
          TextSpan(text: widget.movement.source?.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: ' y '),
          TextSpan(text: widget.movement.target?.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: ' recibió '),
          TextSpan(text: utilsService.beautifyCurrency(widget.movement.amount * widget.movement.conversionRate!, widget.movement.target!.currency), style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: ' bajo el concepto de '),
          TextSpan(text: widget.movement.category, style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: '.'),
        ];
      } else {
        return [
          const TextSpan(text: 'Se transfirieron '),
          TextSpan(text: utilsService.beautifyCurrency(widget.movement.amount, widget.movement.source!.currency), style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: ' desde '),
          TextSpan(text: widget.movement.source?.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: ' hacia '),
          TextSpan(text: widget.movement.target?.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: ' bajo el concepto de '),
          TextSpan(text: widget.movement.category, style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: '.'),
        ];
      }
    }
    return [];
  }

  openDeleteMovementConfirmationDialog() async {
    var result = await utilsService.confirm(context, title: 'Eliminar movimiento', message: '¿Estás seguro que deseas eliminar este movimiento?');
    if (result == true) {
      await databaseService.movementsRepository.remove(widget.movement);
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  openEditMovementDialog(BuildContext context) async {
    var result = await showDialog<Movement?>(context: context, builder: (context) {
      return NewMovementDialog(movement: widget.movement);
    });
    if (result != null) {
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          buildTitle(context),
          const SizedBox(height: 10),
          buildText(context),
          if (widget.movement.description != '')
            ...buildDescription(context),
          if (widget.movement.creationDate != null)
            ...buildDate(context),
          const SizedBox(height: 5),
          buildActionButtons(context),
        ],
      ),
    );
  }

  Widget buildTitle(BuildContext context) {
    return Text('Detalles del movimiento', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold));
  }

  Widget buildText(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18),
        children: getText()
      )
    );
  }

  List<Widget> buildDescription(BuildContext context) {
    return [
      const SizedBox(height: 10),
      const Text('Descripción', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      Text(widget.movement.description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
    ];
  }

  List<Widget> buildDate(BuildContext context) {
    var date = widget.movement.creationDate!.toLocal();
    return [
      const SizedBox(height: 10),
      const Text('Fecha y hora', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      Text('${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
    ];
  }

  Widget buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => openEditMovementDialog(context),
          child: const Text('Editar movimiento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: () => openDeleteMovementConfirmationDialog(),
          style: ElevatedButton.styleFrom(
            primary: Theme.of(context).colorScheme.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
          ),
          child: const Text('Eliminar movimiento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
