import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/feedback.dart';
import '../../providers/backend_auth_provider.dart';
import '../../providers/feedback_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/feedback_api.dart';
import '../../theme/app_colors.dart';
import '../../utils/locale_utils.dart' as locale_utils;
import '../../widgets/gradient_app_bar.dart';
import 'widgets/feedback_form_widgets.dart';

/// 我的反馈：展示处理进度，已修复的标注修复版本。
class MyFeedbackScreen extends ConsumerWidget {
  const MyFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isZh = locale_utils.isZhLocale(context);
    final authorized = ref.watch(backendAuthProvider).isAuthorized;

    return Scaffold(
      appBar: GradientAppBar(title: isZh ? '我的反馈' : 'My feedback'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.pushReplacementNamed(context, AppRoutes.feedback),
        icon: const Icon(Icons.edit_outlined),
        label: Text(isZh ? '写反馈' : 'New'),
      ),
      body: authorized ? _list(context, ref, isZh) : _signIn(context, isZh),
    );
  }

  Widget _signIn(BuildContext context, bool isZh) {
    return _CenterHint(
      icon: Icons.qr_code_2,
      text: isZh ? '扫码登录后查看你提交过的反馈' : 'Sign in to see your feedback',
      action: FilledButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.qrAuth),
        child: Text(isZh ? '微信扫码登录' : 'Sign in with WeChat'),
      ),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, bool isZh) {
    final async = ref.watch(myFeedbackProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FeedbackErrorBanner(
              message: e is FeedbackApiException && e.statusCode == 401
                  ? (isZh
                        ? '登录已失效，请重新扫码'
                        : 'Session expired, please sign in again')
                  : (isZh ? '加载失败' : 'Failed to load'),
              detail: '$e',
              isZh: isZh,
              onDismiss: () => ref.invalidate(myFeedbackProvider),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(myFeedbackProvider),
              child: Text(isZh ? '重试' : 'Retry'),
            ),
          ],
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _CenterHint(
            icon: Icons.inbox_outlined,
            text: isZh ? '还没有提交过反馈' : 'No feedback yet',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(myFeedbackProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _FeedbackCard(item: items[i], isZh: isZh),
          ),
        );
      },
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final MyFeedbackItem item;
  final bool isZh;

  const _FeedbackCard({required this.item, required this.isZh});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = _status();
    final type = findFeedbackOption(feedbackTypes, item.type);
    final area = findFeedbackOption(feedbackAreas, item.area);
    final d = item.createdAt;
    final date =
        '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                type?.label(isZh) ?? item.type,
                area?.label(isZh) ?? item.area,
                'v${item.appVersion}',
                date,
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// 状态文案：所属问题已修复且有版本 → 「已修复于 vX」优先；否则按问题/反馈状态。
  (String, Color) _status() {
    final fixed = item.fixedInVersion;
    if (item.issueStatus == 'fixed' && fixed != null) {
      return (isZh ? '已修复于 v$fixed' : 'Fixed in v$fixed', AppColors.success);
    }
    switch (item.issueStatus) {
      case 'planned':
        return (isZh ? '已排期' : 'Planned', AppColors.info);
      case 'in_progress':
        return (isZh ? '修复中' : 'In progress', AppColors.info);
    }
    return switch (item.status) {
      'new' => (isZh ? '待处理' : 'Received', AppColors.warning),
      'triaged' => (isZh ? '已确认' : 'Confirmed', AppColors.info),
      'resolved' => (isZh ? '已解决' : 'Resolved', AppColors.success),
      'wont_fix' => (isZh ? '暂不处理' : "Won't fix", AppColors.textTertiary),
      _ => (isZh ? '已关闭' : 'Closed', AppColors.textTertiary),
    };
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class _CenterHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _CenterHint({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(text, style: TextStyle(color: cs.onSurfaceVariant)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
