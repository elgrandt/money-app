
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:money/views/accounts_list/accounts_list.dialog.dart';

class Navbar extends StatefulWidget {
  final Widget body;
  final FloatingActionButton? floatingActionButton;

  const Navbar({ super.key, required this.body, this.floatingActionButton });

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {

  void openMenu() async {
    await showDialog<void>(context: context, builder: (context) {
      return const NavigationMenu();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Money'),
        centerTitle: true,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: openMenu,
            icon: const Icon(Icons.menu),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
      body: widget.body,
    );
  }
}

class NavigationMenu extends StatelessWidget {
  const NavigationMenu({ super.key });

  void openAccountListDialog(BuildContext context) async {
    Navigator.of(context).pop();
    await showDialog<bool?>(context: context, builder: (context) {
      return const AccountsListDialog();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => openAccountListDialog(context),
            child: const Text('Editar cuentas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 20),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => null,
            child: const Text('Editar categorías', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
