
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:money/models/account.model.dart';
import 'package:money/services/utils.service.dart';

class TotalViewer extends StatelessWidget {
  final Account? account;
  final List<Account> accounts;
  final Currency currency;
  final EdgeInsets? padding;

  const TotalViewer({ super.key, this.account, required this.accounts, required this.currency, this.padding });

  String totalString() {
    var utilsService = GetIt.instance.get<UtilsService>();
    double total = 0;
    if (account != null) {
      total = utilsService.convertCurrencies(account!.total, account!.currency, currency);
    } else {
      total = 0;
      for (var account in accounts) {
        total += utilsService.convertCurrencies(account.total, account.currency, currency);
      }
    }
    return GetIt.instance.get<UtilsService>().beautifyCurrency(total, currency);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      alignment: Alignment.center,
      child: Text(totalString(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
    );
  }
}