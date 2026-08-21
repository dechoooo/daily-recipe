import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import '../models/category.dart';
import '../models/media_item.dart';
import '../models/variant.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';

class RecipeEditPage extends StatefulWidget {
  final Recipe? recipe;
  const RecipeEditPage({super.key, this.recipe});

  @override
  State<RecipeEditPage> createState() => _RecipeEditPageState();
}

class _RecipeEditPageState extends State<RecipeEditPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ingredientsCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController();
  final _tipsCtrl = TextEditingController();

  List<Category> _categories = [];
  int? _selectedCategoryId;
  String? _coverImagePath;
  List<MediaItem> _mediaItems = [];
  bool _saving = false;

  // Variant 管理
  List<Variant> _variants = [];
  late TabController _tabController;
  int _activeVariantIdx = 0;
  final List<TextEditingController> _variantNameCtrls = [];
  final List<TextEditingController> _variantIngredientsCtrls = [];
  final List<TextEditingController> _variantStepsCtrls = [];
  final List<TextEditingController> _variantTipsCtrls = [];

  // 草稿
  String get _draftKey => "${AppConstants.spKeyDraftPrefix}${widget.recipe?.id ?? 'new'}";
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    final r = widget.recipe;
    if (r != null) {
      _nameCtrl.text = r.name;
      _selectedCategoryId = r.categoryId;
      _coverImagePath = r.imagePath;
      _loadMedia(r.id!);
      _loadVariants(r.id!);
    } else {
      // 新建菜谱：创建默认变体
      _variants = [
        Variant(recipeId: 0, name: '默认做法'),
      ];
      _initVariantControllers();
      _tabController = TabController(length: 1, vsync: this);
      _tabController.addListener(() {
        if (_tabController.indexIsChanging) return;
        setState(() => _activeVariantIdx = _tabController.index);
      });
      _checkDraft();
    }

    // 监听变化
    _nameCtrl.addListener(_markChanged);
    _ingredientsCtrl.addListener(_markChanged);
    _stepsCtrl.addListener(_markChanged);
    _tipsCtrl.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasChanges) {
      _hasChanges = true;
      _saveDraftDebounced();
    }
  }

  Future<void> _checkDraft() async {
    final sp = await SharedPreferences.getInstance();
    final draft = sp.getString(_draftKey);
    if (draft != null && draft.isNotEmpty) {
      try {
        final map = jsonDecode(draft) as Map<String, dynamic>;
        if (mounted) {
          final keep = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("发现未保存的草稿"),
              content: const Text("是否恢复上次编辑的内容？"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("丢弃")),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("恢复")),
              ],
            ),
          );
          if (keep == true) {
            _nameCtrl.text = map['name'] ?? '';
            _selectedCategoryId = map['categoryId'] as int?;
            _coverImagePath = map['coverImagePath'] as String?;
            // 恢复变体
            final variantsJson = map['variants'] as List? ?? [];
            _variants = variantsJson.map((v) => Variant.fromMap(Map<String, dynamic>.from(v))).toList();
            if (_variants.isEmpty) {
              _variants = [Variant(recipeId: 0, name: '默认做法')];
            }
            _initVariantControllers();
            _tabController = TabController(length: _variants.length, vsync: this);
            _tabController.addListener(() {
              if (_tabController.indexIsChanging) return;
              setState(() => _activeVariantIdx = _tabController.index);
            });
          } else {
            await sp.remove(_draftKey);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _saveDraftDebounced() async {
    // 延迟保存草稿
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_hasChanges || !mounted) return;
    await _saveDraft();
  }

  Future<void> _saveDraft() async {
    final sp = await SharedPreferences.getInstance();
    final map = {
      'name': _nameCtrl.text,
      'categoryId': _selectedCategoryId,
      'coverImagePath': _coverImagePath,
      'variants': _variants.map((v) => v.toMap()).toList(),
    };
    await sp.setString(_draftKey, jsonEncode(map));
  }

  Future<void> _clearDraft() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_draftKey);
  }

  void _initVariantControllers() {
    for (final ctrl in _variantNameCtrls) ctrl.dispose();
    for (final ctrl in _variantIngredientsCtrls) ctrl.dispose();
    for (final ctrl in _variantStepsCtrls) ctrl.dispose();
    for (final ctrl in _variantTipsCtrls) ctrl.dispose();
    _variantNameCtrls.clear();
    _variantIngredientsCtrls.clear();
    _variantStepsCtrls.clear();
    _variantTipsCtrls.clear();

    for (final v in _variants) {
      _variantNameCtrls.add(TextEditingController(text: v.name));
      _variantIngredientsCtrls.add(TextEditingController(text: v.ingredients));
      _variantStepsCtrls.add(TextEditingController(text: v.steps));
      _variantTipsCtrls.add(TextEditingController(text: v.tips));
    }
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseService.instance.getAllCategories();
    setState(() => _categories = cats);
  }

  Future<void> _loadMedia(int recipeId) async {
    final media = await DatabaseService.instance.getMediaByRecipe(recipeId);
    setState(() => _mediaItems = media);
  }

  Future<void> _loadVariants(int recipeId) async {
    final variants = await DatabaseService.instance.getVariantsByRecipe(recipeId);
    setState(() {
      _variants = variants;
      if (_variants.isEmpty) {
        _variants = [Variant(recipeId: recipeId, name: '默认做法')];
      }
      _initVariantControllers();
      _tabController = TabController(length: _variants.length, vsync: this);
      _tabController.addListener(() {
        if (_tabController.indexIsChanging) return;
        setState(() => _activeVariantIdx = _tabController.index);
      });
    });
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = "cover_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}";
    final savedPath = p.join(appDir.path, fileName);
    await File(picked.path).copy(savedPath);
    setState(() => _coverImagePath = savedPath);
    _markChanged();
  }

  Future<void> _pickMedia(String section) async {
    final picker = ImagePicker();
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择媒体类型'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'image'), child: const Text('图片')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'video'), child: const Text('视频')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
    if (type == null) return;

    XFile? picked;
    if (type == 'image') {
      picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    } else {
      picked = await picker.pickVideo(source: ImageSource.gallery);
    }
    if (picked == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final ext = p.extension(picked.path);
    final fileName = "${section}_${DateTime.now().millisecondsSinceEpoch}$ext";
    final savedPath = p.join(appDir.path, fileName);
    await File(picked.path).copy(savedPath);

    final media = MediaItem(
      recipeId: widget.recipe?.id ?? 0,
      filePath: savedPath,
      type: type,
      section: section,
      sortOrder: _mediaItems.where((m) => m.section == section).length,
    );
    setState(() => _mediaItems.add(media));
  }

  Future<void> _removeMedia(MediaItem media) async {
    if (media.id != null) {
      await DatabaseService.instance.deleteMedia(media.id!);
    }
    final file = File(media.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    setState(() => _mediaItems.remove(media));
  }

  // === Variant 操作 ===
  void _addVariant() {
    setState(() {
      _variants.add(Variant(recipeId: widget.recipe?.id ?? 0, name: '新做法 ${_variants.length + 1}'));
      _initVariantControllers();
      _tabController.dispose();
      _tabController = TabController(length: _variants.length, vsync: this);
      _tabController.addListener(() {
        if (_tabController.indexIsChanging) return;
        setState(() => _activeVariantIdx = _tabController.index);
      });
      _tabController.animateTo(_variants.length - 1);
    });
    _markChanged();
  }

  Future<void> _removeVariant(int idx) async {
    if (_variants.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("至少保留一个做法")));
      return;
    }
    final v = _variants[idx];
    if (v.id != null) {
      await DatabaseService.instance.deleteVariant(v.id!);
    }
    setState(() {
      _variants.removeAt(idx);
      _initVariantControllers();
      _tabController.dispose();
      _tabController = TabController(length: _variants.length, vsync: this);
      _tabController.addListener(() {
        if (_tabController.indexIsChanging) return;
        setState(() => _activeVariantIdx = _tabController.index);
      });
      if (_activeVariantIdx >= _variants.length) {
        _activeVariantIdx = _variants.length - 1;
        _tabController.animateTo(_activeVariantIdx);
      }
    });
    _markChanged();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final recipe = Recipe(
        id: widget.recipe?.id,
        name: _nameCtrl.text.trim(),
        ingredients: _ingredientsCtrl.text.trim(),
        steps: _stepsCtrl.text.trim(),
        tips: _tipsCtrl.text.trim(),
        categoryId: _selectedCategoryId,
        imagePath: _coverImagePath,
        createdAt: widget.recipe?.createdAt,
      );
      int recipeId;
      if (widget.recipe?.id == null) {
        recipeId = await DatabaseService.instance.insert(recipe);
      } else {
        await DatabaseService.instance.update(recipe);
        recipeId = widget.recipe!.id!;
        await DatabaseService.instance.deleteMediaByRecipe(recipeId);
      }
      // Save media items
      for (final media in _mediaItems) {
        media.recipeId = recipeId;
        if (media.id == null) {
          await DatabaseService.instance.insertMedia(media);
        }
      }
      // Save variants
      await DatabaseService.instance.deleteVariantsByRecipe(recipeId);
      for (int i = 0; i < _variants.length; i++) {
        final v = _variants[i];
        v.recipeId = recipeId;
        v.sortOrder = i;
        // 从 controller 读取最新内容
        v.name = _variantNameCtrls[i].text.trim();
        v.ingredients = _variantIngredientsCtrls[i].text.trim();
        v.steps = _variantStepsCtrls[i].text.trim();
        v.tips = _variantTipsCtrls[i].text.trim();
        await DatabaseService.instance.insertVariant(v);
      }
      // 清除草稿
      await _clearDraft();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("保存失败: $e")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ingredientsCtrl.dispose();
    _stepsCtrl.dispose();
    _tipsCtrl.dispose();
    for (final ctrl in _variantNameCtrls) ctrl.dispose();
    for (final ctrl in _variantIngredientsCtrls) ctrl.dispose();
    for (final ctrl in _variantStepsCtrls) ctrl.dispose();
    for (final ctrl in _variantTipsCtrls) ctrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("未保存的修改"),
        content: const Text("要保留草稿以便下次继续编辑吗？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("丢弃")),
          TextButton(
            onPressed: () async {
              await _saveDraft();
              Navigator.pop(ctx, true);
            },
            child: const Text("保留草稿"),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消")),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.recipe?.id != null;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? "编辑菜谱" : "新增菜谱"),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("保存", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面图片
                const Text('封面图片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    onTap: _pickCoverImage,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _coverImagePath != null && File(_coverImagePath!).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(File(_coverImagePath!), fit: BoxFit.cover),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 32, color: Colors.grey),
                                SizedBox(height: 4),
                                Text("添加封面", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 分类选择
                DropdownButtonFormField<int>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: "分类",
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(value: cat.id, child: Text(cat.name));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                ),
                const SizedBox(height: 16),
                // 名称
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "菜谱名称 *",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "请输入菜谱名称" : null,
                ),
                const SizedBox(height: 24),

                // === 变体管理 ===
                Row(
                  children: [
                    const Text("做法变体", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addVariant,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("添加做法"),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "一个菜谱可以有多种烹饪方式，如：火烤、空气炸锅、清蒸等",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),

                // Tab bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.orange,
                    unselectedLabelColor: Colors.grey,
                    indicator: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    tabs: _variants.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final v = entry.value;
                      return Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_variantNameCtrls[idx].text.isEmpty ? v.name : _variantNameCtrls[idx].text),
                            if (_variants.length > 1) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _removeVariant(idx),
                                child: const Icon(Icons.close, size: 14, color: Colors.red),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // 当前变体编辑区
                if (_variants.isNotEmpty && _activeVariantIdx < _variants.length)
                  _buildVariantEditor(_activeVariantIdx),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _saving ? const CircularProgressIndicator() : const Text("保存菜谱"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVariantEditor(int idx) {
    if (idx >= _variants.length) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 变体名称
        TextFormField(
          controller: _variantNameCtrls[idx],
          decoration: const InputDecoration(
            labelText: "做法名称 *",
            hintText: "如：火烤、空气炸锅、清蒸",
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _markChanged(),
        ),
        const SizedBox(height: 16),
        // 食材
        TextFormField(
          controller: _variantIngredientsCtrls[idx],
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: "食材清单（每条一行）",
            hintText: "例如：\n鸡蛋 2个\n西红柿 2个\n盐 适量",
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: (_) => _markChanged(),
        ),
        const SizedBox(height: 8),
        _buildMediaSection('ingredients_${_variants[idx].id ?? 'new_$idx'}', '食材图片/视频'),
        const SizedBox(height: 16),
        // 步骤
        TextFormField(
          controller: _variantStepsCtrls[idx],
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: "制作步骤（每条一行）",
            hintText: "例如：\n1. 鸡蛋打散\n2. 热锅倒油...",
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: (_) => _markChanged(),
        ),
        const SizedBox(height: 8),
        _buildMediaSection('steps_${_variants[idx].id ?? 'new_$idx'}', '步骤图片/视频'),
        const SizedBox(height: 16),
        // 小贴士
        TextFormField(
          controller: _variantTipsCtrls[idx],
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: "小贴士/备注",
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: (_) => _markChanged(),
        ),
        const SizedBox(height: 8),
        _buildMediaSection('tips_${_variants[idx].id ?? 'new_$idx'}', '备注图片/视频'),
      ],
    );
  }

  Widget _buildMediaSection(String section, String title) {
    final items = _mediaItems.where((m) => m.section == section).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _pickMedia(section),
              icon: const Icon(Icons.add_photo_alternate, size: 18),
              label: const Text('添加'),
            ),
          ],
        ),
        if (items.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final media = items[i];
                return Stack(
                  children: [
                    Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: media.type == 'image' && File(media.filePath).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(media.filePath), fit: BoxFit.cover),
                            )
                          : const Center(child: Icon(Icons.videocam, size: 32)),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _removeMedia(media),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
