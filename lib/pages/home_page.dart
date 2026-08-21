import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/recipe.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/ai_api_service.dart';
import '../services/theme_manager.dart';
import 'recipe_detail_page.dart';
import 'recipe_edit_page.dart';
import 'ai_recipe_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<Recipe> _recipes = [];
  List<Category> _categories = [];
  int? _selectedCategoryId;
  String _keyword = "";
  bool _loading = true;
  String? _errorMsg;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final recipes = await DatabaseService.instance.getAll(
        keyword: _keyword,
        categoryId: _selectedCategoryId,
      );
      final categories = await DatabaseService.instance.getAllCategories();
      if (mounted) {
        setState(() {
          _recipes = recipes;
          _categories = categories;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = "加载失败: $e";
        });
      }
    }
  }

  Future<void> _goToEdit({Recipe? recipe}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeEditPage(recipe: recipe),
      ),
    );
    if (mounted && result == true) _loadData();
  }

  Future<void> _goToAiRecipe() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiRecipePage()),
    );
    if (!mounted) return;
    if (result is AiRecipeResult) {
      final recipe = Recipe(
        name: result.name,
        ingredients: result.ingredients,
        steps: result.steps,
        tips: result.tips,
      );
      final saved = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RecipeEditPage(recipe: recipe)),
      );
      if (mounted && saved == true) _loadData();
    }
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("删除菜谱"),
        content: Text("确定要删除「${recipe.name}」吗？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("删除", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (mounted && confirm == true && recipe.id != null) {
      await DatabaseService.instance.delete(recipe.id!);
      if (mounted) _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeManager = Provider.of<ThemeManager>(context);
    final bgImage = themeManager.getBackgroundImage();
    final hasBg = bgImage != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("藏膳"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
              _loadData();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (hasBg)
            Positioned.fill(
              child: Image(
                image: bgImage!,
                fit: BoxFit.cover,
              ),
            ),
          if (hasBg)
            Positioned.fill(
              child: Container(color: Colors.white.withOpacity(0.55)),
            ),
          Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: "搜索菜名、食材...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _keyword.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              _keyword = "";
                              _loadData();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: hasBg ? Colors.white.withOpacity(0.85) : null,
                  ),
                  onChanged: (v) {
                    _keyword = v;
                    _loadData();
                  },
                ),
              ),
              // Category filters
              if (_categories.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _categories.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text("全部"),
                            selected: _selectedCategoryId == null,
                            onSelected: (_) {
                              setState(() => _selectedCategoryId = null);
                              _loadData();
                            },
                            selectedColor: theme.colorScheme.primaryContainer,
                          ),
                        );
                      }
                      final cat = _categories[i - 1];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(cat.name),
                          selected: _selectedCategoryId == cat.id,
                          onSelected: (_) {
                            setState(() => _selectedCategoryId = _selectedCategoryId == cat.id ? null : cat.id);
                            _loadData();
                          },
                          selectedColor: theme.colorScheme.primaryContainer,
                        ),
                      );
                    },
                  ),
                ),
              // List
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMsg != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                                const SizedBox(height: 12),
                                Text(_errorMsg!, style: TextStyle(color: theme.colorScheme.error)),
                                const SizedBox(height: 16),
                                ElevatedButton(onPressed: _loadData, child: const Text("重试")),
                              ],
                            ),
                          )
                        : _recipes.isEmpty
                            ? _emptyView(theme)
                            : RefreshIndicator(
                                onRefresh: _loadData,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _recipes.length,
                                  itemBuilder: (ctx, i) => _recipeCard(_recipes[i]),
                                ),
                              ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "ai_btn",
            onPressed: _goToAiRecipe,
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            icon: const Icon(Icons.auto_awesome),
            label: const Text("AI 生成"),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "add_btn",
            onPressed: () => _goToEdit(),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _recipeCard(Recipe recipe) {
    final theme = Theme.of(context);
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    final bgImage = themeManager.getBackgroundImage();
    final hasBg = bgImage != null;
    final cardBg = hasBg ? Colors.white.withOpacity(0.9) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      color: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final changed = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RecipeDetailPage(recipeId: recipe.id!)),
          );
          if (mounted && changed == true) _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: recipe.imagePath != null && File(recipe.imagePath!).existsSync()
                    ? Image.file(File(recipe.imagePath!), width: 72, height: 72, fit: BoxFit.cover)
                    : Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.restaurant, color: theme.colorScheme.primary, size: 32),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipe.ingredients.replaceAll("\n", "、"),
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (recipe.tagList.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        children: recipe.tagList
                            .map((t) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    t,
                                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onTertiaryContainer),
                                  ),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat("yyyy-MM-dd HH:mm").format(DateTime.fromMillisecondsSinceEpoch(recipe.updatedAt)),
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                onPressed: () => _deleteRecipe(recipe),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 64, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text("还没有菜谱", style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text("点击 + 或 AI 生成 开始吧", style: TextStyle(fontSize: 13, color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}