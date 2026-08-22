class MediaItem {
  int? id;
  int recipeId;
  String filePath;
  String type; // 'image' or 'video'
  String section; // 'cover', 'ingredients', 'steps', 'tips'
  int sortOrder;

  MediaItem({
    this.id,
    required this.recipeId,
    required this.filePath,
    required this.type,
    this.section = 'cover',
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'recipe_id': recipeId,
    'file_path': filePath,
    'type': type,
    'section': section,
    'sort_order': sortOrder,
  };

  factory MediaItem.fromMap(Map<String, dynamic> map) => MediaItem(
    id: map['id'] as int?,
    recipeId: map['recipe_id'] as int,
    filePath: map['file_path'] as String,
    type: map['type'] as String,
    section: map['section'] as String? ?? 'cover',
    sortOrder: map['sort_order'] as int? ?? 0,
  );
}
