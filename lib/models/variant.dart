class Variant {
  int? id;
  int recipeId;
  String name;
  String ingredients;
  String steps;
  String tips;
  int? parentVariantId;
  int sortOrder;

  Variant({
    this.id,
    required this.recipeId,
    required this.name,
    this.ingredients = "",
    this.steps = "",
    this.tips = "",
    this.parentVariantId,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipe_id': recipeId,
      'name': name,
      'ingredients': ingredients,
      'steps': steps,
      'tips': tips,
      'parent_variant_id': parentVariantId,
      'sort_order': sortOrder,
    };
  }

  factory Variant.fromMap(Map<String, dynamic> map) {
    return Variant(
      id: map['id'] as int?,
      recipeId: map['recipe_id'] as int? ?? 0,
      name: map['name'] as String? ?? "做法",
      ingredients: map['ingredients'] as String? ?? "",
      steps: map['steps'] as String? ?? "",
      tips: map['tips'] as String? ?? "",
      parentVariantId: map['parent_variant_id'] as int?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  List<String> get ingredientsList =>
      ingredients.split("\n").where((e) => e.trim().isNotEmpty).toList();

  List<String> get stepsList =>
      steps.split("\n").where((e) => e.trim().isNotEmpty).toList();
}
