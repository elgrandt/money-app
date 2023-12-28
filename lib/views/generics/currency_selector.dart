
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:money/models/account.model.dart';
import 'package:money/services/utils.service.dart';
import 'package:money/views/generics/button_selector.dart';

class CurrencySelector extends StatelessWidget {
  final Currency selected;
  final void Function(Currency)? onSelectionChange;

  const CurrencySelector({ super.key, required this.selected, this.onSelectionChange });

  @override
  Widget build(BuildContext context) {
    return ButtonSelector(
      selectedIndex: Currency.values.indexOf(selected),
      options: Currency.values.map((currency) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GetIt.instance.get<UtilsService>().getCurrencyIcon(currency),
          const SizedBox(width: 10),
          Text(currency.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      )).toList(),
      onSelectionChange: (index) => onSelectionChange?.call(Currency.values[index]),
    );
  }
}
