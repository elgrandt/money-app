
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class Navbar extends StatefulWidget {
  final Widget body;
  final FloatingActionButton? floatingActionButton;

  const Navbar({ super.key, required this.body, this.floatingActionButton });

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leadingWidth: 90,
        title: Text('Money App',style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontFamily: 'Helvetica'
        )),
        centerTitle: true,
        // leading: const IconButton(
        //   icon: Icon(Icons.menu),
        //   tooltip: 'Navigation menu',
        //   onPressed: null,
        // ),
      ),
      floatingActionButton: widget.floatingActionButton,
      body: widget.body,
    );
  }
}