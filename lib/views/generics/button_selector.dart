
import 'package:flutter/material.dart';

class ButtonSelector extends StatelessWidget {
  final int? selectedIndex;
  final List<Widget> options;
  final void Function(int)? onSelectionChange;
  final void Function()? onAddButtonPressed;

  const ButtonSelector({ super.key, this.selectedIndex, required this.options, this.onSelectionChange, this.onAddButtonPressed });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      crossAxisAlignment: WrapCrossAlignment.center,
      direction: Axis.horizontal,
      spacing: 10,
      runSpacing: 10,
      children: [
        ...buildOptionButtons(context),
        if (onAddButtonPressed != null)
          buildAddButton(context),
      ],
    );
  }

  List<Widget> buildOptionButtons(BuildContext context) {
    List<Widget> buttons = [];
    for (var i = 0; i < options.length; i++) {
      buttons.add(SizedBox(
        height: 30,
        child: OutlinedButton(
          onPressed: () {
            if (onSelectionChange != null) {
              onSelectionChange!(i);
            }
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            backgroundColor: i == selectedIndex ? Colors.grey.shade400 : Colors.transparent,
          ),
          child: options[i],
        ),
      ));
    }
    return buttons;
  }

  Widget buildAddButton(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: OutlinedButton(
        onPressed: onAddButtonPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
