
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
  String category;
  Account? source;
  Account? target;
  DateTime? creationDate;

  Movement(this.type, this.description, this.amount, this.category, { super.id, this.source, this.target, this.creationDate });

  @override
  String toString() {
    return '${type.name} $amount (from: ${source?.name ?? '-'}) (to: ${target?.name ?? '-'})';
  }
}