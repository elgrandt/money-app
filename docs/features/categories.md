# Categories

## What it does

Every movement is tagged with a category. Categories are scoped to a movement type — the
categories offered for an income differ from those for an expense or a transfer. They can be
managed on a dedicated screen (one tab per movement type) and created inline while recording a
movement.

## Data model

`Category` — [category.model.dart](../../lib/models/category.model.dart):

- `name` — display name.
- `movementType` — the `MovementType` this category belongs to.

## Key repository methods

`CategoriesRepository` — [categories.repository.dart](../../lib/repositories/categories.repository.dart):

- `create(movementType, name)` — inserts a category
  ([:36-40](../../lib/repositories/categories.repository.dart#L36-L40)).
- `getCategoriesByType()` — returns a `Map<MovementType, List<Category>>` grouping all
  categories by type ([:42-49](../../lib/repositories/categories.repository.dart#L42-L49)).

## Views involved

- [category_list.dart](../../lib/views/categories/category_list.dart) — the `/categories`
  screen; a tabbed list (one tab per `MovementType`) with per-row delete and a FAB to add.
- [new_category.dialog.dart](../../lib/views/categories/new_category.dialog.dart) — create
  dialog (name), receiving the `movementType` to attach.
- The movement dialog uses categories for its category selector and can open the create dialog
  inline — [new_movement.dialog.dart](../../lib/views/movements/new_movement.dialog.dart).

## Edge cases

- **Grouped by type** — the movement dialog only shows categories whose `movementType` matches
  the selected type; switching type resets the selected category.
- **Live refresh after inline create** — the movement dialog listens to
  `categoriesRepository.events` and, on an insert, refetches and pre-selects the new category
  ([new_movement.dialog.dart:135-143](../../lib/views/movements/new_movement.dialog.dart#L135-L143)).
