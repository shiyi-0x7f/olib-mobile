import 'package:flutter/material.dart';
import '../models/feedback.dart';
import '../routes/app_routes.dart';
import '../utils/locale_utils.dart' as locale_utils;

/// 带着出错上下文打开反馈页（类型 / 功能区 / 错误摘要已预填）。
///
/// [errorDetail] 由调用方保证不含密码等敏感字段；这里另外兜底去掉 URL 的查询串
/// （下载直链、接口地址常带签名 / token 参数）。
Future<void> openFeedbackForError(
  BuildContext context, {
  required String area,
  String? summary,
  String? errorDetail,
}) {
  return Navigator.of(context).pushNamed(
    AppRoutes.feedback,
    arguments: FeedbackPrefill(
      area: area,
      summary: summary,
      errorDetail: errorDetail == null ? null : redactUrlQueries(errorDetail),
    ),
  );
}

final _urlQuery = RegExp(r'(https?://[^\s?#]+)[?#]\S*');

/// `https://x.com/dl?key=abc` → `https://x.com/dl?…`
String redactUrlQueries(String s) =>
    s.replaceAllMapped(_urlQuery, (m) => '${m[1]}?…');

/// 出错位置的「反馈此问题」入口，放在重试按钮旁边。
class ReportProblemButton extends StatelessWidget {
  final String area;
  final String? summary;
  final String? errorDetail;

  /// 紧凑样式（列表卡片内），否则为普通文字按钮（整页错误态）。
  final bool dense;

  const ReportProblemButton({
    super.key,
    required this.area,
    this.summary,
    this.errorDetail,
    this.dense = false,
  });

  /// 未指定 [summary] 时按功能区生成一句，如「使用「下载」时出错」。
  String _defaultSummary(bool isZh) {
    final label = findFeedbackOption(feedbackAreas, area)?.label(isZh) ?? area;
    return isZh ? '使用「$label」时出错' : 'Something went wrong in $label';
  }

  @override
  Widget build(BuildContext context) {
    final isZh = locale_utils.isZhLocale(context);
    return TextButton.icon(
      onPressed: () => openFeedbackForError(
        context,
        area: area,
        summary: summary ?? _defaultSummary(isZh),
        errorDetail: errorDetail,
      ),
      style: dense
          ? TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            )
          : null,
      icon: const Icon(Icons.feedback_outlined, size: 18),
      label: Text(isZh ? '反馈此问题' : 'Report'),
    );
  }
}
