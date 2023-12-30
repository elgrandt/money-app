
import 'package:flutter/material.dart';
import 'package:money/models/account.model.dart';
import 'package:money/views/home/total_viewer.dart';

class Dashboard extends StatelessWidget {
  final List<Account> accounts;

  const Dashboard({ super.key, required this.accounts });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        buildTotal(context),
      ],
    );
  }

  Widget buildTotal(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        const Text('Patrimonio total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        TotalViewer(accounts: accounts, currency: Currency.USD)
      ],
    );
  }
}