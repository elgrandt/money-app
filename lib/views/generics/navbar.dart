
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Navbar extends StatefulWidget {
  final Widget body;
  final FloatingActionButton? floatingActionButton;
  final String title;

  const Navbar({ super.key, required this.body, this.floatingActionButton, this.title = 'Money' });

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
        title: Text(widget.title),
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

  void goToHome(BuildContext context) async {
    Navigator.of(context).pop();
    await Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void goToAccounts(BuildContext context) async {
    Navigator.of(context).pop();
    await Navigator.of(context).pushNamed('/accounts');
  }

  void goToCategories(BuildContext context) async {
    Navigator.of(context).pop();
    await Navigator.of(context).pushNamed('/categories');
  }

  void goToStatistics(BuildContext context) async {
    Navigator.of(context).pop();
    await Navigator.of(context).pushNamed('/statistics');
  }

  void goToBackups(BuildContext context) async {
    Navigator.of(context).pop();
    await Navigator.of(context).pushNamed('/backups');
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
            onPressed: () => goToHome(context),
            child: const Text('Home', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 20),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => goToAccounts(context),
            child: const Text('Editar cuentas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 20),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => goToCategories(context),
            child: const Text('Editar categorías', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 20),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => goToStatistics(context),
            child: const Text('Estadísticas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 20),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => goToBackups(context),
            child: const Text('Backups', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
