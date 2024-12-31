import 'package:events_emitter/events_emitter.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:money/services/database.service.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/generics/currency_selector.dart';
import 'package:money/views/generics/loader.dart';
import 'package:money/views/home/movements_list.dart';
import 'package:money/views/home/total_viewer.dart';

class AllExpensesChart extends StatefulWidget {
  const AllExpensesChart({super.key});

  @override
  State<AllExpensesChart> createState() => _AllExpensesChartState();
}

class _AllExpensesChartState extends State<AllExpensesChart> {
  Currency currency = Currency.ARS;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: Column(
        children: [
          const SizedBox(height: 10),
          CurrencySelector(selected: currency, onSelectionChange: (newValue) => setState(() { currency = newValue; })),
          const SizedBox(height: 30),
          MovementsList(currency: currency, movementTypeFilter: MovementType.REMOVE,),
        ],
      ),
    );
  }
}