import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'pages/draw_page.dart';
import 'services/database_service.dart';
import 'services/theme_manager.dart';

/// 全局刷新通知器 — 保存/删除菜谱后 +1，所有页面监听后重新加载数据
final ValueNotifier<int> globalRefreshNotifier = ValueNotifier<int>(0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeManager = ThemeManager();
  await themeManager.load();
  // 确保数据库就绪 & 默认分类存在
  final db = DatabaseService.instance();
  await db.ensureDefaultCategories();
  // 初始化老标签 sort_order（兼容旧数据）
  await db.initializeTagSortOrder();
  // 初始化老分类 sort_order
  await db.initializeCategorySortOrder();
  runApp(
    ChangeNotifierProvider.value(
      value: themeManager,
      child: const RecipeApp(),
    ),
  );
}

class RecipeApp extends StatelessWidget {
  const RecipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    return MaterialApp(
      title: '玄灶',
      debugShowCheckedModeBanner: false,
      theme: themeManager.themeData,
      home: const MainNavigator(),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;

  // 保持页面实例，通过 ValueNotifier 驱动刷新
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DrawPage(refreshNotifier: globalRefreshNotifier),
      HomePage(refreshNotifier: globalRefreshNotifier),
    ];
  }

  /// 构建全局背景：用户自定义背景图 → 纯色底色回退 → 半透明遮罩
  /// 图片丢失自动回退纯色，不崩溃不空白
  Widget _buildBackground(ThemeManager theme) {
    final bgPath = theme.getBackgroundPath();
    final hasCustomBg = bgPath != null;
    final bgColor = theme.backgroundColor;

    return Stack(
      children: [
        // 第一层：纯色底色（始终存在）
        Positioned.fill(child: Container(color: bgColor)),
        // 第二层：用户自定义背景图（存在时叠加）
        if (hasCustomBg)
          Positioned.fill(
            child: Image.file(
              File(bgPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        // 第三层：半透明遮罩
        Positioned.fill(
          child: Container(color: Colors.white.withOpacity(0.15)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          // 背景图叠加层（默认底纹 + 自定义背景叠加）
          Positioned.fill(
            child: Consumer<ThemeManager>(
              builder: (_, theme, __) => _buildBackground(theme),
            ),
          ),
          // 主页面内容（页面自身 Scaffold 设为透明以透出背景）
          IndexedStack(index: _currentIndex, children: _pages),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.casino_outlined),
            selectedIcon: Icon(Icons.casino),
            label: '卜食',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: '藏膳',
          ),
        ],
      ),
    );
  }
}