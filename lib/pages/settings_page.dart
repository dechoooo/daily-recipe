import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/theme_manager.dart';
import '../utils/constants.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _baseUrlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  bool _obscureKey = true;
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadCategories();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    _baseUrlCtrl.text = sp.getString(AppConstants.spKeyApiBaseUrl) ?? AppConstants.defaultBaseUrl;
    _modelCtrl.text = sp.getString(AppConstants.spKeyApiModel) ?? AppConstants.defaultModel;
    _apiKeyCtrl.text = sp.getString(AppConstants.spKeyApiKey) ?? "";
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseService.instance.getAllCategories();
    setState(() => _categories = cats);
  }

  Future<void> _saveApiConfig() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(AppConstants.spKeyApiBaseUrl, _baseUrlCtrl.text.trim());
    await sp.setString(AppConstants.spKeyApiModel, _modelCtrl.text.trim());
    await sp.setString(AppConstants.spKeyApiKey, _apiKeyCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("配置已保存"), backgroundColor: Colors.green),
      );
    }
  }

  void _applyPreset(String baseUrl, String model) {
    _baseUrlCtrl.text = baseUrl;
    _modelCtrl.text = model;
  }

  // ===== Category Management =====
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
              if (category == null) {
                await DatabaseService.instance.insertCategory(Category(name: name, sortOrder: _categories.length));
              } else {
                category.name = name;
                await DatabaseService.instance.updateCategory(category);
              }
              Navigator.pop(ctx);
              _loadCategories();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定要删除「${category.name}」吗？该分类下的菜谱不会被删除。'),
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
      await DatabaseService.instance.deleteCategory(category.id!);
      _loadCategories();
    }
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
              // 主色调
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
              // 统一背景设置
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
        // 开关
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
    // 弹出选择对话框
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
      final data = await DatabaseService.instance.exportAllData(
        includeRecipes: includeRecipes,
        includeCategories: includeCategories,
      );
      final json = jsonEncode(data);
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/recipe_export_${DateTime.now().millisecondsSinceEpoch}.json';
      await File(path).writeAsString(json);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出成功: $path'), backgroundColor: Colors.green),
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
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        // 检查文件包含哪些内容
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

        // 弹出选择对话框
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
                  if (!hasRecipes && hasCategories)
                    const Text("仅包含分类标签"),
                  if (hasRecipes && !hasCategories)
                    const Text("仅包含菜谱"),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消")),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("导入"),
                ),
              ],
            ),
          ),
        );

        if (confirm != true) return;

        await DatabaseService.instance.importData(
          data,
          importRecipes: importRecipes,
          importCategories: importCategories,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('导入成功'), backgroundColor: Colors.green),
          );
          _loadCategories();
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
          ..._categories.map((cat) => ListTile(
            title: Text(cat.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: () => _showCategoryDialog(category: cat)),
                IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteCategory(cat)),
              ],
            ),
          )),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('新增分类'),
            onTap: () => _showCategoryDialog(),
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
          const Divider(height: 32),
          // AI 接口配置
          const Text("AI 接口配置", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            "支持 DeepSeek / 豆包 / 智谱 / 通义 / Moonshot / OpenAI 等 OpenAI 兼容接口",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrlCtrl,
            decoration: const InputDecoration(
              labelText: "API Base URL",
              hintText: "https://api.deepseek.com",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(
              labelText: "Model",
              hintText: "deepseek-chat",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyCtrl,
            maxLines: 2,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: "API Key",
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveApiConfig,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text("保存配置"),
            ),
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 12),
          const Text("常用配置快速填充", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _presetTile("DeepSeek", "https://api.deepseek.com", "deepseek-chat"),
          _presetTile("豆包 (火山方舟)", "https://ark.cn-beijing.volces.com/api/v3", "ep-xxxxxx（替换为你的接入点 ID）"),
          _presetTile("智谱 GLM", "https://open.bigmodel.cn/api/paas/v4", "glm-4-flash"),
          _presetTile("通义千问", "https://dashscope.aliyuncs.com/compatible-mode/v1", "qwen-turbo"),
          _presetTile("Moonshot Kimi", "https://api.moonshot.cn/v1", "moonshot-v1-8k"),
          _presetTile("OpenAI", "https://api.openai.com/v1", "gpt-4o-mini"),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 12),
          const Text("数据与隐私说明", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            "✅ 所有菜谱、图片全部保存在本机 SQLite 数据库，不上传云端。\n"
            "✅ 仅在你主动点击「AI 整理菜谱」时，将粘贴的文本发送到你配置的 AI 接口。\n"
            "✅ API Key 仅保存在本机 SharedPreferences，不会上传。",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.6),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _presetTile(String name, String baseUrl, String model) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text("Model: $model", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: TextButton(
        onPressed: () {
          _applyPreset(baseUrl, model);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("已填充 $name 配置，记得填写 API Key 后保存")),
          );
        },
        child: const Text("填充"),
      ),
    );
  }
}
