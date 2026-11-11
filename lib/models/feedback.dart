/// SCC 统一反馈（`/api/v1/client/feedback`）的客户端模型与选项表。
///
/// 枚举值与 SCC `app/schemas/feedback.py` 一一对应；area 为本应用自维护的固定功能区列表。
/// 契约见 `dev_docs/refs/software_control_center.md`。
library;

import 'package:flutter/material.dart';

/// 一个可选项：提交给 SCC 的 [value] + 中英文展示文案 + 图标。
class FeedbackOption {
  final String value;
  final String zh;
  final String en;
  final IconData icon;

  /// 选项下方的一句提示（可选），帮用户判断该选哪个。
  final String? hintZh;
  final String? hintEn;

  const FeedbackOption(
    this.value,
    this.zh,
    this.en,
    this.icon, {
    this.hintZh,
    this.hintEn,
  });

  String label(bool isZh) => isZh ? zh : en;
  String? hint(bool isZh) => isZh ? hintZh : hintEn;
}

/// 反馈类型（SCC FeedbackType）。
const feedbackTypes = <FeedbackOption>[
  FeedbackOption('bug', '功能异常', 'Bug', Icons.bug_report_outlined),
  FeedbackOption('crash', '闪退崩溃', 'Crash', Icons.error_outline),
  FeedbackOption('performance', '卡顿缓慢', 'Slow', Icons.speed_outlined),
  FeedbackOption('ux', '界面体验', 'UI / UX', Icons.palette_outlined),
  FeedbackOption('feature', '功能建议', 'Suggestion', Icons.lightbulb_outline),
  FeedbackOption('other', '其他', 'Other', Icons.more_horiz),
];

/// 需要展示「影响程度」与「复现步骤」的类型（问题类）。
const feedbackProblemTypes = {'bug', 'crash', 'performance'};

/// 功能区（SCC area slug，小写 `[a-z0-9_-]`）。新增功能区只在此追加，勿改已有 value。
const feedbackAreas = <FeedbackOption>[
  FeedbackOption('search', '搜索找书', 'Search', Icons.search),
  FeedbackOption(
    'book_detail',
    '书籍详情',
    'Book details',
    Icons.menu_book_outlined,
  ),
  FeedbackOption('download', '下载', 'Download', Icons.download_outlined),
  FeedbackOption('reader', '阅读器', 'Reader', Icons.chrome_reader_mode_outlined),
  FeedbackOption('shelf', '书架收藏', 'Shelf', Icons.bookmarks_outlined),
  FeedbackOption(
    'ai_prescriber',
    'AI 寻书',
    'AI finder',
    Icons.auto_awesome_outlined,
  ),
  FeedbackOption('weread', '微信读书', 'WeRead', Icons.chat_bubble_outline),
  FeedbackOption('account', '登录账号', 'Account', Icons.person_outline),
  FeedbackOption('other', '其他', 'Other', Icons.more_horiz),
];

/// 影响程度（SCC FeedbackSeverity），文案按用户感知写。
const feedbackSeverities = <FeedbackOption>[
  FeedbackOption(
    'minor',
    '小问题',
    'Minor',
    Icons.sentiment_neutral,
    hintZh: '有点别扭，但不影响使用',
    hintEn: 'Annoying but usable',
  ),
  FeedbackOption(
    'major',
    '影响使用',
    'Major',
    Icons.sentiment_dissatisfied,
    hintZh: '部分功能没法正常用',
    hintEn: 'Part of the app is broken',
  ),
  FeedbackOption(
    'blocker',
    '完全用不了',
    'Blocker',
    Icons.block,
    hintZh: '核心功能无法使用',
    hintEn: 'Cannot use the app at all',
  ),
];

/// 从出错位置跳进反馈页时的预填内容（`AppRoutes.feedback` 的路由参数）。
///
/// [area] 须取自 [feedbackAreas] 的 value；[errorDetail] 为已脱敏的错误摘要，
/// 预填进「实际结果」，用户补一句描述即可提交。
class FeedbackPrefill {
  final String type;
  final String area;
  final String? summary;
  final String? errorDetail;

  const FeedbackPrefill({
    this.type = 'bug',
    required this.area,
    this.summary,
    this.errorDetail,
  });
}

FeedbackOption? findFeedbackOption(List<FeedbackOption> options, String value) {
  for (final o in options) {
    if (o.value == value) return o;
  }
  return null;
}

/// `GET /client/feedback/mine` 的一项。
class MyFeedbackItem {
  final int id;
  final String type;
  final String area;
  final String title;
  final String status;
  final String appVersion;
  final DateTime createdAt;
  final String? issueStatus;
  final String? fixedInVersion;

  const MyFeedbackItem({
    required this.id,
    required this.type,
    required this.area,
    required this.title,
    required this.status,
    required this.appVersion,
    required this.createdAt,
    this.issueStatus,
    this.fixedInVersion,
  });

  factory MyFeedbackItem.fromJson(Map<String, dynamic> json) {
    return MyFeedbackItem(
      id: json['id'] as int,
      type: json['type'] as String,
      area: json['area'] as String,
      title: json['title'] as String,
      status: json['status'] as String,
      appVersion: json['app_version'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      issueStatus: json['issue_status'] as String?,
      fixedInVersion: json['fixed_in_version'] as String?,
    );
  }
}

/// 设备诊断信息（「所见即所发」：表单展示的就是要发送的值）。
class DeviceDiagnostics {
  /// SCC platform 枚举值；当前平台不在 SCC 支持列表（如 Linux）时为 null。
  final String? platform;
  final String? deviceModel;
  final String? osVersion;
  final String appVersion;

  const DeviceDiagnostics({
    required this.platform,
    required this.deviceModel,
    required this.osVersion,
    required this.appVersion,
  });

  /// 勾选框旁展示的摘要，如 `Xiaomi 23127PN0CC · Android 15`。
  String get summary => [
    deviceModel,
    osVersion,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
}
