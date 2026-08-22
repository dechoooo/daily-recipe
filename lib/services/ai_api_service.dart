import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// AI 解析结果模型
class AiRecipeResult {
  final String name;
  final String ingredients; // 食材
  final String steps; // 步骤
  final String tips; // 小贴士
  final String time; // 耗时
  final List<String> tags; // 标签
  final String category; // 分类建议

  AiRecipeResult({
    this.name = '',
    this.ingredients = '',
    this.steps = '',
    this.tips = '',
    this.time = '',
    this.tags = const [],
    this.category = '',
  });
}

/// AI 菜谱解析服务
/// 调用 OpenAI 兼容接口将杂乱文本解析为结构化菜谱数据。
/// 修复：SocketException 友好提示、30s 超时、HTTP 错误码展示。
class AiApiService {
  /// 解析原始文本为结构化菜谱
  /// 使用配置的 baseUrl、model、apiKey 调用 OpenAI 兼容接口。
  /// 返回 AiRecipeResult，所有字段不为 null（未命中时为空字符串）。
  static Future<AiRecipeResult> parseRawTextToRecipe({
    required String baseUrl,
    required String model,
    required String apiKey,
    required String rawText,
  }) async {
    final url = baseUrl.trim().endsWith('/')
        ? '${baseUrl.trim()}chat/completions'
        : '${baseUrl.trim()}/chat/completions';

    final prompt = '''
你是一个专业的菜谱整理助手。请将用户输入的杂乱做菜文本整理成结构化的菜谱数据。

【数据格式要求】
请严格按照以下 JSON 格式输出，不要包含任何额外的说明文字：

{
  "name": "菜名",
  "category": "分类（如：家常菜、减脂、甜品、面食等）",
  "tags": ["标签1", "标签2"],
  "ingredients": "食材清单，每条一行",
  "steps": "制作步骤，每条一行，带序号",
  "tips": "小贴士/注意事项",
  "time": "耗时文本（如：30分钟）"
}

【注意事项】
- 如果用户输入的文本中没有明确告知分类，请根据菜品的类型合理推断并填入 category 字段
- tags 为选填，可以为空数组
- 所有字段必须为字符串类型（tags 除外）
- 确保 JSON 格式严格正确，无多余字符
''';

    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': prompt},
        {'role': 'user', 'content': rawText},
      ],
      'temperature': 0.3,
      'max_tokens': 2000,
    });

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30)
        ..idleTimeout = const Duration(seconds: 30);

      // 解析 baseUrl 判断是否 HTTPS
      final uri = Uri.parse(url);
      final request = await client.postUrl(uri);

      // 设置请求头
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $apiKey');

      // 写入请求体
      request.write(body);

      // 发送请求并获取响应
      final response = await request.close();

      // 检查 HTTP 状态码
      if (response.statusCode != 200) {
        final errorBody = await response.transform(utf8.decoder).join();
        String errorMsg;
        try {
          final errorJson = jsonDecode(errorBody);
          errorMsg = errorJson['error']?['message'] ?? errorBody;
        } catch (_) {
          errorMsg = errorBody;
        }

        switch (response.statusCode) {
          case 401:
          case 403:
            throw AiApiException('API Key 认证失败，请检查设置页的 API Key 是否正确');
          case 404:
            throw AiApiException('接口地址不正确，请检查 Base URL 配置');
          case 429:
            throw AiApiException('请求过于频繁，请稍后再试');
          case 500:
          case 502:
          case 503:
            throw AiApiException('AI 服务暂时不可用，请稍后重试');
          default:
            throw AiApiException('AI 接口返回错误 ($response.statusCode): $errorMsg');
        }
      }

      // 解析响应
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final content = decoded['choices']?[0]?['message']?['content'] as String? ?? '';

      if (content.isEmpty) {
        throw AiApiException('AI 返回内容为空，请重试');
      }

      // 提取 JSON 内容（可能被 markdown 包裹）
      final jsonStr = _extractJson(content);
      if (jsonStr == null) {
        throw AiApiException('AI 返回格式异常，无法解析，请重试');
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      return AiRecipeResult(
        name: data['name'] as String? ?? '',
        ingredients: data['ingredients'] as String? ?? '',
        steps: data['steps'] as String? ?? '',
        tips: data['tips'] as String? ?? '',
        time: data['time'] as String? ?? '',
        tags: (data['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        category: data['category'] as String? ?? '',
      );
    } on SocketException catch (e) {
      // 域名解析失败 / 网络不可达
      if (e.osError?.errorCode == 7 || e.osError?.errorCode == 8) {
        throw AiApiException('网络连接失败，请检查网络和 API Base URL 地址是否正确');
      }
      throw AiApiException('网络连接异常: ${e.message}');
    } on HttpException catch (e) {
      throw AiApiException('HTTP 请求异常: ${e.message}');
    } on FormatException {
      throw AiApiException('AI 返回数据格式错误，请重试');
    } on TimeoutException {
      throw AiApiException('请求超时，请检查网络或稍后重试');
    } catch (e) {
      final msg = e.toString();
      // 统一友好提示
      if (msg.contains('SocketException') || msg.contains('Connection refused')) {
        throw AiApiException('无法连接到 AI 服务，请检查网络和 API 地址');
      }
      // 透传自定义异常
      if (e is AiApiException) rethrow;
      throw AiApiException('AI 解析失败: $msg');
    }
  }

  /// 从 AI 响应文本中提取 JSON 对象
  /// 兼容 markdown 代码块包裹的情况
  static String? _extractJson(String text) {
    // 尝试匹配 ```json ... ``` 代码块
    final codeBlock = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (codeBlock != null) {
      return codeBlock.group(1)?.trim();
    }
    // 直接尝试查找 { ... }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return null;
  }
}

/// AI 自定义异常，用于友好提示
class AiApiException implements Exception {
  final String message;
  AiApiException(this.message);

  @override
  String toString() => message;
}