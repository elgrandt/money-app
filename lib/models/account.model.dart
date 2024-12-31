
import 'package:money/models/base.model.dart';

enum Currency {
  ARS,
  USD,
  EUR
}

class Account extends BaseModel {
  String name;
  double total;
  Currency currency;
  int sortIndex;
  bool showTotal = false;

  Account({ required this.name, required this.total, required this.currency, required this.sortIndex, this.showTotal = false, super.id });

  @override
  String toString() {
    return '$name $total (id=$id)';
  }
}