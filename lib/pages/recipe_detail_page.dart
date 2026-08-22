import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../models/media_item.dart';
import '../models/variant.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/theme_manager.dart';
import 'recipe_edit_page.dart';

class RecipeDetailPage extends StatefulWidget {
  final int recipeId;
  const RecipeDetailPage({super.key, required this.recipeId});

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  Recipe? _recipe;
  Category? _category;
  List<Variant> _variants = [];
  List<MediaItem> _mediaItems = [];
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final r = await DatabaseService.instance().getById(widget.recipeId);
      final variants = await DatabaseService.instance().getVariantsByRecipe(widget.recipeId);
      final media = await DatabaseService.instance().getMediaByRecipe(widget.recipeId);
      Category? cat;
      if (r != null && r.categoryId != null) {
        final cats = await DatabaseService.instance().getAllCategories();
        cat = cats.where((c) => c.id == r.categoryId).firstOrNull;
      }
      if (mounted) {
        setState(() {
          _recipe = r;
          _category = cat;
          _variants = variants;
          _mediaItems = media;
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

  Future<void> _edit() async {
    if (_recipe == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecipeEditPage(recipe: _recipe)),
    );
    if (!mounted) return;
    if (result == true) {
      _load();
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_recipe?.name ?? "菜谱详情"),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _edit),
        ],
      ),
      body: _loading
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
                      ElevatedButton(onPressed: _load, child: const Text("重试")),
                    ],
                  ),
                )
              : _recipe == null
                  ? const Center(child: Text("菜谱不存在"))
                  : _detailBody(),
    );
  }

  Widget _detailBody() {
    final r = _recipe!;
    final theme = Provider.of<ThemeManager>(context, listen: false);
    final hasBg = theme.config.bgEnabled && theme.config.backgroundImage != null;
    final cardBg = hasBg ? Colors.white.withOpacity(0.92) : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面图
          if (r.imagePath != null && File(r.imagePath!).existsSync())
            Image.file(File(r.imagePath!), width: double.infinity, height: 240, fit: BoxFit.cover)
          else
            Container(
              width: double.infinity,
              height: 200,
              color: Colors.orange.shade50,
              child: const Icon(Icons.restaurant, size: 64, color: Colors.orange),
            ),
          // 封面媒体
          if (_mediaItems.where((m) => m.section == 'cover').isNotEmpty)
            _buildMediaRow(_mediaItems.where((m) => m.section == 'cover').toList()),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 所属分类
                if (_category != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Chip(
                      avatar: const Icon(Icons.label_outline, size: 16),
                      label: Text('分类：${_category!.name}', style: const TextStyle(fontSize: 13)),
                      backgroundColor: Colors.orange.shade50,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                // 耗时
                if (r.time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('耗时：${r.time}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                // 标签（按 tags 表 sort_order 排序）
                if (r.tagList.isNotEmpty)
                  FutureBuilder<List<String>>(
                    future: DatabaseService.instance().getSortedTags(),
                    builder: (_, snapshot) {
                      final sortedOrder = snapshot.data ?? [];
                      final sortedTags = List<String>.from(r.tagList)
                        ..sort((a, b) {
                          final ai = sortedOrder.indexOf(a);
                          final bi = sortedOrder.indexOf(b);
                          if (ai == -1 && bi == -1) return a.compareTo(b);
                          if (ai == -1) return 1;
                          if (bi == -1) return -1;
                          return ai.compareTo(bi);
                        });
                      return Wrap(
                        spacing: 6,
                        children: sortedTags
                            .map((t) => Chip(
                                  label: Text(t, style: const TextStyle(fontSize: 12)),
                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                  side: BorderSide.none,
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      );
                    },
                  ),
                const SizedBox(height: 12),

                // === 变体列表 ===
                if (_variants.isNotEmpty) ...[
                  _sectionTitle("做法变体", Icons.restaurant_menu),
                  const SizedBox(height: 8),
                  ..._variants.asMap().entries.map((entry) {
                    final v = entry.value;
                    return _variantCard(v, entry.key + 1, cardBg);
                  }),
                  const SizedBox(height: 20),
                ],

                // 更新时间
                Text(
                  "最后更新：${DateFormat("yyyy-MM-dd HH:mm").format(DateTime.fromMillisecondsSinceEpoch(r.updatedAt))}",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _variantCard(Variant v, int index, Color? cardBg) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardBg,
      child: ExpansionTile(
        title: Text(
          "${index}. ${v.name}",
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: v.ingredients.isNotEmpty
            ? Text(v.ingredients.replaceAll('\n', '、'), maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 食材
                if (v.ingredients.trim().isNotEmpty) ...[
                  const Text("食材清单", style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  _textBlock(v.ingredients, cardBg),
                  _buildMediaSection('ingredients_${v.id}'),
                  const SizedBox(height: 12),
                ],
                // 步骤
                if (v.steps.trim().isNotEmpty) ...[
                  const Text("制作步骤", style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  _stepsBlock(v.steps),
                  _buildMediaSection('steps_${v.id}'),
                  const SizedBox(height: 12),
                ],
                // 小贴士
                if (v.tips.trim().isNotEmpty) ...[
                  const Text("小贴士", style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  _textBlock(v.tips, cardBg),
                  _buildMediaSection('tips_${v.id}'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection(String section) {
    final items = _mediaItems.where((m) => m.section == section).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _buildMediaRow(items),
    );
  }

  Widget _buildMediaRow(List<MediaItem> items) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final media = items[i];
          if (!File(media.filePath).existsSync()) return const SizedBox.shrink();
          if (media.type == 'image') {
            return Container(
              width: 100,
              margin: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(media.filePath), fit: BoxFit.cover),
              ),
            );
          } else {
            return Container(
              width: 100,
              margin: const EdgeInsets.only(right: 8),
              child: VideoPlayerWidget(filePath: media.filePath),
            );
          }
        },
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.orange),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _textBlock(String text, Color? bg) {
    if (text.trim().isEmpty) {
      return Text("暂无", style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic));
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg ?? Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14, height: 1.6)),
    );
  }

  Widget _stepsBlock(String steps) {
    if (steps.trim().isEmpty) {
      return Text("暂无", style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic));
    }
    final lines = steps.split("\n").where((e) => e.trim().isNotEmpty).toList();
    return Column(
      children: lines.asMap().entries.map((entry) {
        final idx = entry.key + 1;
        final line = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.orange,
                child: Text("$idx", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(line, style: const TextStyle(fontSize: 14, height: 1.6))),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String filePath;
  const VideoPlayerWidget({super.key, required this.filePath});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath));
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_controller),
          VideoProgressIndicator(_controller, allowScrubbing: true),
          Center(
            child: IconButton(
              icon: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
              color: Colors.white,
              iconSize: 32,
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
