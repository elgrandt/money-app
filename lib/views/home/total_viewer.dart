
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:money/models/account.model.dart';
import 'package:money/services/utils.service.dart';

Map<int, bool> visibilitiesByAccount = {};

class TotalViewer extends StatefulWidget {
  final Account? account;
  final List<Account> accounts;
  final Currency currency;
  final EdgeInsets? padding;

  const TotalViewer({ super.key, this.account, required this.accounts, required this.currency, this.padding });

  @override
  State<TotalViewer> createState() => _TotalViewerState();
}

class _TotalViewerState extends State<TotalViewer> {
  bool visible = false;

  @override
  void initState() {
    super.initState();
    if (visibilitiesByAccount.containsKey(widget.account?.id ?? -1)) {
      visible = visibilitiesByAccount[widget.account?.id ?? -1]!;
    }
  }

  String totalString() {
    var utilsService = GetIt.instance.get<UtilsService>();
    if (visible) {
      double total = 0;
      if (widget.account != null) {
        total = utilsService.convertCurrencies(widget.account!.total, widget.account!.currency, widget.currency);
      } else {
        total = 0;
        for (var account in widget.accounts) {
          total += utilsService.convertCurrencies(account.total, account.currency, widget.currency);
        }
      }
      return GetIt.instance.get<UtilsService>().beautifyCurrency(total, widget.currency);
    } else {
      return '**** ${ utilsService.getCurrencySymbol(widget.currency) }';
    }
  }

  switchVisible() {
    setState(() {
      visible = !visible;
      visibilitiesByAccount[widget.account?.id ?? -1] = visible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: widget.padding,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: switchVisible,
        child: Text(totalString(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold), textAlign: TextAlign.center)
      ),
    );
  }
}