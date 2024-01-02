
import 'package:money/models/base.model.dart';
import 'package:money/models/movement.model.dart';

class Category extends BaseModel {
  String name;
  MovementType movementType;

  Category({ super.id, required this.name, required this.movementType });

  @override
  String toString() {
    return '$movementType: $name (id=$id)';
  }
}
