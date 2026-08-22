class AppConstants {
  // SharedPreferences keys
  static const String spKeyThemeConfig = "theme_config";
  static const String spKeyDrawConfig = "draw_config";
  static const String spKeyTagOrder = "tag_order";

  // 默认分类
  static const List<String> defaultTags = [
    "家常菜", "减脂", "甜品", "面食", "肉类", "素菜", "汤品"
  ];

  // 数据库
  static const String dbName = "recipe_app.db";
  static const int dbVersion = 6;

  // 草稿 key 前缀
  static const String spKeyDraftPrefix = "draft_recipe_";
}
