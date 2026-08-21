# 玄灶 - 菜谱管理 App

一个功能丰富的菜谱管理应用，支持分类管理、菜谱变体、随机抽签、数据导入导出等功能。

## 功能特点

- 🍳 **双页面设计**：藏膳（菜谱管理）和卜食（随机抽签）
- 🏷️ **分类管理**：自定义创建、重命名、删除分类
- 📝 **菜谱管理**：支持图片/视频、步骤编辑、多种做法（变体）
- 🔀 **随机抽签**：按分类筛选，设定抽取数量
- 🎨 **主题自定义**：按钮颜色、背景图片、排布布局
- 💾 **数据导入导出**：JSON 格式，支持选择性导入导出
- 🌙 **深色主题**：Material 3 设计语言

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
git clone https://github.com/你的用户名/xuanzao.git
cd xuanzao

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
│   └── settings_page.dart    # 设置页
├── services/
│   ├── database_service.dart # 数据库服务
│   └── theme_manager.dart    # 主题管理
└── utils/
    └── constants.dart        # 常量定义
```

## 开源协议

本项目基于 MIT 协议开源。