import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money/models/account.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/views/generics/currency_selector.dart';
import 'package:money/views/home/movements_list.dart';

class CategoryMovementsDialog extends StatefulWidget {
  final String category;
  final DateTime dateFrom;
  final DateTime dateTo;
  final MovementType movementType;
  final Account? account;
  final Currency initialCurrency;

  const CategoryMovementsDialog({ super.key, required this.category, required this.dateFrom, required this.dateTo, required this.movementType, required this.initialCurrency, this.account });

  @override
  State<CategoryMovementsDialog> createState() => _CategoryMovementsDialogState();
}

class _CategoryMovementsDialogState extends State<CategoryMovementsDialog> {
  late Currency currency = widget.initialCurrency;

  get title => 'Movimientos de ${ widget.category }';

  get description => 'Del ${ formatDate(widget.dateFrom) } al ${ formatDate(widget.dateTo) }';

  String formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

  double getDialogHeight(BuildContext context) {
    return MediaQuery.of(context).size.height * 0.55;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
        child: SizedBox(
          height: getDialogHeight(context),
          child: Column(
            children: [
              buildTitle(context),
              const SizedBox(height: 10),
              buildDescription(context),
              const SizedBox(height: 15),
              CurrencySelector(selected: currency, onSelectionChange: (newValue) => setState(() { currency = newValue; })),
              const SizedBox(height: 15),
              MovementsList(
                currency: currency,
                account: widget.account,
                movementTypeFilter: widget.movementType,
                categoryFilter: widget.category,
                dateFromFilter: widget.dateFrom,
                dateToFilter: widget.dateTo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget buildDescription(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Text(
        description,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16),
      ),
    );
  }
}
