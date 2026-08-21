import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/recipe.dart';
import '../models/category.dart';
import '../models/media_item.dart';
import '../models/variant.dart';
import '../utils/constants.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  factory DatabaseService() => instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, AppConstants.dbName);
    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // v2 schema
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        ingredients TEXT,
        steps TEXT,
        tips TEXT,
        tags TEXT,
        category_id INTEGER,
        image_path TEXT,
        created_at INTEGER,
        updated_at INTEGER,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE media (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        type TEXT NOT NULL,
        section TEXT DEFAULT 'cover',
        sort_order INTEGER DEFAULT 0,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      )
    ''');
    // v3 schema
    await db.execute('''
      CREATE TABLE variants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        name TEXT NOT NULL DEFAULT '做法',
        ingredients TEXT DEFAULT '',
        steps TEXT DEFAULT '',
        tips TEXT DEFAULT '',
        parent_variant_id INTEGER,
        sort_order INTEGER DEFAULT 0,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
        FOREIGN KEY (parent_variant_id) REFERENCES variants(id) ON DELETE SET NULL
      )
    ''');
    // Insert default categories
    for (int i = 0; i < AppConstants.defaultTags.length; i++) {
      await db.insert('categories', {
        'name': AppConstants.defaultTags[i],
        'sort_order': i,
      });
    }
  }

  /// 安全地检查列是否存在
  Future<bool> _columnExists(Database db, String table, String column) async {
    try {
      final result = await db.rawQuery('PRAGMA table_info($table)');
      for (final row in result) {
        if (row['name'] == column) return true;
      }
    } catch (_) {}
    return false;
  }

  /// 安全地检查表是否存在
  Future<bool> _tableExists(Database db, String table) async {
    try {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [table],
      );
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 → v2: categories + media 表, tag→category_id 迁移
    if (oldVersion < 2) {
      // Create categories table
      if (!await _tableExists(db, 'categories')) {
        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            sort_order INTEGER DEFAULT 0
          )
        ''');
      }
      // Add category_id to recipes
      if (!await _columnExists(db, 'recipes', 'category_id')) {
        await db.execute('ALTER TABLE recipes ADD COLUMN category_id INTEGER');
      }
      // Create media table
      if (!await _tableExists(db, 'media')) {
        await db.execute('''
          CREATE TABLE media (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            recipe_id INTEGER NOT NULL,
            file_path TEXT NOT NULL,
            type TEXT NOT NULL,
            section TEXT DEFAULT 'cover',
            sort_order INTEGER DEFAULT 0,
            FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
          )
        ''');
      }
      // Insert default categories
      for (int i = 0; i < AppConstants.defaultTags.length; i++) {
        try {
          await db.insert('categories', {
            'name': AppConstants.defaultTags[i],
            'sort_order': i,
          });
        } catch (_) {} // ignore duplicates
      }
      // Migrate tags to categories
      final recipes = await db.query('recipes');
      for (final r in recipes) {
        final tagsRaw = r['tags'] as String?;
        if (tagsRaw != null && tagsRaw.isNotEmpty) {
          final tags = tagsRaw.split(',').where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList();
          if (tags.isNotEmpty) {
            final cat = await db.query('categories', where: 'name = ?', whereArgs: [tags.first], limit: 1);
            if (cat.isNotEmpty) {
              await db.update('recipes', {'category_id': cat.first['id']}, where: 'id = ?', whereArgs: [r['id']]);
            }
          }
        }
      }
    }

    // v2 → v3: variants 表
    if (oldVersion < 3) {
      if (!await _tableExists(db, 'variants')) {
        await db.execute('''
          CREATE TABLE variants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            recipe_id INTEGER NOT NULL,
            name TEXT NOT NULL DEFAULT '做法',
            ingredients TEXT DEFAULT '',
            steps TEXT DEFAULT '',
            tips TEXT DEFAULT '',
            parent_variant_id INTEGER,
            sort_order INTEGER DEFAULT 0,
            FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
            FOREIGN KEY (parent_variant_id) REFERENCES variants(id) ON DELETE SET NULL
          )
        ''');
      }
      // 把已有菜谱的食材/步骤迁移为默认变体
      final recipes = await db.query('recipes');
      for (final r in recipes) {
        final id = r['id'] as int?;
        if (id == null) continue;
        // 检查是否已有变体
        final existing = await db.query('variants', where: 'recipe_id = ?', whereArgs: [id]);
        if (existing.isEmpty) {
          await db.insert('variants', {
            'recipe_id': id,
            'name': '默认做法',
            'ingredients': r['ingredients'] ?? '',
            'steps': r['steps'] ?? '',
            'tips': r['tips'] ?? '',
            'sort_order': 0,
          });
        }
      }
    }
  }

  // ===== Category CRUD =====
  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'sort_order ASC');
    return maps.map((e) => Category.fromMap(e)).toList();
  }

  Future<int> insertCategory(Category cat) async {
    final db = await database;
    return await db.insert('categories', cat.toMap()..remove('id'));
  }

  Future<int> updateCategory(Category cat) async {
    final db = await database;
    return await db.update('categories', cat.toMap(), where: 'id = ?', whereArgs: [cat.id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderCategories(List<Category> categories) async {
    final db = await database;
    for (int i = 0; i < categories.length; i++) {
      categories[i].sortOrder = i;
      await db.update('categories', {'sort_order': i}, where: 'id = ?', whereArgs: [categories[i].id]);
    }
  }

  // ===== Recipe CRUD =====
  Future<int> insert(Recipe recipe) async {
    final db = await database;
    return await db.insert('recipes', recipe.toMap()..remove('id'));
  }

  Future<int> update(Recipe recipe) async {
    final db = await database;
    recipe.updatedAt = DateTime.now().millisecondsSinceEpoch;
    return await db.update('recipes', recipe.toMap(), where: 'id = ?', whereArgs: [recipe.id]);
  }

  Future<int> delete(int id) async {
    final db = await database;
    await db.delete('variants', where: 'recipe_id = ?', whereArgs: [id]);
    await db.delete('media', where: 'recipe_id = ?', whereArgs: [id]);
    return await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }

  Future<Recipe?> getById(int id) async {
    final db = await database;
    final maps = await db.query('recipes', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Recipe.fromMap(maps.first);
  }

  Future<List<Recipe>> getAll({String? keyword, int? categoryId}) async {
    final db = await database;
    String where = "1=1";
    List<dynamic> args = [];
    if (keyword != null && keyword.trim().isNotEmpty) {
      where += " AND (name LIKE ? OR ingredients LIKE ? OR tips LIKE ?)";
      final kw = "%${keyword.trim()}%";
      args.addAll([kw, kw, kw]);
    }
    if (categoryId != null) {
      where += " AND category_id = ?";
      args.add(categoryId);
    }
    final maps = await db.query('recipes', where: where, whereArgs: args, orderBy: 'updated_at DESC');
    return maps.map((e) => Recipe.fromMap(e)).toList();
  }

  Future<List<Recipe>> getRandomFromCategory(int categoryId, int count) async {
    final db = await database;
    final maps = await db.query(
      'recipes',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'RANDOM()',
      limit: count,
    );
    return maps.map((e) => Recipe.fromMap(e)).toList();
  }

  Future<List<String>> getAllTags() async {
    final db = await database;
    final maps = await db.query('recipes', columns: ['tags']);
    final Set<String> tags = {};
    for (final m in maps) {
      final raw = m['tags'] as String?;
      if (raw != null && raw.isNotEmpty) {
        tags.addAll(raw.split(",").where((e) => e.trim().isNotEmpty).map((e) => e.trim()));
      }
    }
    return tags.toList();
  }

  // ===== Variant CRUD =====
  Future<List<Variant>> getVariantsByRecipe(int recipeId) async {
    final db = await database;
    final maps = await db.query('variants', where: 'recipe_id = ?', whereArgs: [recipeId], orderBy: 'sort_order ASC');
    return maps.map((e) => Variant.fromMap(e)).toList();
  }

  Future<int> insertVariant(Variant variant) async {
    final db = await database;
    return await db.insert('variants', variant.toMap()..remove('id'));
  }

  Future<int> updateVariant(Variant variant) async {
    final db = await database;
    return await db.update('variants', variant.toMap(), where: 'id = ?', whereArgs: [variant.id]);
  }

  Future<int> deleteVariant(int id) async {
    final db = await database;
    return await db.delete('variants', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteVariantsByRecipe(int recipeId) async {
    final db = await database;
    await db.delete('variants', where: 'recipe_id = ?', whereArgs: [recipeId]);
  }

  // ===== Media CRUD =====
  Future<List<MediaItem>> getMediaByRecipe(int recipeId) async {
    final db = await database;
    final maps = await db.query('media', where: 'recipe_id = ?', whereArgs: [recipeId], orderBy: 'sort_order ASC');
    return maps.map((e) => MediaItem.fromMap(e)).toList();
  }

  Future<int> insertMedia(MediaItem media) async {
    final db = await database;
    return await db.insert('media', media.toMap()..remove('id'));
  }

  Future<int> deleteMedia(int id) async {
    final db = await database;
    return await db.delete('media', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMediaByRecipe(int recipeId) async {
    final db = await database;
    await db.delete('media', where: 'recipe_id = ?', whereArgs: [recipeId]);
  }

  // ===== Export/Import =====
  Future<Map<String, dynamic>> exportAllData({bool includeRecipes = true, bool includeCategories = true}) async {
    final db = await database;
    final data = <String, dynamic>{
      'version': 3,
      'exported_at': DateTime.now().toIso8601String(),
    };
    if (includeCategories) {
      data['categories'] = await db.query('categories', orderBy: 'sort_order ASC');
    }
    if (includeRecipes) {
      data['recipes'] = await db.query('recipes', orderBy: 'updated_at DESC');
      data['variants'] = await db.query('variants', orderBy: 'sort_order ASC');
      data['media'] = await db.query('media', orderBy: 'sort_order ASC');
    }
    return data;
  }

  Future<void> importData(Map<String, dynamic> data, {bool importRecipes = true, bool importCategories = true}) async {
    final db = await database;
    await db.transaction((txn) async {
      if (importCategories) {
        final categories = data['categories'] as List? ?? [];
        for (final c in categories) {
          try {
            await txn.insert('categories', Map<String, dynamic>.from(c as Map));
          } catch (_) {} // ignore duplicates
        }
      }
      if (importRecipes) {
        final recipes = data['recipes'] as List? ?? [];
        for (final r in recipes) {
          await txn.insert('recipes', Map<String, dynamic>.from(r as Map));
        }
        // v3: import variants
        final variants = data['variants'] as List? ?? [];
        for (final v in variants) {
          await txn.insert('variants', Map<String, dynamic>.from(v as Map));
        }
        final media = data['media'] as List? ?? [];
        for (final m in media) {
          await txn.insert('media', Map<String, dynamic>.from(m as Map));
        }
      }
    });
  }
}
