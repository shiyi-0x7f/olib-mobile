import 'package:olib_api_plugin/olib_api_plugin.dart';

/// 单条阅读推荐
class ReadingTip {
  final String bookName;
  final String author;
  final String reason; // 推荐理由
  final String category; // 治愈/技能/娱乐
  Book? matchedBook; // z站匹配结果（异步填充）
  bool isSearching; // 是否正在搜索匹配

  ReadingTip({
    required this.bookName,
    required this.author,
    required this.reason,
    required this.category,
    this.matchedBook,
    this.isSearching = false,
  });

  ReadingTip copyWith({
    String? bookName,
    String? author,
    String? reason,
    String? category,
    Book? matchedBook,
    bool? isSearching,
  }) {
    return ReadingTip(
      bookName: bookName ?? this.bookName,
      author: author ?? this.author,
      reason: reason ?? this.reason,
      category: category ?? this.category,
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
