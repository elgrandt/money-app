
class MigrationDefinition {
  String name;
  Future<void> Function() up;
  Future<void> Function() down;

  MigrationDefinition(this.name, this.up, this.down);
}