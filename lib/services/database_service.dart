import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/recipe.dart';
import '../models/category.dart';
import '../models/variant.dart';
import '../models/media_item.dart';
import '../utils/constants.dart';

/// 数据库服务（单例）
/// 负责所有 SQLite 读写操作，包括标签库、分类管理、数据导入导出。
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService.instance() => _instance;
  DatabaseService._internal();

  Database? _db;

  /// 获取数据库实例，懒加载
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    final db = await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // 启用外键约束
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );

    // 调试：启动打印 variants 表数据，确认食材真实存入
    try {
      final variants = await db.query('variants');
      print('[启动调试] variants表共 ${variants.length} 条记录');
      for (final v in variants) {
        print('[启动调试] variant: id=${v['id']}, recipe_id=${v['recipe_id']}, name=${v['name']}, ingredients=${v['ingredients']}');
      }
    } catch (e) {
      print('[启动调试] 读取variants表失败: $e');
    }

    return db;
  }

  // ==================== 建表 ====================

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        ingredients TEXT NOT NULL DEFAULT '',
        steps TEXT NOT NULL DEFAULT '',
        tips TEXT NOT NULL DEFAULT '',
        tags TEXT NOT NULL DEFAULT '',
        category_id INTEGER,
        image_path TEXT,
        time TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE variants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        ingredients TEXT NOT NULL DEFAULT '',
        steps TEXT NOT NULL DEFAULT '',
        tips TEXT NOT NULL DEFAULT '',
        parent_variant_id INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE media_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        section TEXT NOT NULL,
        type TEXT NOT NULL,
        file_path TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      )
    ''');

    // v4 新增: 标签库表
    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 插入默认分类
    for (int i = 0; i < AppConstants.defaultTags.length; i++) {
      await db.insert('categories', {
        'name': AppConstants.defaultTags[i],
        'sort_order': i,
      });
    }
  }

  // ==================== 迁移 ====================

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 已存在则跳过
    }

    // v3 → v4: 添加 time 列 + tags 表
    if (oldVersion < 4) {
      try {
        await db.execute("ALTER TABLE recipes ADD COLUMN time TEXT NOT NULL DEFAULT ''");
      } catch (_) {
        // 列可能已存在，忽略
      }
      // 创建 tags 表
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
      } catch (_) {}
    }

    // v4 → v5: variants 表补全 parent_variant_id 列
    if (oldVersion < 5) {
      try {
        await db.execute("ALTER TABLE variants ADD COLUMN parent_variant_id INTEGER");
      } catch (_) {
        // 列可能已存在，忽略
      }
    }

    // v5 → v6: variants 表补全 sort_order 列（如果缺失）
    if (oldVersion < 6) {
      try {
        await db.execute("ALTER TABLE variants ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0");
      } catch (_) {
        // 列可能已存在，忽略
      }
    }
  }

  // ==================== 分类 CRUD ====================

  /// 获取所有分类，按 sort_order 排序
  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'sort_order ASC, id ASC');
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  /// 新建分类（自动去重，自动分配末尾 sort_order）
  Future<int> insertCategory(Category category) async {
    final db = await database;
    // 重名校验
    final existing = await db.query(
      'categories',
      where: 'name = ?',
      whereArgs: [category.name.trim()],
    );
    if (existing.isNotEmpty) {
      throw Exception('分类「${category.name}」已存在');
    }
    category.name = category.name.trim();
    // 自动分配末尾序号
    if (category.sortOrder == 0) {
      final maxResult = await db.rawQuery('SELECT MAX(sort_order) as max_order FROM categories');
      final maxOrder = (maxResult.first['max_order'] as int?) ?? -1;
      category.sortOrder = maxOrder + 1;
    }
    return db.insert('categories', category.toMap());
  }

  /// 更新分类 — 级联更新所有关联菜谱的 category 显示名
  Future<void> updateCategory(Category category) async {
    final db = await database;
    // 重名校验（排除自身）
    final existing = await db.query(
      'categories',
      where: 'name = ? AND id != ?',
      whereArgs: [category.name.trim(), category.id],
    );
    if (existing.isNotEmpty) {
      throw Exception('分类「${category.name}」已存在');
    }
    category.name = category.name.trim();
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
    // 级联：菜谱中的 category 引用通过外键自动关联，名称已更新，无需额外操作
  }

  /// 检查分类是否被菜谱使用
  Future<bool> isCategoryUsed(int categoryId) async {
    final db = await database;
    final result = await db.query(
      'recipes',
      columns: ['id'],
      where: 'category_id = ?',
      whereArgs: [categoryId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// 删除分类（先检查是否被使用，删除后补齐 sort_order 序号）
  Future<void> deleteCategory(int categoryId) async {
    final db = await database;
    // 检查是否被菜谱使用
    final used = await isCategoryUsed(categoryId);
    if (used) {
      throw Exception('该分类下有关联菜谱，请先将菜谱更换到其他分类后再删除');
    }
    await db.delete('categories', where: 'id = ?', whereArgs: [categoryId]);
    // 删除后补齐 sort_order 序号
    final remaining = await db.query('categories', orderBy: 'sort_order ASC, id ASC');
    final batch = db.batch();
    for (int i = 0; i < remaining.length; i++) {
      batch.update(
        'categories',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [remaining[i]['id']],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 创建默认分类（如果没有任何分类）
  Future<void> ensureDefaultCategories() async {
    final cats = await getAllCategories();
    if (cats.isEmpty) {
      final db = await database;
      for (int i = 0; i < AppConstants.defaultTags.length; i++) {
        try {
          await db.insert('categories', {
            'name': AppConstants.defaultTags[i],
            'sort_order': i,
          });
        } catch (_) {}
      }
    }
  }

  // ==================== 菜谱 CRUD ====================

  /// 插入菜谱，返回新 id
  Future<int> insertRecipe(Recipe recipe) async {
    final db = await database;
    final id = await db.insert('recipes', recipe.toMap());
    // 同步标签库
    await _syncTagsFromRecipe(recipe);
    return id;
  }

  /// 更新菜谱
  Future<void> updateRecipe(Recipe recipe) async {
    final db = await database;
    await db.update(
      'recipes',
      recipe.toMap(),
      where: 'id = ?',
      whereArgs: [recipe.id],
    );
    // 同步标签库
    await _syncTagsFromRecipe(recipe);
  }

  /// 删除菜谱
  Future<void> deleteRecipe(int id) async {
    final db = await database;
    // 级联删除 variants、media_items
    await db.delete('variants', where: 'recipe_id = ?', whereArgs: [id]);
    await db.delete('media_items', where: 'recipe_id = ?', whereArgs: [id]);
    await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }

  /// 根据 id 获取菜谱
  Future<Recipe?> getById(int id) async {
    final db = await database;
    final maps = await db.query('recipes', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Recipe.fromMap(maps.first);
  }

  /// 获取所有菜谱
  Future<List<Recipe>> getAllRecipes() async {
    final db = await database;
    final maps = await db.query('recipes', orderBy: 'updated_at DESC');
    return maps.map((m) => Recipe.fromMap(m)).toList();
  }

  /// 按分类获取菜谱
  Future<List<Recipe>> getRecipesByCategory(int categoryId) async {
    final db = await database;
    final maps = await db.query(
      'recipes',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Recipe.fromMap(m)).toList();
  }

  /// 搜索菜谱（关键词 + 分类筛选叠加）
  /// [keyword] 搜索关键词（菜名、食材），自动 trim
  /// [categoryId] 可选，按分类筛选
  /// 常膳搜索：JOIN variants，同时匹配菜谱名称和变体食材
  Future<List<Recipe>> searchRecipes({String keyword = '', int? categoryId}) async {
    final db = await database;
    keyword = keyword.trim();

    // 如果关键词为空且无分类筛选，返回全部
    if (keyword.isEmpty && categoryId == null) {
      return getAllRecipes();
    }

    // 构建 WHERE 子句
    final List<String> conditions = [];
    final List<dynamic> args = [];

    if (keyword.isNotEmpty) {
      // 常膳搜索：匹配菜谱名称 + 变体食材
      final like = '%$keyword%';
      conditions.add('(r.name LIKE ? OR v.ingredients LIKE ?)');
      args.addAll([like, like]);
    }

    if (categoryId != null) {
      conditions.add('r.category_id = ?');
      args.add(categoryId);
    }

    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final sql = '''
      SELECT DISTINCT r.* FROM recipes r
      INNER JOIN variants v ON r.id = v.recipe_id
      $where
      ORDER BY r.updated_at DESC
    ''';

    // 调试打印
    print('[常膳搜索] keyword=$keyword, categoryId=$categoryId');
    print('[常膳搜索] SQL=$sql, args=$args');

    final maps = await db.rawQuery(sql, args);

    print('[常膳搜索] rawQuery返回 ${maps.length} 条结果');

    return maps.map((m) => Recipe.fromMap(m)).toList();
  }

  /// 按食材筛选菜谱（JOIN variants，仅匹配变体食材字段，不匹配菜谱名称）
  /// 卜材搜索：只能靠食材内容检索
  Future<List<Recipe>> searchByIngredient(String ingredient) async {
    final db = await database;
    ingredient = ingredient.trim();
    if (ingredient.isEmpty) return [];

    final like = '%$ingredient%';
    final sql = '''
      SELECT DISTINCT r.* FROM recipes r
      INNER JOIN variants v ON r.id = v.recipe_id
      WHERE v.ingredients LIKE ?
      ORDER BY r.updated_at DESC
    ''';

    // 调试打印
    print('[卜材搜索] ingredient=$ingredient');
    print('[卜材搜索] SQL=$sql, args=[$like]');

    final maps = await db.rawQuery(sql, [like]);

    print('[卜材搜索] rawQuery返回 ${maps.length} 条结果');

    return maps.map((m) => Recipe.fromMap(m)).toList();
  }

  // ==================== 变体 CRUD ====================

  Future<List<Variant>> getVariantsByRecipe(int recipeId) async {
    final db = await database;
    final maps = await db.query(
      'variants',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      orderBy: 'sort_order ASC',
    );
    return maps.map((m) => Variant.fromMap(m)).toList();
  }

  Future<void> saveVariants(int recipeId, List<Variant> variants) async {
    final db = await database;
    await db.delete('variants', where: 'recipe_id = ?', whereArgs: [recipeId]);
    for (int i = 0; i < variants.length; i++) {
      final v = variants[i];
      v.recipeId = recipeId;
      v.sortOrder = i;
      await db.insert('variants', v.toMap());
    }
  }

  // ==================== 多媒体 CRUD ====================

  Future<List<MediaItem>> getMediaByRecipe(int recipeId) async {
    final db = await database;
    final maps = await db.query(
      'media_items',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      orderBy: 'sort_order ASC',
    );
    return maps.map((m) => MediaItem.fromMap(m)).toList();
  }

  Future<void> saveMedia(int recipeId, List<MediaItem> items) async {
    final db = await database;
    await db.delete('media_items', where: 'recipe_id = ?', whereArgs: [recipeId]);
    for (int i = 0; i < items.length; i++) {
      final m = items[i];
      m.recipeId = recipeId;
      m.sortOrder = i;
      await db.insert('media_items', m.toMap());
    }
  }

  // ==================== 标签库管理 ====================

  /// 获取所有标签（去重），按 sort_order 排序
  Future<List<String>> getAllTags() async {
    final db = await database;
    final maps = await db.query('tags', orderBy: 'sort_order ASC, name ASC');
    return maps.map((m) => m['name'] as String).toList();
  }

  /// 同步标签库：从菜谱 tags 字段提取所有标签，补充到标签库
  Future<void> _syncTagsFromRecipe(Recipe recipe) async {
    final db = await database;
    final tagNames = recipe.tagList;
    for (final name in tagNames) {
      final existing = await db.query(
        'tags',
        where: 'name = ?',
        whereArgs: [name],
        limit: 1,
      );
      if (existing.isEmpty) {
        // 获取当前最大 sort_order
        final maxResult = await db.rawQuery('SELECT MAX(sort_order) as max_order FROM tags');
        final maxOrder = (maxResult.first['max_order'] as int?) ?? 0;
        await db.insert('tags', {
          'name': name,
          'sort_order': maxOrder + 1,
        });
      }
    }
  }

  /// 全部重建标签库（从所有菜谱中提取）
  Future<void> rebuildTags() async {
    final db = await database;
    final recipes = await getAllRecipes();
    // 收集所有标签
    final allTags = <String>{};
    for (final r in recipes) {
      allTags.addAll(r.tagList);
    }
    // 清除原有标签，保留排序信息
    final existingTags = await db.query('tags', orderBy: 'sort_order ASC');
    final existingMap = {for (final t in existingTags) t['name'] as String: t['sort_order'] as int};

    await db.delete('tags');
    int i = 0;
    for (final name in allTags) {
      await db.insert('tags', {
        'name': name,
        'sort_order': existingMap[name] ?? i,
      });
      i++;
    }
  }

  /// 更新标签排序（拖拽后批量保存）
  Future<void> updateTagOrder(List<String> orderedTags) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < orderedTags.length; i++) {
      batch.update(
        'tags',
        {'sort_order': i},
        where: 'name = ?',
        whereArgs: [orderedTags[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 按 sort_order 排序标签列表（用于排序菜谱内的标签显示顺序）
  Future<List<String>> getSortedTags() async {
    final db = await database;
    final maps = await db.query('tags', orderBy: 'sort_order ASC, name ASC');
    return maps.map((m) => m['name'] as String).toList();
  }

  /// 初始化老标签的 sort_order（按 id 顺序，id 即创建顺序）
  Future<void> initializeTagSortOrder() async {
    final db = await database;
    // 找出所有 sort_order 为 0 且有多个标签的记录
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM tags WHERE sort_order = 0',
    );
    final count = (result.first['cnt'] as int?) ?? 0;
    if (count == 0) return;

    // 全部按 id 重新排序
    final all = await db.query('tags', orderBy: 'id ASC');
    final batch = db.batch();
    for (int i = 0; i < all.length; i++) {
      batch.update(
        'tags',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [all[i]['id']],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 从标签库删除标签（不删除菜谱中的标签数据）
  Future<void> deleteTag(String tagName) async {
    final db = await database;
    await db.delete('tags', where: 'name = ?', whereArgs: [tagName]);
  }

  // ==================== 数据导入导出 ====================

  /// 导出数据
  Future<Map<String, dynamic>> exportAllData({
    bool includeRecipes = true,
    bool includeCategories = true,
  }) async {
    final db = await database;
    final data = <String, dynamic>{};

    if (includeCategories) {
      final cats = await db.query('categories', orderBy: 'sort_order ASC');
      data['categories'] = cats;
      // 导出标签库排序信息
      final tags = await db.query('tags', orderBy: 'sort_order ASC');
      data['tags'] = tags;
    }

    if (includeRecipes) {
      final recipes = await db.query('recipes', orderBy: 'id ASC');
      data['recipes'] = recipes;

      // 变体
      final variants = await db.query('variants', orderBy: 'sort_order ASC');
      data['variants'] = variants;

      // 多媒体
      final media = await db.query('media_items', orderBy: 'sort_order ASC');
      data['media_items'] = media;
    }

    return data;
  }

  /// 导入数据（支持重名处理策略：'skip' 跳过, 'overwrite' 覆盖）
  /// [duplicateStrategy] 由调用方传入，每遇到重名时弹窗让用户选择
  /// 返回 { 'skipped': int, 'overwritten': int, 'imported': int }
  Future<Map<String, int>> importData(
    Map<String, dynamic> data, {
    bool importRecipes = true,
    bool importCategories = true,
    String duplicateStrategy = 'skip', // 'skip' | 'overwrite'
  }) async {
    final db = await database;
    int skipped = 0, overwritten = 0, imported = 0;

    if (importCategories && data.containsKey('categories')) {
      final cats = data['categories'] as List;
      for (final cat in cats) {
        try {
          final existing = await db.query(
            'categories',
            where: 'name = ?',
            whereArgs: [cat['name']],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            if (duplicateStrategy == 'overwrite') {
              await db.update(
                'categories',
                {'sort_order': cat['sort_order'] ?? 0},
                where: 'name = ?',
                whereArgs: [cat['name']],
              );
              overwritten++;
            } else {
              skipped++;
            }
          } else {
            await db.insert('categories', {
              'name': cat['name'],
              'sort_order': cat['sort_order'] ?? 0,
            });
            imported++;
          }
        } catch (_) {}
      }

      // 导入标签排序信息
      if (data.containsKey('tags')) {
        final tags = data['tags'] as List;
        for (final tag in tags) {
          try {
            final existing = await db.query(
              'tags',
              where: 'name = ?',
              whereArgs: [tag['name']],
              limit: 1,
            );
            if (existing.isNotEmpty) {
              // 始终用导入的排序覆盖本地
              await db.update(
                'tags',
                {'sort_order': tag['sort_order'] ?? 0},
                where: 'name = ?',
                whereArgs: [tag['name']],
              );
            } else {
              await db.insert('tags', {
                'name': tag['name'],
                'sort_order': tag['sort_order'] ?? 0,
              });
            }
          } catch (_) {}
        }
      }
    }

    if (importRecipes && data.containsKey('recipes')) {
      final recipes = data['recipes'] as List;
      for (final r in recipes) {
        try {
          final existing = await db.query(
            'recipes',
            where: 'name = ?',
            whereArgs: [r['name']],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            if (duplicateStrategy == 'overwrite') {
              await db.update(
                'recipes',
                {
                  'ingredients': r['ingredients'] ?? '',
                  'steps': r['steps'] ?? '',
                  'tips': r['tips'] ?? '',
                  'tags': r['tags'] ?? '',
                  'category_id': r['category_id'],
                  'image_path': r['image_path'],
                  'time': r['time'] ?? '',
                  'updated_at': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'name = ?',
                whereArgs: [r['name']],
              );
              overwritten++;
            } else {
              skipped++;
            }
          } else {
            await db.insert('recipes', {
              'name': r['name'],
              'ingredients': r['ingredients'] ?? '',
              'steps': r['steps'] ?? '',
              'tips': r['tips'] ?? '',
              'tags': r['tags'] ?? '',
              'category_id': r['category_id'],
              'image_path': r['image_path'],
              'time': r['time'] ?? '',
              'created_at': r['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
              'updated_at': r['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
            });
            imported++;
          }
        } catch (_) {}
      }
    }

    return {'skipped': skipped, 'overwritten': overwritten, 'imported': imported};
  }

  /// 更新分类排序（拖拽后批量保存）
  Future<void> updateCategoryOrder(List<Category> orderedCategories) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < orderedCategories.length; i++) {
      batch.update(
        'categories',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [orderedCategories[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 初始化老分类的 sort_order（按 id 顺序）
  Future<void> initializeCategorySortOrder() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM categories WHERE sort_order = 0',
    );
    final count = (result.first['cnt'] as int?) ?? 0;
    if (count == 0) return;

    final all = await db.query('categories', orderBy: 'id ASC');
    final batch = db.batch();
    for (int i = 0; i < all.length; i++) {
      batch.update(
        'categories',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [all[i]['id']],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 获取菜谱数量（按分类）
  Future<int> getRecipeCountByCategory(int categoryId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM recipes WHERE category_id = ?',
      [categoryId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }
}