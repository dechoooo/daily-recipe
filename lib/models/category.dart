class Category {
  int? id;
  String name;
  int sortOrder;

  Category({this.id, required this.name, this.sortOrder = 0});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'sort_order': sortOrder,
  };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
    id: map['id'] as int?,
    name: map['name'] as String? ?? '',
    sortOrder: map['sort_order'] as int? ?? 0,
  );
}
