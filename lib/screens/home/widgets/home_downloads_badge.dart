import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// 首页名字下方的「今日剩 N 次」小标签；用完时变为警示色。
class HomeDownloadsBadge extends StatelessWidget {
  final int left;

  const HomeDownloadsBadge({super.key, required this.left});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = left > 0 ? cs.primary : cs.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.download_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)
                .get('downloads_left_short')
                .replaceAll('%d', '${left < 0 ? 0 : left}'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
