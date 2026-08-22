class Recipe {
  int? id;
  String name;
  String ingredients;
  String steps;
  String tips;
  String tags;
  int? categoryId;
  String? imagePath;
  String time; // 耗时文本，如 "30分钟"
  int createdAt;
  int updatedAt;

  Recipe({
    this.id,
    required this.name,
    required this.ingredients,
    required this.steps,
    this.tips = "",
    this.tags = "",
    this.categoryId,
    this.imagePath,
    this.time = "",
    int? createdAt,
    int? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ingredients': ingredients,
      'steps': steps,
      'tips': tips,
      'tags': tags,
      'category_id': categoryId,
      'image_path': imagePath,
      'time': time,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] as int?,
      name: map['name'] as String? ?? "",
      ingredients: map['ingredients'] as String? ?? "",
      steps: map['steps'] as String? ?? "",
      tips: map['tips'] as String? ?? "",
      tags: map['tags'] as String? ?? "",
      categoryId: map['category_id'] as int?,
      imagePath: map['image_path'] as String?,
      time: map['time'] as String? ?? "",
      createdAt: map['created_at'] as int? ?? 0,
      updatedAt: map['updated_at'] as int? ?? 0,
    );
  }

  List<String> get tagList =>
      tags.split(",").where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList();
}
