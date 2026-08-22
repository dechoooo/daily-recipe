import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';
import 'recipe_detail_page.dart';

/// 卜食页面 — 极简重构版
/// 顶部：左侧标题「卜食」，中间卜膳/卜材Tab切换，右上角配置按钮
/// 所有配置收纳到弹窗面板，主页面保持大骰子UI常驻
class DrawPage extends StatefulWidget {
  final ValueNotifier<int> refreshNotifier;

  const DrawPage({super.key, required this.refreshNotifier});

  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> {
  // 模式：true=卜膳，false=卜材
  bool _isShanMode = true;

  // ===== 卜膳相关 =====
  List<Category> _categories = [];
  Map<int, bool> _categoryEnabled = {};
  Map<String, int> _drawCounts = {};

  // ===== 卜材相关 =====
  final _ingredientCtrl = TextEditingController();
  List<Recipe> _ingredientResults = [];
  Recipe? _randomResult;
  bool _showIngredientResults = false;
  bool _hasSearched = false;

  // ===== 抽签结果 =====
  List<Recipe> _drawResults = [];
  bool _hasDrawn = false;

  @override
  void initState() {
    super.initState();
    widget.refreshNotifier.addListener(_loadData);
    _loadData();
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_loadData);
    _ingredientCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final cats = await DatabaseService.instance().getAllCategories();
    final sp = await SharedPreferences.getInstance();
    final savedCounts = sp.getString(AppConstants.spKeyDrawConfig);
    Map<String, int> counts = {};
    if (savedCounts != null) {
      try {
        final raw = savedCounts.split(';');
        for (final entry in raw) {
          final parts = entry.split('=');
          if (parts.length == 2) {
            counts[parts[0]] = int.tryParse(parts[1]) ?? 1;
          }
        }
      } catch (_) {
        counts = {};
      }
    }

    for (final cat in cats) {
      _categoryEnabled.putIfAbsent(cat.id!, () => true);
      if (!counts.containsKey(cat.name)) {
        counts[cat.name] = 1;
      }
    }

    if (mounted) {
      setState(() {
        _categories = cats;
        _drawCounts = counts;
      });
    }
  }

  void _saveCounts() {
    SharedPreferences.getInstance().then((sp) {
      final str = _drawCounts.entries.map((e) => '${e.key}=${e.value}').join(';');
      sp.setString(AppConstants.spKeyDrawConfig, str);
    });
  }

  // ==================== 卜膳：抽签 ====================

  Future<void> _startDraw() async {
    final enabledCats = _categories.where((c) => _categoryEnabled[c.id] == true).toList();
    if (enabledCats.isEmpty) {
      _showToast('请先勾选至少一个分类');
      return;
    }

    final db = DatabaseService.instance();
    final results = <Recipe>[];

    for (final cat in enabledCats) {
      final recipes = await db.getRecipesByCategory(cat.id!);
      if (recipes.isEmpty) continue;
      final count = _drawCounts[cat.name] ?? 1;
      final shuffled = List<Recipe>.from(recipes)..shuffle(Random());
      results.addAll(shuffled.take(count));
    }

    if (results.isEmpty) {
      _showToast('该分类下暂无菜谱，请添加菜谱后再抽签');
      return;
    }

    if (!mounted) return;
    setState(() {
      _drawResults = results;
      _hasDrawn = true;
    });
  }

  // ==================== 卜材：检索 ====================

  Future<void> _listByIngredient() async {
    final keyword = _ingredientCtrl.text.trim();
    if (keyword.isEmpty) {
      _showToast('请输入食材名称');
      return;
    }

    final results = await DatabaseService.instance().searchByIngredient(keyword);
    if (!mounted) return;
    setState(() {
      _ingredientResults = results;
      _randomResult = null;
      _showIngredientResults = true;
      _hasSearched = true;
    });

    if (results.isEmpty) {
      _showToast('未找到使用该食材的菜谱');
    }
  }

  Future<void> _randomByIngredient() async {
    final keyword = _ingredientCtrl.text.trim();
    if (keyword.isEmpty) {
      _showToast('请输入食材名称');
      return;
    }

    final results = await DatabaseService.instance().searchByIngredient(keyword);
    if (results.isEmpty) {
      if (mounted) _showToast('未找到使用该食材的菜谱');
      return;
    }

    final random = results[Random().nextInt(results.length)];
    if (!mounted) return;
    setState(() {
      _randomResult = random;
      _showIngredientResults = true;
      _hasSearched = true;
    });
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ==================== 统一配置弹窗（卜膳/卜材复用一个Widget） ====================

  void _showConfigPanel() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide.none,
      ),
      builder: (ctx) => _DrawConfigPanel(
        isShanMode: _isShanMode,
        categories: _categories,
        categoryEnabled: _categoryEnabled,
        drawCounts: _drawCounts,
        ingredientCtrl: _ingredientCtrl,
        onListByIngredient: () {
          Navigator.pop(ctx);
          _listByIngredient();
        },
        onRandomByIngredient: () {
          Navigator.pop(ctx);
          _randomByIngredient();
        },
        onToggleCategory: (catId, enabled) {
          setState(() => _categoryEnabled[catId] = enabled);
        },
        onUpdateCount: (catName, count) {
          setState(() => _drawCounts[catName] = count);
          _saveCounts();
        },
      ),
    );
  }

  // ==================== 抽签结果弹窗 ====================

  void _showDrawResultSheet() {
    if (_drawResults.isEmpty) return;
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide.none,
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.casino, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text('卜膳结果', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('关闭'),
                ),
              ],
            ),
            const Divider(),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _drawResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = _drawResults[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      child: Text('${i + 1}', style: TextStyle(color: theme.colorScheme.primary)),
                    ),
                    title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(r.time.isNotEmpty ? '⏱ ${r.time}' : ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RecipeDetailPage(recipeId: r.id!)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 构建 UI ====================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('卜食'),
        centerTitle: false,
        actions: [
          // 卜膳/卜材 Tab 切换（居中区域）
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabBtn('卜膳', true, theme),
                  _buildTabBtn('卜材', false, theme),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 配置按钮（用 GestureDetector 替代 IconButton 避免 Tooltip 泄漏）
          GestureDetector(
            onTap: _showConfigPanel,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.tune, color: Colors.white),
            ),
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildTabBtn(String label, bool isShan, ThemeData theme) {
    final selected = _isShanMode == isShan;
    return GestureDetector(
      onTap: () {
        if (selected) return;
        setState(() {
          _isShanMode = isShan;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? theme.colorScheme.primary : Colors.white,
          ),
        ),
      ),
    );
  }

  /// 主体内容：大骰子UI + 模式文案 + 结果
  Widget _buildBody(ThemeData theme) {
    final primary = theme.colorScheme.primary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ===== 大骰子（整体半透明大骰子，无双层叠加） =====
            GestureDetector(
              onTap: _isShanMode ? _startDraw : _randomByIngredient,
              child: Icon(Icons.casino, size: 100, color: primary.withOpacity(0.35)),
            ),
            const SizedBox(height: 28),

            // ===== 模式差异化文案 =====
            Text(
              _isShanMode ? '今天吃什么？' : '拿食材做什么？',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _isShanMode
                  ? '挑选分类，抽签决定吃什么'
                  : '输入食材，看看能做哪些菜',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),

            // ===== 卜材模式：输入框快捷入口 =====
            if (!_isShanMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: TextField(
                  controller: _ingredientCtrl,
                  decoration: InputDecoration(
                    hintText: '输入食材...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    suffixIcon: _ingredientCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _ingredientCtrl.clear();
                              setState(() {
                                _ingredientResults = [];
                                _randomResult = null;
                                _showIngredientResults = false;
                                _hasSearched = false;
                              });
                            },
                          )
                        : null,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _listByIngredient(),
                ),
              ),

            // ===== 底部按钮（主题色，不出现黄色） =====
            SizedBox(
              width: 220,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isShanMode ? _startDraw : _listByIngredient,
                icon: Icon(_isShanMode ? Icons.casino : Icons.search, size: 22),
                label: Text(
                  _isShanMode ? '开始卜膳' : '开始卜材',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
              ),
            ),

            // ===== 卜材结果 =====
            if (!_isShanMode && _hasSearched) ...[
              const SizedBox(height: 24),
              if (_randomResult != null)
                _buildIngredientResultCard(theme),
              if (_showIngredientResults && _randomResult == null)
                _buildIngredientResultList(theme),
            ],

            // ===== 卜膳结果入口 =====
            if (_isShanMode && _hasDrawn && _drawResults.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildDrawResultEntry(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDrawResultEntry(ThemeData theme) {
    final primary = theme.colorScheme.primary;
    return Card(
      color: primary.withOpacity(0.08),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primary,
          child: const Icon(Icons.casino, color: Colors.white, size: 20),
        ),
        title: Text('抽到 ${_drawResults.length} 道菜谱', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(_drawResults.map((r) => r.name).join('、'),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: _showDrawResultSheet,
      ),
    );
  }

  Widget _buildIngredientResultCard(ThemeData theme) {
    final primary = theme.colorScheme.primary;
    return Card(
      color: primary.withOpacity(0.08),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primary,
          child: const Icon(Icons.shuffle, color: Colors.white, size: 20),
        ),
        title: Text(_randomResult!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_randomResult!.time.isNotEmpty ? '⏱ ${_randomResult!.time}' : ''),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeDetailPage(recipeId: _randomResult!.id!),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIngredientResultList(ThemeData theme) {
    if (_ingredientResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('未找到使用该食材的菜谱', style: TextStyle(color: Colors.grey, fontSize: 15)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '找到 ${_ingredientResults.length} 道菜谱',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        ..._ingredientResults.map((r) => Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            title: Text(r.name),
            subtitle: Text(r.time.isNotEmpty ? '⏱ ${r.time}' : ''),
            trailing: const Icon(Icons.chevron_right, size: 18),
            dense: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RecipeDetailPage(recipeId: r.id!)),
              );
            },
          ),
        )),
      ],
    );
  }
}

// =====================================================================
// 统一配置弹窗组件 — 卜膳/卜材复用同一个Widget，只替换内部内容
// 圆角、背景、间距、分割线完全统一，颜色全部遵循主题配色
// =====================================================================
class _DrawConfigPanel extends StatefulWidget {
  final bool isShanMode;
  final List<Category> categories;
  final Map<int, bool> categoryEnabled;
  final Map<String, int> drawCounts;
  final TextEditingController ingredientCtrl;
  final VoidCallback onListByIngredient;
  final VoidCallback onRandomByIngredient;
  final void Function(int, bool) onToggleCategory;
  final void Function(String, int) onUpdateCount;

  const _DrawConfigPanel({
    required this.isShanMode,
    required this.categories,
    required this.categoryEnabled,
    required this.drawCounts,
    required this.ingredientCtrl,
    required this.onListByIngredient,
    required this.onRandomByIngredient,
    required this.onToggleCategory,
    required this.onUpdateCount,
  });

  @override
  State<_DrawConfigPanel> createState() => _DrawConfigPanelState();
}

class _DrawConfigPanelState extends State<_DrawConfigPanel> {
  late TextEditingController _ingredientCtrl;

  late Map<int, bool> _localCategoryEnabled;
  late Map<String, int> _localDrawCounts;

  @override
  void initState() {
    super.initState();
    _ingredientCtrl = TextEditingController(text: widget.ingredientCtrl.text);
    _localCategoryEnabled = Map.from(widget.categoryEnabled);
    _localDrawCounts = Map.from(widget.drawCounts);
  }

  @override
  void dispose() {
    // 关闭弹窗时将食材输入同步回主页面
    widget.ingredientCtrl.text = _ingredientCtrl.text;
    _ingredientCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      constraints: BoxConstraints(
        maxHeight: widget.isShanMode
            ? MediaQuery.of(context).size.height * 0.65
            : MediaQuery.of(context).size.height * 0.45,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== 统一的标题栏 =====
          Row(
            children: [
              Icon(
                widget.isShanMode ? Icons.tune : Icons.search,
                color: primary,
              ),
              const SizedBox(width: 8),
              Text(
                widget.isShanMode ? '卜膳配置' : '食材检索',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.isShanMode
                ? '勾选要参与抽签的分类，设置每类抽取数量'
                : '输入食材名称，检索或随机选择菜式',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const Divider(),

          // ===== 模式不同的内容区 =====
          if (widget.isShanMode) _buildShanContent(primary) else _buildCaiContent(primary),
        ],
      ),
    );
  }

  /// 卜膳内容：分类开关 + 抽取数量
  Widget _buildShanContent(Color primary) {
    return Flexible(
      child: ListView(
        children: widget.categories.map((cat) {
          final enabled = _localCategoryEnabled[cat.id] ?? true;
          final count = _localDrawCounts[cat.name] ?? 1;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: Icon(
                enabled ? Icons.check_circle : Icons.radio_button_unchecked,
                color: enabled ? primary : Colors.grey,
              ),
              title: Text(cat.name, style: const TextStyle(fontSize: 15)),
              trailing: enabled
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            if (count > 1) {
                              setState(() {
                                _localDrawCounts[cat.name] = count - 1;
                              });
                              widget.onUpdateCount(cat.name, count - 1);
                            }
                          },
                        ),
                        Container(
                          width: 28,
                          alignment: Alignment.center,
                          child: Text('$count',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _localDrawCounts[cat.name] = count + 1;
                            });
                            widget.onUpdateCount(cat.name, count + 1);
                          },
                        ),
                      ],
                    )
                  : Text('已关闭', style: TextStyle(color: Colors.grey, fontSize: 13)),
              onTap: () {
                setState(() {
                  _localCategoryEnabled[cat.id!] = !enabled;
                });
                widget.onToggleCategory(cat.id!, !enabled);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 卜材内容：食材输入 + 按钮（无黄色，全部主题色）
  Widget _buildCaiContent(Color primary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: _ingredientCtrl,
          decoration: const InputDecoration(
            labelText: '输入食材名称',
            hintText: '如：鸡胸肉、番茄、鸡蛋',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            widget.ingredientCtrl.text = _ingredientCtrl.text;
            widget.onListByIngredient();
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.ingredientCtrl.text = _ingredientCtrl.text;
                  widget.onListByIngredient();
                },
                icon: const Icon(Icons.list, size: 18),
                label: const Text('列出相关菜式'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.ingredientCtrl.text = _ingredientCtrl.text;
                  widget.onRandomByIngredient();
                },
                icon: const Icon(Icons.shuffle, size: 18),
                label: const Text('随机择一'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}