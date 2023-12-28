
import 'package:flutter/material.dart';

class ButtonSelector extends StatelessWidget {
  final int? selectedIndex;
  final List<Widget> options;
  final void Function(int)? onSelectionChange;

  const ButtonSelector({ super.key, this.selectedIndex, required this.options, this.onSelectionChange });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      crossAxisAlignment: WrapCrossAlignment.center,
      direction: Axis.horizontal,
      spacing: 10,
      runSpacing: 10,
      children: options.asMap().map((index, option) => MapEntry(index, SizedBox(
        height: 30,
        child: OutlinedButton(
          onPressed: () {
            if (onSelectionChange != null) {
              onSelectionChange!(index);
            }
          },
          style: ButtonStyle(
            padding: MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.symmetric(horizontal: 16)),
            backgroundColor: MaterialStateProperty.all(index == selectedIndex ? Colors.grey.shade400 : Colors.transparent),
          ),
          child: options[index],
        ),
      ))).values.toList(),
    );
  }
}
