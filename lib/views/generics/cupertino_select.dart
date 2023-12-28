
import 'package:flutter/cupertino.dart';

class CupertinoSelect extends StatelessWidget {
  final int selectedIndex;
  final List<String> options;
  final void Function(int)? onSelectedIndexChange;
  final String? label;
  final TextStyle? labelStyle;

  const CupertinoSelect({ super.key, required this.options, this.selectedIndex = 0, this.onSelectedIndexChange, this.label, this.labelStyle });

  // This shows a CupertinoModalPopup with a reasonable fixed height which hosts CupertinoPicker.
  void _showDialog(BuildContext context, Widget child) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        // The Bottom margin is provided to align the popup above the system navigation bar.
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        // Provide a background color for the popup.
        color: CupertinoColors.systemBackground.resolveFrom(context),
        // Use a SafeArea widget to avoid system overlaps.
        child: SafeArea(
          top: false,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Text('$label:', style: labelStyle ?? const TextStyle(fontSize: 16)),
        if (label != null)
          const SizedBox(width: 2),
        SizedBox(
          height: 30,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showDialog(
              context,
              CupertinoPicker(
                magnification: 1.22,
                squeeze: 1.2,
                itemExtent: 32.0,
                useMagnifier: true,
                // This sets the initial item.
                scrollController: FixedExtentScrollController(
                  initialItem: selectedIndex,
                ),
                // This is called when selected item is changed.
                onSelectedItemChanged: onSelectedIndexChange,
                children: List<Widget>.generate(options.length, (int index) {
                  return Center(child: Text(options[index]));
                }),
              ),
            ),
            child: Text(options[selectedIndex], overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}
