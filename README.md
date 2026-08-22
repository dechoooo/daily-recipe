# 玄灶 - 菜谱管理

一个功能丰富的菜谱管理应用，支持分类管理、菜谱变体、随机抽签（卜食/卜材）、数据导入导出、全局背景自定义等功能。

> ⚠️ **注意**：目前仅支持 Android 平台。

## 功能特点

### 📋 菜谱管理（藏膳）
- 🏷️ **分类管理**：自定义创建、重命名、删除分类，支持拖拽排序
- 📝 **菜谱管理**：支持图片/视频、步骤编辑、多种做法（变体）
- 🔀 **变体系统**：同一菜谱可保存多种做法版本
- 🔍 **筛选检索**：按分类、标签快速筛选菜谱

### 🎲 随机抽签（卜食）
- 🥘 **卜膳**：按分类筛选随机抽取菜谱
- 🥬 **卜材**：输入手头食材，检索可制作菜式
- 🔢 **自定义数量**：支持按需求设置抽取/检索数量

### 🎨 个性化
- 🖼️ **全局背景**：相册导入图片设为全局背景，清除恢复纯色底色（文件异常自动降级）
- 🎭 **主题色**：支持自定义主题颜色
- 🌙 **深色主题**：Material 3 设计语言

### 💾 数据管理
- 📤 **导入导出**：JSON 格式，支持分类排序、标签排序等完整数据
- 📎 **系统分享**：支持通过系统分享导出数据文件
- 🔄 **数据迁移**：自动处理数据库版本升级

## 版本历史

### v1.3.0（当前版本）
**✨ 新增功能**
- 新增卜材模式：卜食扩展为卜膳、卜材双 Tab。卜膳随机抽签选菜谱；卜材输入手头食材，检索可以制作的菜式
- 菜谱分类拖拽排序：category 分类支持长按拖拽调整展示顺序；排序同步作用于藏膳顶部筛选栏、卜食配置弹窗；数据持久化保存
- 导入导出增强：JSON 导入导出支持分类排序数据，支持自定义分享
- 全局自定义背景：相册导入图片作为全局背景，清除可恢复纯色底色，文件异常自动降级

**🐛 Bug 修复**
- 全局背景图修复：修复设置保存背景图后页面不生效问题，全页面共用背景组件，图片持久化存储
- AI 相关功能修复：修复本地 AI 调用相关异常
- UI 残留泄漏修复：打开弹窗时左下角多余黑框悬浮提示问题修复

### v1.0.0（初始版本）
- 双页面设计：藏膳（菜谱管理）和卜食（随机抽签）
- 菜谱分类、标签管理
- 菜谱增删改查，支持图片、视频、步骤编辑
- 卜食随机抽签功能
- 数据导入导出（JSON 格式）
- 主题自定义（按钮颜色、布局排布）
- 分类管理

## 技术栈

- **框架**: Flutter 3.47.1
- **语言**: Dart
- **数据库**: SQLite (sqflite)
- **状态管理**: Provider
- **最低 SDK**: Android 5.0 (API 21)
- **目标 SDK**: Android 14 (API 34)

## 截图

<!-- 截图待添加 -->

## 快速开始

### 环境要求

- Flutter SDK 3.x
- Android Studio 或 VS Code
- Android SDK 34+

### 安装

```bash
# 克隆项目
git clone https://github.com/dechoooo/daily-recipe.git
cd daily-recipe

# 安装依赖
flutter pub get

# 运行
flutter run
```

### 构建 APK

```bash
# 构建 release APK
flutter build apk --release --target-platform android-arm64
```

## 项目结构

```
lib/
├── main.dart                 # 入口文件
├── models/
│   ├── recipe.dart           # 菜谱模型
│   ├── category.dart         # 分类模型
│   ├── variant.dart          # 变体模型
│   └── media_item.dart       # 媒体文件模型
├── pages/
│   ├── home_page.dart        # 藏膳页（菜谱列表）
│   ├── draw_page.dart        # 卜食页（随机抽签）
│   ├── recipe_edit_page.dart # 菜谱编辑
│   ├── recipe_detail_page.dart # 菜谱详情
│   ├── ai_recipe_page.dart   # AI 菜谱页
│   └── settings_page.dart    # 设置页
├── services/
│   ├── database_service.dart # 数据库服务
│   ├── theme_manager.dart    # 主题管理
│   └── ai_api_service.dart   # AI API 服务
└── utils/
    └── constants.dart        # 常量定义
```

## 开源协议

本项目基于 MIT 协议开源。