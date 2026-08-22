import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/theme_manager.dart';
import '../utils/constants.dart';
import '../main.dart';

/// 设置页面
/// 包括：分类管理（含占用校验）、标签库拖拽排序、主题设置、数据导入导出。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<Category> _categories = [];
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadTags();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseService.instance().getAllCategories();
    setState(() => _categories = cats);
  }

  Future<void> _loadTags() async {
    final tags = await DatabaseService.instance().getAllTags();
    setState(() => _tags = tags);
  }

  // ===== Category Management =====
  void _showCategoryReorderDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _CategoryReorderSheet(
        categories: List.from(_categories),
        onSave: (orderedCats) async {
          await DatabaseService.instance().updateCategoryOrder(orderedCats);
          _loadCategories();
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showCategoryDialog({Category? category}) {
    final ctrl = TextEditingController(text: category?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category == null ? '新增分类' : '编辑分类'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: '分类名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              try {
                if (category == null) {
                  await DatabaseService.instance().insertCategory(
                    Category(name: name, sortOrder: _categories.length),
                  );
                } else {
                  category.name = name;
                  await DatabaseService.instance().updateCategory(category);
                }
                Navigator.pop(ctx);
                _loadCategories();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(Category category) async {
    // 先检查是否被菜谱使用
    final used = await DatabaseService.instance().isCategoryUsed(category.id!);
    if (used) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('该分类下有关联菜谱，请先将菜谱更换到其他分类后再删除'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定要删除「${category.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await DatabaseService.instance().deleteCategory(category.id!);
        _loadCategories();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ===== Tag Management =====
  void _showTagReorderDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        // 局部状态，用于拖拽
        return _TagReorderSheet(
          tags: List.from(_tags),
          onSave: (orderedTags) async {
            await DatabaseService.instance().updateTagOrder(orderedTags);
            _loadTags();
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  // ===== Theme =====
  void _showThemeSettings() {
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('主题设置', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.color_lens),
                title: const Text('主色调'),
                trailing: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: themeManager.config.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                onTap: () async {
                  final color = await showDialog<Color>(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: const Text('选择主色调'),
                      children: [
                        Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
                        Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
                        Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
                        Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
                        Colors.brown, Colors.grey, Colors.blueGrey,
                      ].map((c) => SimpleDialogOption(
                        onPressed: () => Navigator.pop(ctx, c),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                        ),
                      )).toList(),
                    ),
                  );
                  if (color != null) {
                    await themeManager.setPrimaryColor(color);
                  }
                },
              ),
              const Divider(),
              _bgTab(themeManager),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bgTab(ThemeManager themeManager) {
    final bgPath = themeManager.getBackgroundPath();
    final hasBg = bgPath != null;
    final enabled = themeManager.config.bgEnabled;

    return ListView(
      shrinkWrap: true,
      children: [
        SwitchListTile(
          title: const Text('背景图'),
          subtitle: Text(enabled ? '已启用' : '已关闭'),
          value: enabled,
          onChanged: (v) async {
            await themeManager.toggleBackgroundEnabled(v);
            setState(() {});
          },
        ),
        if (hasBg) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(bgPath),
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasBg)
              TextButton.icon(
                onPressed: () async {
                  await themeManager.setBackgroundImage(null);
                  setState(() {});
                },
                icon: const Icon(Icons.clear),
                label: const Text('清除'),
              ),
            TextButton.icon(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  allowMultiple: false,
                );
                if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
                  final appDir = await getApplicationDocumentsDirectory();
                  final savedPath = '${appDir.path}/bg_${DateTime.now().millisecondsSinceEpoch}.png';
                  await File(result.files.first.path!).copy(savedPath);
                  await themeManager.setBackgroundImage(savedPath);
                  setState(() {});
                }
              },
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(hasBg ? '更换' : '选择图片'),
            ),
          ],
        ),
      ],
    );
  }

  // ===== 选择性导入导出 =====
  Future<void> _exportData() async {
    bool includeRecipes = true;
    bool includeCategories = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("选择导出内容"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text("菜谱（含图片、视频、做法变体）"),
                value: includeRecipes,
                onChanged: (v) => setDialogState(() => includeRecipes = v ?? true),
              ),
              CheckboxListTile(
                title: const Text("分类标签"),
                value: includeCategories,
                onChanged: (v) => setDialogState(() => includeCategories = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消")),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("导出"),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    if (!includeRecipes && !includeCategories) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请至少选择一项")));
      return;
    }

    try {
      final data = await DatabaseService.instance().exportAllData(
        includeRecipes: includeRecipes,
        includeCategories: includeCategories,
      );
      final json = jsonEncode(data);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'recipe_export_$timestamp.json';

      // 先保存到临时路径
      final tempDir = await getApplicationDocumentsDirectory();
      final tempPath = '${tempDir.path}/$fileName';
      await File(tempPath).writeAsString(json);

      if (!mounted) return;

      // 弹窗让用户选择：分享 / 保存到下载文件夹
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导出成功'),
          content: const Text('请选择导出方式：'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'share'),
              child: const Text('系统分享'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'download'),
              child: const Text('保存到下载文件夹'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'both'),
              child: const Text('两种都执行'),
            ),
          ],
        ),
      );

      if (action == null) return;

      if (action == 'share' || action == 'both') {
        // 系统分享
        await Share.shareXFiles(
          [XFile(tempPath)],
          subject: '玄灶菜谱数据导出',
          text: '玄灶菜谱数据导出 - $fileName',
        );
      }

      if (action == 'download' || action == 'both') {
        // 保存到系统 Download 下载文件夹
        try {
          // 优先尝试 Android Download 目录
          final downloadDir = Directory('/storage/emulated/0/Download');
          String savePath;
          if (await downloadDir.exists()) {
            savePath = '${downloadDir.path}/$fileName';
          } else {
            // 回退到应用文档目录，但通过分享让用户保存到任意位置
            savePath = tempPath;
          }
          if (savePath != tempPath) {
            await File(tempPath).copy(savePath);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('文件已保存\n$savePath'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('保存失败，请使用系统分享保存'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      if (mounted && action == 'share') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出成功'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        if (!await file.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('文件不存在或无法读取'), backgroundColor: Colors.red),
            );
          }
          return;
        }

        String content;
        try {
          content = await file.readAsString();
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('文件损坏，无法读取'), backgroundColor: Colors.red),
            );
          }
          return;
        }

        Map<String, dynamic> data;
        try {
          data = jsonDecode(content) as Map<String, dynamic>;
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('文件格式错误，不是有效的 JSON 文件'), backgroundColor: Colors.red),
            );
          }
          return;
        }

        final hasRecipes = data.containsKey('recipes') && (data['recipes'] as List).isNotEmpty;
        final hasCategories = data.containsKey('categories') && (data['categories'] as List).isNotEmpty;

        if (!hasRecipes && !hasCategories) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('文件中没有可导入的数据'), backgroundColor: Colors.orange),
            );
          }
          return;
        }

        bool importRecipes = hasRecipes;
        bool importCategories = hasCategories;

        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              title: const Text("选择导入内容"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasRecipes)
                    CheckboxListTile(
                      title: const Text("菜谱"),
                      value: importRecipes,
                      onChanged: (v) => setDialogState(() => importRecipes = v ?? true),
                    ),
                  if (hasCategories)
                    CheckboxListTile(
                      title: const Text("分类标签"),
                      value: importCategories,
                      onChanged: (v) => setDialogState(() => importCategories = v ?? true),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消")),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("继续导入"),
                ),
              ],
            ),
          ),
        );

        if (confirm != true) return;

        // 检查是否有重名数据，弹窗让用户选择策略
        String duplicateStrategy = 'skip';
        final existingNames = <String>[];

        if (importRecipes && data.containsKey('recipes')) {
          final db = DatabaseService.instance();
          final allRecipes = await db.getAllRecipes();
          final existingRecipeNames = allRecipes.map((r) => r.name).toSet();
          for (final r in data['recipes'] as List) {
            if (existingRecipeNames.contains(r['name'])) {
              existingNames.add(r['name']);
            }
          }
        }

        if (existingNames.isNotEmpty) {
          final strategy = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('发现同名菜谱'),
              content: Text('${existingNames.length} 道菜谱重名：\n${existingNames.take(5).join('、')}${existingNames.length > 5 ? '...' : ''}\n\n请选择处理方式：'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'skip'),
                  child: const Text('跳过重名'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'overwrite'),
                  child: const Text('覆盖重名'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  child: const Text('取消导入'),
                ),
              ],
            ),
          );

          if (strategy == null || strategy == 'cancel') return;
          duplicateStrategy = strategy;
        }

        final dbResult = await DatabaseService.instance().importData(
          data,
          importRecipes: importRecipes,
          importCategories: importCategories,
          duplicateStrategy: duplicateStrategy,
        );

        if (mounted) {
          // 触发全局刷新
          globalRefreshNotifier.value++;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '导入完成：新增 ${dbResult['imported']} 条，覆盖 ${dbResult['overwritten']} 条，跳过 ${dbResult['skipped']} 条',
              ),
              backgroundColor: Colors.green,
            ),
          );
          _loadCategories();
          _loadTags();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("设置")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 分类管理
          const Text("分类管理", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._categories.map((cat) => GestureDetector(
            onLongPress: _showCategoryReorderDialog,
            child: ListTile(
              title: Text(cat.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _showCategoryDialog(category: cat)),
                  IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteCategory(cat)),
                ],
              ),
            ),
          )),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('新增分类'),
            onTap: () => _showCategoryDialog(),
          ),
          if (_categories.isNotEmpty)
            TextButton.icon(
              onPressed: _showCategoryReorderDialog,
              icon: const Icon(Icons.swap_vert, size: 18),
              label: const Text('拖拽排序'),
            ),
          const Divider(height: 32),

          // 标签库管理
          const Text("标签库", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            "拖拽调整标签显示顺序，不影响菜谱内部数据",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _tags.map((tag) => GestureDetector(
              onLongPress: _showTagReorderDialog,
              child: Chip(
                label: Text(tag, style: const TextStyle(fontSize: 13)),
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ),
            )).toList(),
          ),
          if (_tags.isNotEmpty)
            TextButton.icon(
              onPressed: _showTagReorderDialog,
              icon: const Icon(Icons.swap_vert, size: 18),
              label: const Text('拖拽排序'),
            ),
          const Divider(height: 32),

          // 主题设置
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('主题设置'),
            onTap: _showThemeSettings,
          ),
          const Divider(height: 32),

          // 数据管理
          const Text("数据管理", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('导出数据'),
            subtitle: const Text('可选择导出菜谱或分类'),
            onTap: _exportData,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('导入数据'),
            subtitle: const Text('可选择导入菜谱或分类'),
            onTap: _importData,
          ),
        ],
      ),
    );
  }
}

/// 分类拖拽排序组件
class _CategoryReorderSheet extends StatefulWidget {
  final List<Category> categories;
  final void Function(List<Category>) onSave;

  const _CategoryReorderSheet({required this.categories, required this.onSave});

  @override
  State<_CategoryReorderSheet> createState() => _CategoryReorderSheetState();
}

class _CategoryReorderSheetState extends State<_CategoryReorderSheet> {
  late List<Category> _categories;

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('拖拽调整分类顺序', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '仅调整展示顺序，不影响菜谱关联',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          if (_categories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('暂无分类', style: TextStyle(color: Colors.grey)),
            )
          else
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: _categories.length,
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _categories.removeAt(oldIndex);
                    _categories.insert(newIndex, item);
                  });
                },
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  return ListTile(
                    key: ValueKey(cat.id),
                    title: Text(cat.name),
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onSave(_categories),
              child: const Text('保存顺序'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 标签拖拽排序组件（独立于 SettingsPage，避免 rebuild 重置状态）
class _TagReorderSheet extends StatefulWidget {
  final List<String> tags;
  final void Function(List<String>) onSave;

  const _TagReorderSheet({required this.tags, required this.onSave});

  @override
  State<_TagReorderSheet> createState() => _TagReorderSheetState();
}

class _TagReorderSheetState extends State<_TagReorderSheet> {
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.tags);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('拖拽调整标签顺序', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_tags.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('暂无标签', style: TextStyle(color: Colors.grey)),
            )
          else
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: _tags.length,
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    // ❗Flutter ReorderableListView 向下移动时 newIndex 会多 1
                    if (newIndex > oldIndex) newIndex--;
                    final item = _tags.removeAt(oldIndex);
                    _tags.insert(newIndex, item);
                  });
                },
                itemBuilder: (_, i) {
                  return ListTile(
                    key: ValueKey(_tags[i]),
                    title: Text(_tags[i]),
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onSave(_tags),
              child: const Text('保存顺序'),
            ),
          ),
        ],
      ),
    );
  }
}