
import 'package:money/models/base.model.dart';

class Migration extends BaseModel {
  String name;

  Migration(this.name, { super.id });

  @override
  String toString() {
    return '$name (id=$id)';
  }
}