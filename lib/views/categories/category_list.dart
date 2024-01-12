
import 'package:events_emitter/events_emitter.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:money/models/category.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:money/services/database.service.dart';
import 'package:money/views/categories/new_category.dialog.dart';
import 'package:money/views/generics/loader.dart';
import 'package:money/views/generics/navbar.dart';
import 'package:money/views/generics/tabs.dart' as tabs;

class CategoryList extends StatefulWidget {
  const CategoryList({ super.key });

  @override
  State<CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends State<CategoryList> {

  Map<MovementType, List<Category>>? categoriesByType;
  var databaseService = GetIt.instance.get<DatabaseService>();
  var logger = GetIt.instance.get<Logger>();
  EventListener<TableUpdateEvent<Category>>? categoriesListener;
  bool disableCategoryUpdate = false;
  MovementType selectedMovementType = MovementType.ADD;

  @override
  void initState() {
    super.initState();
    getCategories();
    watchCategoryChanges();
  }

  @override
  void dispose() {
    super.dispose();
    categoriesListener?.cancel();
  }

  Future<void> getCategories() async {
    if (disableCategoryUpdate) return;
    await databaseService.initialized;
    try {
      logger.d('Getting categories');
      var categoriesByType = await databaseService.categoriesRepository.getCategoriesByType();
      setState(() {
        this.categoriesByType = categoriesByType;
      });
    } catch (error, stackTrace) {
      logger.e('Error getting categories', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> watchCategoryChanges() async {
    await databaseService.initialized;
    categoriesListener = databaseService.categoriesRepository.events.on<TableUpdateEvent<Category>>('change', (event) {
      logger.d('Category change: $event');
      getCategories();
    });
  }

  Future<void> openNewCategoryDialog() async {
    await showDialog<Category?>(context: context, builder: (context) {
      return NewCategoryDialog(movementType: selectedMovementType);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Navbar(
      title: 'Categorías',
      floatingActionButton: FloatingActionButton(
        onPressed: openNewCategoryDialog,
        backgroundColor: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: categoriesByType == null ? const Loader() : buildMovementTypeTabs(context),
    );
  }

  Widget buildMovementTypeTabs(BuildContext context) {
    return tabs.Tabs(
      onSelectedTabChange: (index) => setState(() {
        selectedMovementType = MovementType.values[index];
      }),
      tabs: MovementType.values.map((movementType) => tabs.Tab(
        name: movementTypeNames[movementType]!,
        body: buildCategoryList(context, movementType),
      )).toList(),
    );;
  }

  Widget buildCategoryList(BuildContext context, MovementType movementType) {
    var categories = categoriesByType![movementType]!;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
      itemBuilder: (context, index) => buildCategoryItem(context, categories[index], index),
      itemCount: categories.length,
      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10),
    );
  }

  Widget buildCategoryItem(BuildContext context, Category category, int index) {
    return Container(
      key: ValueKey(index),
      padding: const EdgeInsets.only(top: 5, bottom: 5, left: 10),
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 7,
            offset: const Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child: ListTile(
        title: Text(category.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red.shade900),
              onPressed: () {
                databaseService.categoriesRepository.delete(category.id!);
              },
            ),
          ],
        ),
      ),
    );
  }
}
