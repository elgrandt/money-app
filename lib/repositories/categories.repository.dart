
import 'package:money/models/category.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:sqflite/sqflite.dart';

class CategoriesRepository extends BaseRepository<Category> {
  static List<DatabaseColumnDefinition> categoryColumns = [
    DatabaseColumnDefinition('id', DatabaseColumnType.INTEGER, primaryKey: PrimaryKeyDefinition(autoincrement: true)),
    DatabaseColumnDefinition('name', DatabaseColumnType.TEXT),
    DatabaseColumnDefinition('movementType', DatabaseColumnType.TEXT),
  ];

  CategoriesRepository(Database db): super(db, 'categories', CategoriesRepository.categoryColumns);

  @override
  Map<String, Object?> modelToMap(Category model) {
    var map = <String, Object?>{};
    if (model.id != null) {
      map['id'] = model.id;
    }
    map['name'] = model.name;
    map['movementType'] = model.movementType.name;
    return map;
  }

  @override
  Category mapToModel(Map<String, Object?> map) {
    return Category(
      name: map['name'] as String,
      movementType: MovementType.values.firstWhere((movementType) => movementType.name == map['movementType']),
      id: map['id'] as int?
    );
  }

  Future<Category> create(MovementType movementType, String name) async {
    var category = Category(movementType: movementType, name: name);
    category = await insert(category);
    return category;
  }

  Future<Map<MovementType, List<Category>>> getCategoriesByType() async {
    var categories = await find();
    var categoriesByType = <MovementType, List<Category>>{};
    for (var movementType in MovementType.values) {
      categoriesByType[movementType] = categories.where((category) => category.movementType == movementType).toList();
    }
    return categoriesByType;
  }
}