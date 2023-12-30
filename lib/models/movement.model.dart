
import 'package:money/models/account.model.dart';
import 'package:money/models/base.model.dart';

enum MovementType {
  ADD,
  REMOVE,
  TRANSFER
}

class Movement extends BaseModel {
  MovementType type;
  String description;
  double amount;
  double? conversionRate;
  String category;
  Account? source;
  Account? target;
  DateTime? creationDate;

  Movement(this.type, this.description, this.amount, this.category, { super.id, this.source, this.target, this.creationDate, this.conversionRate });

  @override
  String toString() {
    return '$creationDate: ${type.name} $amount (from: ${source?.name ?? '-'}) (to: ${target?.name ?? '-'})';
  }
}