import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/weread_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../weread/weread_reading_report_screen.dart';

/// 首页搜索框下的一排快捷功能，让藏在二三级页面的能力一眼可见。
///
/// 新增快捷功能只需往 [build] 的列表里追加一项。
class HomeQuickActions extends ConsumerWidget {
  /// AI 寻书入口（含授权校验，由首页提供）。
  final VoidCallback onOpenPrescriber;

  const HomeQuickActions({super.key, required this.onOpenPrescriber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final nav = Navigator.of(context);

    void openReport() {
      // 没连微信读书时进微信读书页，那里有连接引导
      final connected = ref.read(wereadConnectionProvider).valueOrNull == true;
      if (connected) {
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => const WereadReadingReportScreen(),
          ),
        );
      } else {
        nav.pushNamed(AppRoutes.wereadHome);
      }
    }

    final items = [
      _QuickAction(
        Icons.auto_awesome,
        t.get('home_quick_ai'),
        onOpenPrescriber,
        highlight: true,
      ),
      _QuickAction(
        Icons.laptop_chromebook_rounded,
        t.get('desktop_link_title'),
        () => nav.pushNamed(AppRoutes.desktopLink),
      ),
      _QuickAction(
        Icons.insights_rounded,
        t.get('home_quick_report'),
        openReport,
      ),
      _QuickAction(
        Icons.feedback_outlined,
        t.get('home_quick_feedback'),
        () => nav.pushNamed(AppRoutes.feedback),
      ),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _QuickActionTile(item)),
          ],
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  const _QuickAction(
    this.icon,
    this.label,
    this.onTap, {
    this.highlight = false,
  });
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;

  const _QuickActionTile(this.action);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hl = action.highlight;
    final fg = hl ? Colors.white : cs.primary;
    return Material(
      color: hl ? AppColors.primary : cs.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: hl ? 3 : 0,
      shadowColor: AppColors.primary.withValues(alpha: 0.4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: action.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          decoration: hl
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant),
                ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: fg, size: 24),
              const SizedBox(height: 6),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hl ? Colors.white : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
