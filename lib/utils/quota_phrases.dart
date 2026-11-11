import 'dart:math';

/// 配额耗尽提示文案库 — 用文学化措辞代替"免费/配额/社群"等商业词。
/// 调用方按场景选 list，调 [randomPhrase] 拿一句展示。
class QuotaPhrases {
  QuotaPhrases._();

  /// AI 调用配额耗尽
  static const List<String> aiQuota = [
    '书籍是人类进步的阶梯，明天再来登一级。',
    'AI 也需要休息，明天它会以更好的状态等你。',
    '一日不读书，胸臆无佳想。今日已尽，明日再续。',
    '今日的思绪已抵达终点，明日再启航。',
    '探索的脚步暂停一下，明天继续翻开新的一页。',
  ];

  /// AI 调用全局预算熔断（多人共用时偶发）
  static const List<String> aiGlobal = [
    '今日的书海格外热闹，明天清晨再来探索吧。',
    '众人皆在阅读，AI 略感繁忙。明日相见。',
    '今日的探索者太多，请将精彩留到明天。',
  ];

  /// AI 寻书结果的免费下载额度耗尽
  static const List<String> downloadQuota = [
    '今日已遇见好书，让它们慢慢陪你。明日再来寻新书。',
    '书海无涯，今日已得其精华，明日再相会。',
    '愿你已收到今日的礼物，明天还有新书在路上。',
    '阅读如品茶，今日已斟满，明天再续一盏。',
    '好书需要时间消化，今日所得已足，明日再寻。',
  ];

  /// 从 list 里随机抽一句
  static String randomFrom(List<String> phrases) {
    if (phrases.isEmpty) return '';
    return phrases[Random().nextInt(phrases.length)];
  }
}
