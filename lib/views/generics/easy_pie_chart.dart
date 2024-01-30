
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

enum LabelPosition {
  none,
  left,
  right,
  top,
  bottom,
}

class EasyPieChart<T> extends StatelessWidget {
  final LabelPosition labelPosition;
  final List<T> items;
  final String Function(T item)? label;
  final double Function(T item) value;
  final Random? randomGenerator;
  final double maxHeight;
  final double maxWidth;
  final double maxLabelWidth;
  final List<Color>? colors;

  List<PieChartSectionData> getSections(List<Color> colors) {
    List<PieChartSectionData> sections = [];
    for (var i = 0; i < items.length; i++) {
      var percent = value(items[i]) / total * 100;
      sections.add(PieChartSectionData(
        color: colors[i],
        value: value(items[i]),
        radius: maxWidth != double.infinity ? maxWidth / 2 - 10 : maxHeight != double.infinity ? maxHeight / 2 - 10 : 100,
        title: percent >= 10 ? '${percent.toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    return sections;
  }

  double get total {
    if (items.isEmpty) return 0;
    return items.map((item) => value(item)).reduce((value, element) => value + element);
  }

  const EasyPieChart({ super.key, this.labelPosition = LabelPosition.bottom, required this.items, this.label, required this.value, this.randomGenerator, this.maxHeight = double.infinity, this.maxWidth = double.infinity, this.maxLabelWidth = double.infinity, this.colors });

  @override
  Widget build(BuildContext context) {
    if (total == 0) return Container();
    List<Color> colors = this.colors != null ? this.colors! : items.map((item) => Colors.primaries[randomGenerator!.nextInt(Colors.primaries.length)].shade700).toList();
    if (this.label != null) {
      switch (labelPosition) {
        case LabelPosition.left:
          return Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildChart(context, colors),
              buildLabelsVertical(context, colors),
            ],
          );
        case LabelPosition.right:
          return Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildLabelsVertical(context, colors),
              buildChart(context, colors),
            ],
          );
        case LabelPosition.top:
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildLabelsHorizontal(context, colors),
              buildChart(context, colors),
            ],
          );
        case LabelPosition.bottom:
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildChart(context, colors),
              buildLabelsHorizontal(context, colors),
            ],
          );
        case LabelPosition.none:
          return buildChart(context, colors);
      }
    } else {
      return buildChart(context, colors);
    }
  }

  Widget buildChart(BuildContext context, List<Color> colors) {
    return Container(
      alignment: Alignment.center,
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        maxWidth: maxWidth,
      ),
      child: PieChart(
        PieChartData(
          sections: getSections(colors),
          centerSpaceRadius: 0,
        ),
        swapAnimationDuration: const Duration(milliseconds: 150),
        swapAnimationCurve: Curves.linear,
      ),
    );
  }

  Widget buildLabelsVertical(BuildContext context, List<Color> colors) {
    List<Widget> widgets = [];
    for (var i = 0; i < items.length; i++) {
      widgets.add(buildLabel(context, items[i], colors[i]));
      if (i != items.length - 1) widgets.add(const SizedBox(height: 4));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widgets
      ],
    );
  }

  Widget buildLabelsHorizontal(BuildContext context, List<Color> colors) {
    List<Widget> widgets = [];
    for (var i = 0; i < items.length; i++) {
      widgets.add(buildLabel(context, items[i], colors[i]));
    }
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
          ...widgets
      ],
    );
  }

  Widget buildLabel(BuildContext context, T item, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(Radius.circular(20))
          ),
        ),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxLabelWidth,
          ),
          child: Text(label!(item), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}