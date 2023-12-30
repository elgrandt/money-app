import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/generics/loader.dart';

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

  @override
  void initState() {
    super.initState();
    getMovements();
  }

  @override
  didUpdateWidget(MovementsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (movements == null || widget.account?.name != oldWidget.account?.name) {
      getMovements();
    }
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
          itemBuilder: (BuildContext context, int index) => MovementListItem(movement: movements![index], currency: widget.currency, account: widget.account),
          separatorBuilder: (BuildContext context, int index) => const Divider(),
        ),
      );
  }

  Widget buildEmptyMessage(BuildContext context) {
    return const Text('No se encontaron movimientos');
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
    var utilsService = GetIt.instance.get<UtilsService>();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(movement.description.isNotEmpty ? movement.description : '<sin descripción>', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(width: 20),
              Text(
                utilsService.beautifyCurrency(utilsService.convertCurrencies(amount, account?.currency ?? currency, currency), currency),
                overflow: TextOverflow.visible,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: getMovementTypeColor(movement.type))
              )
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(movement.category),
              Column(
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}