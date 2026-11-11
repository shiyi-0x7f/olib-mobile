import 'package:olib_api_plugin/olib_api_plugin.dart';

/// 单条阅读推荐
class ReadingTip {
  final String bookName;
  final String author;
  final String reason; // 推荐理由
  final String category; // 治愈/技能/娱乐
  /// 后端标识：true = AI 寻书结果，下载走 backend /books/download-url
  /// （受免费下载配额限制）；false = 普通来源，下载走用户自己的 API。
  /// 后端 prescribe 永远返 true；如果将来从别处构造 Tip 应显式设 false。
  final bool fromAi;
  Book? matchedBook; // z站匹配结果（异步填充）
  bool isSearching; // 是否正在搜索匹配

  ReadingTip({
    required this.bookName,
    required this.author,
    required this.reason,
    required this.category,
    this.fromAi = false,
    this.matchedBook,
    this.isSearching = false,
  });

  /// 从后端 JSON 解析
  factory ReadingTip.fromJson(Map<String, dynamic> json) {
    return ReadingTip(
      bookName: json['book_name'] as String? ?? '',
      author: json['author'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      category: json['category'] as String? ?? '',
      // 后端 prescribe 总是带 from_ai=true；防 null 兜底为 false 更安全
      fromAi: json['from_ai'] as bool? ?? false,
    );
  }

  ReadingTip copyWith({
    String? bookName,
    String? author,
    String? reason,
    String? category,
    bool? fromAi,
    Book? matchedBook,
    bool? isSearching,
  }) {
    return ReadingTip(
      bookName: bookName ?? this.bookName,
      author: author ?? this.author,
      reason: reason ?? this.reason,
      category: category ?? this.category,
      fromAi: fromAi ?? this.fromAi,
      matchedBook: matchedBook ?? this.matchedBook,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

/// 阅读锦囊（包含诊断语 + 推荐列表）
class ReadingBag {
  final String diagnosis; // 诊断语/总结
  final List<ReadingTip> tips; // 推荐书目

  ReadingBag({
    required this.diagnosis,
    required this.tips,
  });

  /// 从后端 JSON 解析
  factory ReadingBag.fromJson(Map<String, dynamic> json) {
    final tipsJson = json['tips'] as List<dynamic>? ?? [];
    return ReadingBag(
      diagnosis: json['diagnosis'] as String? ?? '',
      tips: tipsJson
          .map((t) => ReadingTip.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }

  ReadingBag copyWith({
    String? diagnosis,
    List<ReadingTip>? tips,
  }) {
    return ReadingBag(
      diagnosis: diagnosis ?? this.diagnosis,
      tips: tips ?? this.tips,
    );
  }
}

/// 预设主题
class PrescriberTheme {
  final String id;
  final String emoji;
  final String labelZh;
  final String labelEn;

  const PrescriberTheme({
    required this.id,
    required this.emoji,
    required this.labelZh,
    required this.labelEn,
  });
}

/// 预设主题列表
const List<PrescriberTheme> prescriberThemes = [
  PrescriberTheme(
    id: 'relax',
    emoji: '😮‍💨',
    labelZh: '工作压力大，想放松',
    labelEn: 'Stressed, need to unwind',
  ),
  PrescriberTheme(
    id: 'direction',
    emoji: '🤔',
    labelZh: '感到迷茫，想找方向',
    labelEn: 'Feeling lost, seeking direction',
  ),
  PrescriberTheme(
    id: 'learn',
    emoji: '📈',
    labelZh: '想系统学习某个领域',
    labelEn: 'Want to learn a new skill',
  ),
  PrescriberTheme(
    id: 'bedtime',
    emoji: '💤',
    labelZh: '睡前想读点轻松的',
    labelEn: 'Light bedtime reading',
  ),
  PrescriberTheme(
    id: 'heal',
    emoji: '💔',
    labelZh: '情感低落，需要治愈',
    labelEn: 'Emotionally down, need comfort',
  ),
  PrescriberTheme(
    id: 'thinking',
    emoji: '🎯',
    labelZh: '想提升认知和思维',
    labelEn: 'Sharpen my thinking',
  ),
];
