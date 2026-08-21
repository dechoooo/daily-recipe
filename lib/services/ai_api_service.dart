import 'dart:convert';
import 'package:http/http.dart' as http;

class AiRecipeResult {
  String name;
  String ingredients;
  String steps;
  String tips;
  AiRecipeResult({
    required this.name,
    required this.ingredients,
    required this.steps,
    required this.tips,
  });
}

/// 通用 OpenAI 兼容接口服务
/// 支持：DeepSeek、豆包(火山方舟)、智谱、通义、Moonshot、OpenAI 等
class AiApiService {
  static Future<AiRecipeResult?> parseRawTextToRecipe({
    required String baseUrl,
    required String model,
    required String apiKey,
    required String rawText,
  }) async {
    if (apiKey.isEmpty || baseUrl.isEmpty || model.isEmpty) return null;

    String endpoint = _buildEndpoint(baseUrl);
    final url = Uri.parse(endpoint);

    const prompt = '''
你是菜谱整理助手，请把用户粘贴的杂乱做菜文字整理成 JSON，不要多余解释。
输出字段：
{"name":"菜谱名称","ingredients":"食材清单，每条换行","steps":"制作步骤，每条换行","tips":"小贴士/备注"}
用户原始文本：
''';

    final resp = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": model,
        "messages": [
          {"role": "user", "content": prompt + rawText}
        ],
        "temperature": 0.4,
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception("API 请求失败: HTTP ${resp.statusCode}\n${resp.body}");
    }

    final body = jsonDecode(resp.body);
    String content = body["choices"][0]["message"]["content"];
    final jsonStr = content
        .replaceAll("```json", "")
        .replaceAll("```", "")
        .trim();
    final j = jsonDecode(jsonStr);
    return AiRecipeResult(
      name: j["name"] ?? "",
      ingredients: j["ingredients"] ?? "",
      steps: j["steps"] ?? "",
      tips: j["tips"] ?? "",
    );
  }

  /// 根据 baseUrl 智能拼接 chat/completions 路径
  /// 自动识别已带版本号（/v1 /v3 /v4 等）的 baseUrl，避免重复拼接
  static String _buildEndpoint(String baseUrl) {
    String b = baseUrl.trim();
    // 去掉末尾斜杠
    while (b.endsWith("/")) {
      b = b.substring(0, b.length - 1);
    }
    // 已经是完整端点，直接返回
    if (b.endsWith("/chat/completions")) return b;
    // 路径已带版本号（如 /v1、/v3、/v4），直接拼 chat/completions
    if (RegExp(r'/v\d+$').hasMatch(b)) {
      return "$b/chat/completions";
    }
    // 否则默认拼 v1/chat/completions（如 DeepSeek 的 https://api.deepseek.com）
    return "$b/v1/chat/completions";
  }
}
