
import 'package:flutter/widgets.dart';

class Loader extends StatelessWidget {
  const Loader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: const Text('Cargando...', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
    );
  }
}
