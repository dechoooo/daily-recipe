import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_api_service.dart';
import '../utils/constants.dart';

class AiRecipePage extends StatefulWidget {
  const AiRecipePage({super.key});

  @override
  State<AiRecipePage> createState() => _AiRecipePageState();
}

class _AiRecipePageState extends State<AiRecipePage> {
  final _rawCtrl = TextEditingController();
  AiRecipeResult? _result;
  bool _loading = false;

  Future<void> _runAiParse() async {
    final sp = await SharedPreferences.getInstance();
    final baseUrl = sp.getString(AppConstants.spKeyApiBaseUrl) ?? AppConstants.defaultBaseUrl;
    final model = sp.getString(AppConstants.spKeyApiModel) ?? AppConstants.defaultModel;
    final apiKey = sp.getString(AppConstants.spKeyApiKey) ?? "";

    if (apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("请先去设置页填写 API Key")),
        );
      }
      return;
    }
    if (_rawCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("请先粘贴要整理的菜谱文本")),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await AiApiService.parseRawTextToRecipe(
        baseUrl: baseUrl,
        model: model,
        apiKey: apiKey,
        rawText: _rawCtrl.text,
      );
      setState(() => _result = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("解析失败: $e"), duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fillBack() {
    if (_result == null) return;
    Navigator.pop(context, _result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI整理菜谱")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("粘贴杂乱做菜文本", style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _rawCtrl,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: "把网上复制的菜谱、随手记的文字粘贴在这里",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _runAiParse,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome),
                label: Text(_loading ? "AI整理中..." : "AI整理菜谱"),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(height: 24),
            if (_result != null) ...[
              const Text("AI解析结果", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _resultCard("菜谱名称", _result!.name),
              _resultCard("食材清单", _result!.ingredients),
              _resultCard("制作步骤", _result!.steps),
              _resultCard("小贴士", _result!.tips),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _fillBack,
                  icon: const Icon(Icons.check_circle),
                  label: const Text("使用此结果，去编辑保存"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultCard(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(value.isEmpty ? "（空）" : value, style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
