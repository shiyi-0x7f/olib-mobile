/// 阅读锦囊 prompt 与结果解析，与 OlibTauri `src-tauri/src/ai_finder/prompt.rs` 保持一致
/// （移植自原 olibai `app/routers/prescribe.py`，仅保留中文）。
library;

import 'dart:convert';

import '../../models/prescription.dart';

/// 解析失败（格式不符），调用方据此重试
class AiFormatException implements Exception {
  final String message;
  const AiFormatException(this.message);
  @override
  String toString() => message;
}

/// 主题快捷入口 → 用户状态描述（与 prescriberThemes 的 id 对应）
const Map<String, String> _themeDescriptions = {
  'relax': '工作压力大，想放松，需要减压',
  'direction': '感到迷茫，想找人生方向',
  'learn': '想系统学习某个领域的知识',
  'bedtime': '睡前想读点轻松的内容',
  'heal': '情感低落，需要治愈和安慰',
  'thinking': '想提升认知能力和思维水平',
};

/// [count]：推荐几本；[extra]：用户补充要求（空 = 无），追加在格式要求之后，不改动 JSON 约定
String buildPrompt(String input, String inputType, int count, String extra) {
  final description = inputType == 'free'
      ? input
      : (_themeDescriptions[input] ?? input);
  final extraTrimmed = extra.trim();
  final extraLine = extraTrimmed.isEmpty
      ? ''
      : '\n- 用户的补充要求（在不违反以上格式的前提下遵守）：$extraTrimmed';
  return '''你是一位资深阅读顾问。用户描述了当前状态："$description"。

请推荐 $count 本最适合的书，严格按以下 JSON 格式返回：
{
  "diagnosis": "一句相关的著名谚语或者名言",
  "tips": [
    {
      "book_name": "书名",
      "author": "作者",
      "reason": "一句推荐理由",
      "category": "分类标签"
    }
  ]
}

要求：
- 只返回 JSON，不要包含其他文字
- tips 数组固定 $count 项
- category 使用简短中文标签（如：治愈、思维、文学、技能、心灵、小说、随笔、管理、哲学、成长、心理、学习）$extraLine''';
}

/// 从模型回复中提取 JSON：去掉推理模型的 `<think>` 段，兼容 markdown 代码块与前后多余文字
Object? extractJson(String raw) {
  var text = raw;
  final thinkEnd = text.lastIndexOf('</think>');
  if (thinkEnd >= 0) text = text.substring(thinkEnd + '</think>'.length);
  text = text.trim();
  try {
    return jsonDecode(text);
  } on FormatException {
    // 代码块或前后夹带说明文字：取第一个 `{` 到最后一个 `}`
  }
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const AiFormatException('AI 返回中没有找到 JSON');
  }
  try {
    return jsonDecode(text.substring(start, end + 1));
  } on FormatException catch (e) {
    throw AiFormatException('AI 返回的不是合法 JSON: ${e.message}');
  }
}

/// 校验并转成 [ReadingBag]；[maxTips]：最多保留几本（模型多给时截断）
ReadingBag validateReadingBag(Object? data, int maxTips) {
  if (data is! Map) throw const AiFormatException('AI 返回的不是 JSON 对象');
  final diagnosis = data['diagnosis'];
  if (diagnosis is! String) throw const AiFormatException('缺少 diagnosis 字段');
  final rawTips = data['tips'];
  if (rawTips is! List) throw const AiFormatException('tips 必须是数组');

  String field(Map t, String k) {
    final v = t[k];
    return v is String ? v : '';
  }

  final tips = rawTips
      .take(maxTips)
      .whereType<Map>()
      .map(
        (t) => ReadingTip(
          bookName: field(t, 'book_name'),
          author: field(t, 'author'),
          reason: field(t, 'reason'),
          category: field(t, 'category'),
        ),
      )
      .where((t) => t.bookName.trim().isNotEmpty)
      .toList();
  if (tips.isEmpty) throw const AiFormatException('tips 为空');
  return ReadingBag(diagnosis: diagnosis, tips: tips);
}
