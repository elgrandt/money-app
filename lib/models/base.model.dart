
abstract class BaseModel {
  int? id;

  BaseModel({ this.id });

  @override
  bool operator ==(Object other) {
    if (other is! BaseModel) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id ?? 0;
}