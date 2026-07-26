import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRangeSelectorDialog extends StatefulWidget {
  final DateTimeRange? initialRange;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String title;

  const DateRangeSelectorDialog({
    super.key,
    this.initialRange,
    this.firstDate,
    this.lastDate,
    this.title = 'Seleccionar rango',
  });

  @override
  State<DateRangeSelectorDialog> createState() => _DateRangeSelectorDialogState();
}

class _DateRangeSelectorDialogState extends State<DateRangeSelectorDialog> {
  late DateTime fromDate;
  late DateTime toDate;

  @override
  void initState() {
    super.initState();
    var now = DateTime.now();
    fromDate = startOfDay(widget.initialRange?.start ?? DateTime(now.year, now.month));
    toDate = startOfDay(widget.initialRange?.end ?? now);
  }

  DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);
  DateTime endOfDay(DateTime date) => DateTime(date.year, date.month, date.day, 23, 59, 59);

  DateTime clampToBounds(DateTime date) {
    if (widget.firstDate != null && date.isBefore(widget.firstDate!)) return widget.firstDate!;
    if (widget.lastDate != null && date.isAfter(widget.lastDate!)) return widget.lastDate!;
    return date;
  }

  bool get canSubmit {
    return !startOfDay(toDate).isBefore(startOfDay(fromDate));
  }

  void submit() {
    Navigator.of(context).pop(DateTimeRange(start: startOfDay(fromDate), end: endOfDay(toDate)));
  }

  void showDatePicker(DateTime initial, void Function(DateTime) onChanged) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: clampToBounds(initial),
            minimumDate: widget.firstDate,
            maximumDate: widget.lastDate,
            onDateTimeChanged: onChanged,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
        child: Column(
          children: [
            buildTitle(context),
            const SizedBox(height: 20),
            buildDateRow(context, 'Desde', fromDate, (date) => setState(() => fromDate = date)),
            const SizedBox(height: 10),
            buildDateRow(context, 'Hasta', toDate, (date) => setState(() => toDate = date)),
            const SizedBox(height: 20),
            buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget buildTitle(BuildContext context) {
    return Text(widget.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold));
  }

  Widget buildDateRow(BuildContext context, String label, DateTime value, void Function(DateTime) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 18)),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => showDatePicker(value, onChanged),
          child: Text(DateFormat('dd/MM/yyyy').format(value), style: const TextStyle(fontSize: 20)),
        ),
      ],
    );
  }

  Widget buildActionButtons(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          style: ButtonStyle(fixedSize: WidgetStateProperty.all(const Size(120, 30))),
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: canSubmit ? Theme.of(context).primaryColor : Theme.of(context).disabledColor,
            foregroundColor: Colors.white,
            fixedSize: const Size(120, 30),
          ),
          onPressed: canSubmit ? submit : null,
          child: const Text('Aplicar', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }
}
