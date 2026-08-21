class AppConstants {
  // SharedPreferences keys
  static const String spKeyApiBaseUrl = "api_base_url";
  static const String spKeyApiModel = "api_model";
  static const String spKeyApiKey = "api_key";
  static const String spKeyThemeConfig = "theme_config";
  static const String spKeyDrawConfig = "draw_config";

  // 默认值（DeepSeek 示例，用户可在设置页改成豆包/其他）
  static const String defaultBaseUrl = "https://api.deepseek.com";
  static const String defaultModel = "deepseek-chat";

  // 默认分类
  static const List<String> defaultTags = [
    "家常菜", "减脂", "甜品", "面食", "肉类", "素菜", "汤品"
  ];

  // 数据库
  static const String dbName = "recipe_app.db";
  static const int dbVersion = 3;

  // 草稿 key 前缀
  static const String spKeyDraftPrefix = "draft_recipe_";
}
