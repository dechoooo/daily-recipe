import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';
import 'recipe_edit_page.dart';
import 'recipe_detail_page.dart';
import 'settings_page.dart';
import '../main.dart'; // 全局刷新通知器

/// 藏膳页面：菜谱列表 + 搜索 + 分类筛选
/// 所有分类动态渲染，搜索带 300ms 防抖。
class HomePage extends StatefulWidget {
  final ValueNotifier<int> refreshNotifier;

  const HomePage({super.key, required this.refreshNotifier});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Recipe> _recipes = [];
  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _loading = true;
  String? _errorMsg;

  // 搜索
  final _searchCtrl = TextEditingController();
  bool _showAdvancedSearch = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.refreshNotifier.addListener(_refresh);
    _searchCtrl.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_refresh);
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _refresh() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final cats = await DatabaseService.instance().getAllCategories();
      final recipes = await DatabaseService.instance().searchRecipes(
        keyword: _searchCtrl.text,
        categoryId: _selectedCategoryId,
      );
      if (mounted) {
        setState(() {
          _categories = cats;
          _recipes = recipes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = '加载失败: $e';
        });
      }
    }
  }

  /// 搜索防抖：300ms 后执行
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search();
    });
  }

  Future<void> _search() async {
    try {
      final results = await DatabaseService.instance().searchRecipes(
        keyword: _searchCtrl.text,
        categoryId: _selectedCategoryId,
      );
      if (mounted) {
        setState(() => _recipes = results);
      }
    } catch (_) {}
  }

  void _selectCategory(int? categoryId) {
    setState(() => _selectedCategoryId = categoryId);
    _search();
  }

  Future<void> _addRecipe() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecipeEditPage()),
    );
    // 保存后触发全局刷新
    if (result == true) {
      globalRefreshNotifier.value++;
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    ).then((_) {
      // 设置页可能修改了分类，需要刷新
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('藏膳'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: _openSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRecipe,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ===== 搜索栏 =====
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索菜谱...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),

          // ===== 高级搜索折叠按钮 =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(
                    _showAdvancedSearch ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(_showAdvancedSearch ? '收起筛选' : '高级搜索'),
                  onPressed: () => setState(() => _showAdvancedSearch = !_showAdvancedSearch),
                ),
              ],
            ),
          ),

          // ===== 分类筛选栏（动态渲染） =====
          if (_showAdvancedSearch && _categories.isNotEmpty)
            Container(
              height: 44,
              margin: const EdgeInsets.only(bottom: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _categories.length + 1, // +1 为"全部"
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _buildCategoryChip(null, '全部');
                  }
                  final cat = _categories[i - 1];
                  return _buildCategoryChip(cat.id!, cat.name);
                },
              ),
            ),

          const Divider(height: 1),

          // ===== 菜谱列表 =====
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _errorMsg != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(_errorMsg!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _load, child: const Text('重试')),
                          ],
                        ),
                      )
                    : _recipes.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('暂无菜谱', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                SizedBox(height: 8),
                                Text('点击右下角 + 添加你的第一个菜谱',
                                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _recipes.length,
                              itemBuilder: (_, i) => _buildRecipeCard(_recipes[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(int? categoryId, String label) {
    final selected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        onSelected: (_) => _selectCategory(selected ? null : categoryId),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: FutureBuilder<List<String>>(
          future: DatabaseService.instance().getSortedTags(),
          builder: (_, snapshot) {
            final sortedOrder = snapshot.data ?? [];
            final sortedTags = List<String>.from(recipe.tagList)
              ..sort((a, b) {
                final ai = sortedOrder.indexOf(a);
                final bi = sortedOrder.indexOf(b);
                if (ai == -1 && bi == -1) return a.compareTo(b);
                if (ai == -1) return 1;
                if (bi == -1) return -1;
                return ai.compareTo(bi);
              });
            return Text(
              [
                if (recipe.time.isNotEmpty) '⏱ ${recipe.time}',
                if (sortedTags.isNotEmpty) '🏷 ${sortedTags.join("、")}',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            );
          },
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RecipeDetailPage(recipeId: recipe.id!)),
          ).then((_) {
            _load();
          });
        },
      ),
    );
  }
}