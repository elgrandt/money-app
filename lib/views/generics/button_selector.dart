
import 'dart:math';

import 'package:flutter/material.dart';

class ButtonSelector extends StatelessWidget {
  final int? selectedIndex;
  final List<Widget> options;
  final void Function(int)? onSelectionChange;
  final void Function()? onAddButtonPressed;
  final bool wrap;

  const ButtonSelector({ super.key, this.selectedIndex, required this.options, this.onSelectionChange, this.onAddButtonPressed, this.wrap = true });

  @override
  Widget build(BuildContext context) {
    if (wrap) {
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
    } else {
      List<Widget> options = buildOptionButtons(context);
      if (onAddButtonPressed != null) {
        options.add(buildAddButton(context));
      }
      int rowCount = options.length > 2 ? 2 : 1;
      int sliceSize = (options.length / rowCount.toDouble()).ceil();
      List<List<Widget>> rows = [];
      for (var i = 0; i < rowCount; i++) {
        rows.add(options.sublist(i * sliceSize, min((i + 1) * sliceSize, options.length)));
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          spacing: 10,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows.map((columnItems) => Row(
            spacing: 10,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: columnItems,
          )).toList(),
        ),
      );
    }
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
