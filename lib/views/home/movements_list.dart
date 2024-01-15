import 'package:events_emitter/events_emitter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/generics/loader.dart';
import 'package:money/views/movements/movement_details.dialog.dart';

class MovementsList extends StatefulWidget {
  final Account? account;
  final Currency currency;

  const MovementsList({ super.key, required this.currency, this.account });

  @override
  State<MovementsList> createState() => MovementsListState();
}

class MovementsListState extends State<MovementsList> {
  List<Movement>? movements;
  int page = 0;
  int itemsPerPage = 10;
  var databaseService = GetIt.instance.get<DatabaseService>();
  EventListener<TableUpdateEvent<Movement>>? movementsListener;

  @override
  void initState() {
    super.initState();
    getMovements();
  }

  @override
  void dispose() {
    super.dispose();
    movementsListener?.cancel();
  }

  @override
  didUpdateWidget(MovementsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (movements == null || widget.account?.name != oldWidget.account?.name) {
      getMovements();
    }
  }

  Future<void> watchMovementChanges() async {
    await databaseService.initialized;
    movementsListener = databaseService.movementsRepository.events.on<TableUpdateEvent<Movement>>('change', (event) {
      getMovements();
    });
  }

  Future<void> getMovements() async {
    await databaseService.initialized;
    try {
      var movements = await databaseService.movementsRepository.getLastMovements(widget.account, page, itemsPerPage);
      setState(() {
        this.movements = movements;
      });
    } catch (error, stackTrace) {
      GetIt.instance.get<Logger>().e('Error getting movements', error: error, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return movements == null ? const Loader() :
      movements!.isEmpty ? buildEmptyMessage(context) :
      Expanded(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: movements!.length,
          scrollDirection: Axis.vertical,
          padding: const EdgeInsets.only(bottom: 80),
          itemBuilder: (BuildContext context, int index) => MovementListItem(movement: movements![index], currency: widget.currency, account: widget.account),
          separatorBuilder: (BuildContext context, int index) => const Divider(height: 0),
        ),
      );
  }

  Widget buildEmptyMessage(BuildContext context) {
    return const Expanded(child: Text('No se encontraron movimientos'));
  }
}

class MovementListItem extends StatelessWidget {
  final Movement movement;
  final Currency currency;
  final Account? account;

  get amount {
    if (movement.conversionRate != null && account?.id == movement.target?.id) {
      return movement.conversionRate! * movement.amount;
    } else {
      return movement.amount;
    }
  }

  const MovementListItem({ super.key, required this.movement, required this.currency, this.account });

  Color getMovementTypeColor(MovementType movementType) {
    if (movementType == MovementType.ADD) {
      return Colors.green.shade900;
    } else if (movementType == MovementType.REMOVE) {
      return Colors.red.shade900;
    } else if (movementType == MovementType.TRANSFER) {
      if (account == null) {
        return Colors.yellow.shade900;
      } else {
        if (movement.source != null && movement.source!.id == account!.id) {
          return Colors.red.shade900;
        }
        if (movement.target != null && movement.target!.id == account!.id) {
          return Colors.green.shade900;
        }
        return Colors.yellow.shade900;
      }
    } else {
      return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await showDialog<bool?>(context: context, builder: (context) {
          return MovementDetailsDialog(movement: movement);
        });
      },
      child: Container(
        color: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 15),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                buildCategory(context),
                const SizedBox(width: 20),
                buildAmount(context),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                buildDescription(context),
                const SizedBox(width: 20),
                if (movement.source != null && movement.target != null)
                  buildAccounts(context),
                if ((movement.source == null || movement.target == null) && movement.creationDate != null)
                  buildDate(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCategory(BuildContext context) {
    return Expanded(
      child: Text(
        movement.category,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
      ),
    );
  }

  Widget buildAmount(BuildContext context) {
    var utilsService = GetIt.instance.get<UtilsService>();
    return Text(
      utilsService.beautifyCurrency(utilsService.convertCurrencies(amount, account?.currency ?? currency, currency), currency),
      overflow: TextOverflow.visible,
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: getMovementTypeColor(movement.type))
    );
  }

  Widget buildDescription(BuildContext context) {
    return Expanded(
      child: Text(
        movement.description.isNotEmpty ? movement.description : '',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14)
      ),
    );
  }
  
  Widget buildAccounts(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        movement.source != null ? Row(
          children: [
            Text(movement.source!.name, overflow: TextOverflow.ellipsis),
            Icon(CupertinoIcons.arrow_down_right, size: 18, color: Colors.red.shade900),
          ],
        ) : Container(),
        movement.target != null ? Row(
          children: [
            Text(movement.target!.name, overflow: TextOverflow.ellipsis),
            Icon(CupertinoIcons.arrow_up_right, size: 18, color: Colors.green.shade900),
          ],
        ) : Container(),
      ],
    );
  }

  Widget buildDate(BuildContext context) {
    var text = '${movement.creationDate!.day}/${movement.creationDate!.month}/${movement.creationDate!.year}';
    var today = DateTime.now();
    var yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (movement.creationDate!.day == today.day && movement.creationDate!.month == today.month && movement.creationDate!.year == today.year) {
      text = 'Hoy';
    } else if (movement.creationDate!.day == yesterday.day && movement.creationDate!.month == yesterday.month && movement.creationDate!.year == yesterday.year) {
      text = 'Ayer';
    }
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
    );
  }
}