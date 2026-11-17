import 'package:material_ui/material_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';

enum VoiceSummaryResult {
  created,
  modify,
}

class VoiceMovementSummaryDialog extends StatefulWidget {
  final Movement movement;

  const VoiceMovementSummaryDialog({ super.key, required this.movement });

  @override
  State<VoiceMovementSummaryDialog> createState() => _VoiceMovementSummaryDialogState();
}

class _VoiceMovementSummaryDialogState extends State<VoiceMovementSummaryDialog> {
  var databaseService = GetIt.instance.get<DatabaseService>();
  var utilsService = GetIt.instance.get<UtilsService>();
  var logger = GetIt.instance.get<Logger>();
  final rateFormat = NumberFormat('#,##0.00', 'es_AR');
  bool creating = false;

  Movement get movement {
    return widget.movement;
  }

  bool get isCrossCurrencyTransfer {
    return movement.type == MovementType.TRANSFER && movement.source!.currency != movement.target!.currency;
  }

  Account get amountAccount {
    return movement.source ?? movement.target!;
  }

  String get amountText {
    return utilsService.beautifyCurrency(movement.amount, amountAccount.currency);
  }

  String get receivedText {
    return utilsService.beautifyCurrency(movement.amount * movement.conversionRate!, movement.target!.currency);
  }

  String get rateText {
    var source = movement.source!.currency;
    var target = movement.target!.currency;
    var shownRate = utilsService.isRateInverse(source, target) ? 1 / movement.conversionRate! : movement.conversionRate!;
    return rateFormat.format(shownRate);
  }

  String get dateText {
    return DateFormat('dd/MM/yyyy HH:mm').format(movement.creationDate!.toLocal());
  }

  Future<void> create() async {
    if (creating) return;
    setState(() {
      creating = true;
    });
    await databaseService.initialized;
    try {
      await databaseService.movementsRepository.create(
        movement.type,
        movement.description,
        movement.amount,
        movement.conversionRate ?? 0,
        movement.category,
        movement.source ?? movement.target!,
        movement.target ?? movement.source!,
        movement.creationDate,
      );
      if (!mounted) return;
      Navigator.of(context).pop(VoiceSummaryResult.created);
    } catch (error, stackTrace) {
      logger.e('Error creating voice movement', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(10),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildTitle(context),
            const SizedBox(height: 15),
            ...buildAttributes(context),
            const SizedBox(height: 20),
            buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget buildTitle(BuildContext context) {
    return Text('Resumen del movimiento', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold));
  }

  List<Widget> buildAttributes(BuildContext context) {
    return [
      buildAttribute('Tipo', movementTypeNames[movement.type]!),
      if (movement.type == MovementType.TRANSFER) ...[
        buildAttribute('Desde', movement.source!.name),
        buildAttribute('Hacia', movement.target!.name),
      ] else
        buildAttribute('Cuenta', amountAccount.name),
      buildAttribute('Monto', amountText),
      if (isCrossCurrencyTransfer && movement.conversionRate != null) ...[
        buildAttribute('Tasa de conversión', rateText),
        buildAttribute('Recibe', receivedText),
      ],
      buildAttribute('Categoría', movement.category),
      if (movement.description != '')
        buildAttribute('Descripción', movement.description),
      buildAttribute('Fecha y hora', dateText),
    ];
  }

  Widget buildAttribute(String name, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget buildActionButtons(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          style: ButtonStyle(fixedSize: WidgetStateProperty.all(const Size(120, 30))),
          onPressed: creating ? null : () {
            Navigator.of(context).pop(VoiceSummaryResult.modify);
          },
          child: Text('Modificar', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: creating ? Theme.of(context).disabledColor : Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            fixedSize: const Size(120, 30),
          ),
          onPressed: creating ? null : create,
          child: const Text('Crear', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }
}
