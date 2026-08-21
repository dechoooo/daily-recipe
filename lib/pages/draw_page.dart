import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/theme_manager.dart';
import '../utils/constants.dart';

class DrawPage extends StatefulWidget {
  const DrawPage({super.key});

  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<Category> _categories = [];
  Map<int, int> _drawCounts = {};
  List<Recipe> _results = [];
  bool _isDrawing = false;
  late AnimationController _animController;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    ));
    _loadCategories();
    _loadDrawConfig();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseService.instance.getAllCategories();
    setState(() => _categories = cats);
  }

  Future<void> _loadDrawConfig() async {
    final sp = await SharedPreferences.getInstance();
    final json = sp.getString(AppConstants.spKeyDrawConfig);
    if (json != null && json.isNotEmpty) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        setState(() {
          _drawCounts = map.map((k, v) => MapEntry(int.parse(k), v as int));
        });
      } catch (_) {}
    }
  }

  Future<void> _saveDrawConfig() async {
    final sp = await SharedPreferences.getInstance();
    final map = _drawCounts.map((k, v) => MapEntry(k.toString(), v));
    await sp.setString(AppConstants.spKeyDrawConfig, jsonEncode(map));
  }

  Future<void> _draw() async {
    if (_drawCounts.isEmpty || _drawCounts.values.every((c) => c == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先设置抽签数量')),
      );
      return;
    }

    setState(() => _isDrawing = true);
    _results.clear();

    for (final entry in _drawCounts.entries) {
      final categoryId = entry.key;
      final count = entry.value;
      if (count > 0) {
        final recipes = await DatabaseService.instance.getRandomFromCategory(categoryId, count);
        _results.addAll(recipes);
      }
    }

    setState(() => _isDrawing = false);
    _animController.forward(from: 0);
  }

  void _showConfigSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('抽签设置', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text('设置每个分类的抽取数量', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              Expanded(
                child: _categories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category, size: 48, color: theme.colorScheme.outlineVariant),
                            const SizedBox(height: 12),
                            Text('暂无分类', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 8),
                            Text('请先在设置中添加分类', style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _categories.length,
                        itemBuilder: (ctx, i) {
                          final cat = _categories[i];
                          final count = _drawCounts[cat.id] ?? 0;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Text(
                                  cat.name.substring(0, 1),
                                  style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                                ),
                              ),
                              title: Text(cat.name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove_circle_outline, color: theme.colorScheme.primary),
                                    onPressed: count > 0
                                        ? () {
                                            setModalState(() {
                                              _drawCounts[cat.id!] = count - 1;
                                            });
                                            setState(() {});
                                          }
                                        : null,
                                  ),
                                  SizedBox(
                                    width: 32,
                                    child: Text(
                                      '$count',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add_circle_outline, color: theme.colorScheme.primary),
                                    onPressed: () {
                                      setModalState(() {
                                        _drawCounts[cat.id!] = count + 1;
                                      });
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    _saveDrawConfig();
                    Navigator.pop(ctx);
                  },
                  child: const Text('保存设置'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeManager = Provider.of<ThemeManager>(context);
    final bgImage = themeManager.getBackgroundImage();
    final hasBg = bgImage != null;
    final cardBg = hasBg ? Colors.white.withOpacity(0.92) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('卜食'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showConfigSheet,
            tooltip: '抽签设置',
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
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_results.isEmpty && !_isDrawing)
                  Column(
                    children: [
                      Icon(Icons.casino, size: 80, color: theme.colorScheme.primary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        '今天吃什么？',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: hasBg ? Colors.black87 : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '点击下方按钮开始抽签',
                        style: TextStyle(
                          fontSize: 14,
                          color: hasBg ? Colors.grey.shade700 : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                if (_isDrawing)
                  Column(
                    children: [
                      CircularProgressIndicator(color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('正在抽签...', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  )
                else if (_results.isNotEmpty)
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _anim,
                      builder: (ctx, child) {
                        return Transform.scale(
                          scale: _anim.value,
                          child: child,
                        );
                      },
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '今日推荐',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: hasBg ? Colors.black87 : theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: _results.length,
                              itemBuilder: (ctx, i) {
                                final r = _results[i];
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  color: cardBg,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: theme.colorScheme.primaryContainer,
                                      child: Icon(Icons.restaurant, color: theme.colorScheme.primary),
                                    ),
                                    title: Text(
                                      r.name,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Text(
                                      r.ingredients.replaceAll('\n', '、'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                if (!_isDrawing)
                  FilledButton.icon(
                    onPressed: _draw,
                    icon: const Icon(Icons.casino, size: 28),
                    label: const Text('抽签', style: TextStyle(fontSize: 18)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                if (_drawCounts.isEmpty && _results.isEmpty) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _showConfigSheet,
                    icon: const Icon(Icons.settings),
                    label: const Text('设置抽签'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}