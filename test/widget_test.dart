import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_app/models/recipe.dart';

void main() {
  group('Recipe model', () {
    test('toMap and fromMap round-trip preserves all fields', () {
      final recipe = Recipe(
        id: 1,
        name: '西红柿炒蛋',
        ingredients: '鸡蛋 2个\n西红柿 2个\n盐 适量',
        steps: '1. 鸡蛋打散\n2. 热锅倒油\n3. 倒入蛋液翻炒',
        tips: '鸡蛋加少许水更嫩',
        tags: '家常菜,快手菜',
        imagePath: '/path/to/image.jpg',
        createdAt: 1000000,
        updatedAt: 2000000,
      );

      final map = recipe.toMap();
      final restored = Recipe.fromMap(map);

      expect(restored.id, recipe.id);
      expect(restored.name, recipe.name);
      expect(restored.ingredients, recipe.ingredients);
      expect(restored.steps, recipe.steps);
      expect(restored.tips, recipe.tips);
      expect(restored.tags, recipe.tags);
      expect(restored.imagePath, recipe.imagePath);
      expect(restored.createdAt, recipe.createdAt);
      expect(restored.updatedAt, recipe.updatedAt);
    });

    test('tagList splits comma-separated tags correctly', () {
      final recipe = Recipe(name: 'test', ingredients: '', steps: '', tags: '家常菜, 减脂 ,甜品');
      expect(recipe.tagList, ['家常菜', '减脂', '甜品']);
    });

    test('tagList handles empty tags', () {
      final recipe = Recipe(name: 'test', ingredients: '', steps: '', tags: '');
      expect(recipe.tagList, isEmpty);
    });

    test('fromMap handles null fields gracefully', () {
      final map = <String, dynamic>{'id': 1, 'name': 'test'};
      final recipe = Recipe.fromMap(map);
      expect(recipe.name, 'test');
      expect(recipe.ingredients, '');
      expect(recipe.steps, '');
      expect(recipe.tips, '');
      expect(recipe.tags, '');
      expect(recipe.imagePath, isNull);
    });

    test('new recipe gets default timestamps', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final recipe = Recipe(name: 'test', ingredients: '', steps: '');
      final after = DateTime.now().millisecondsSinceEpoch;
      expect(recipe.createdAt, greaterThanOrEqualTo(before));
      expect(recipe.createdAt, lessThanOrEqualTo(after));
      expect(recipe.updatedAt, greaterThanOrEqualTo(before));
    });
  });
}
