
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class Tab {
  String name;
  Widget body;

  Tab({ required this.name, required this.body });
}

class Tabs extends StatefulWidget {
  final List<Tab> tabs;
  final void Function(int)? onSelectedTabChange;

  const Tabs({ super.key, required this.tabs, this.onSelectedTabChange });

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  Tab? selectedTab;

  @override
  void initState() {
    super.initState();
    if (widget.tabs.isNotEmpty) {
      selectedTab = widget.tabs.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.tabs.isNotEmpty ? Column(
      children: [
        TabSelector(
          tabs: widget.tabs,
          onTabChange: (tab) => setState(() {
            selectedTab = tab;
            if (widget.onSelectedTabChange != null) {
              widget.onSelectedTabChange!(widget.tabs.indexWhere((element) => element.name == tab.name));
            }
          }),
        ),
        Expanded(
          child: Container(
            child: getSelectedTabWidget(),
          )
        ),
      ],
    ) : const Placeholder();
  }

  Widget getSelectedTabWidget() {
    if (selectedTab == null) return const Placeholder();
    return widget.tabs.firstWhere((tab) => tab.name == selectedTab!.name).body;
  }
}

class TabSelector extends StatefulWidget {
  final List<Tab> tabs;
  final void Function(Tab tab)? onTabChange;

  const TabSelector({ super.key, required this.tabs, this.onTabChange });

  @override
  State<TabSelector> createState() => _TabSelectorState();
}

class _TabSelectorState extends State<TabSelector> {
  final double padding = 50;
  Tab? selected;
  var scrollController = ScrollController();
  List<GlobalKey> keys = [];

  @override
  void initState() {
    super.initState();
    for (var _ in widget.tabs) {
      keys.add(GlobalKey());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.tabs.isNotEmpty) {
        select(widget.tabs.first, instant: true);
      }
    });
  }

  bool isSelected(Tab tab) {
    return selected != null ? tab.name == selected!.name : false;
  }

  int tabIndex(Tab tab) {
    return widget.tabs.indexWhere((current) => current.name == tab.name);
  }

  int? selectedTabIndex() {
    return selected != null ? tabIndex(selected!) : null;
  }

  void nextTab() {
    if (selected != null) {
      var index = selectedTabIndex()!;
      if (index + 1 < widget.tabs.length) {
        select(widget.tabs[index + 1]);
      }
    }
  }

  void previousTab() {
    if (selected != null) {
      var index = selectedTabIndex()!;
      if (index - 1 >= 0) {
        select(widget.tabs[index - 1]);
      }
    }
  }

  void select(Tab tab, { instant = false }) {
    setState(() {
      selected = tab;
    });
    if (scrollController.hasClients) {
      if (selected != null) {
        double offset = 500 + padding;
        var windowSize = MediaQuery.of(context).size;
        for (var tab in widget.tabs) {
          var renderObject = keys[tabIndex(tab)].currentContext?.findRenderObject() as RenderBox?;
          if (renderObject != null) {
            var size = renderObject.size;
            if (tab.name == selected!.name) {
              offset -= windowSize.width / 2 - size.width / 2;
              break;
            } else {
              offset += size.width;
            }
          }
        }
        if (instant) {
          scrollController.jumpTo(offset);
        } else {
          scrollController.animateTo(offset, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        }
      }
    }
    if (widget.onTabChange != null) {
      widget.onTabChange!(tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 50,
          padding: EdgeInsets.symmetric(horizontal: padding),
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            controller: scrollController,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 500),
              child: Row(
                children: widget.tabs.map((tab) => TextButton(
                  key: keys[widget.tabs.indexOf(tab)],
                  onPressed: () => select(tab),
                  child: Text(tab.name, style: TextStyle(fontSize: 20, color: selected != null && selected!.name == tab.name ? Colors.black87 : Colors.black38)),
                )).toList(),
              ),
            ),
          ),
        ),
        Positioned(
          top: 1,
          right: 5,
          child: IconButton(
            icon: const Icon(Icons.keyboard_arrow_right),
            onPressed: nextTab,
          )
        ),
        Positioned(
            top: 1,
            left: 5,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_left),
              onPressed: previousTab,
            )
        ),
      ],
    );
  }
}
