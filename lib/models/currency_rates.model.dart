import 'package:money/models/base.model.dart';

class CurrencyRates extends BaseModel {
  double usdBuy;
  double usdSell;
  double eurBuy;
  double eurSell;
  DateTime updatedAt;

  CurrencyRates({ required this.usdBuy, required this.usdSell, required this.eurBuy, required this.eurSell, required this.updatedAt, super.id });

  @override
  String toString() {
    return 'usdBuy=$usdBuy usdSell=$usdSell eurBuy=$eurBuy eurSell=$eurSell (updatedAt=$updatedAt)';
  }
}
