import 'package:money/models/base.model.dart';

class CurrencyRates extends BaseModel {
  double usdToArs;
  double eurToArs;
  double eurToUsd;
  DateTime updatedAt;

  CurrencyRates({ required this.usdToArs, required this.eurToArs, required this.eurToUsd, required this.updatedAt, super.id });

  @override
  String toString() {
    return 'usdToArs=$usdToArs eurToArs=$eurToArs eurToUsd=$eurToUsd (updatedAt=$updatedAt)';
  }
}
