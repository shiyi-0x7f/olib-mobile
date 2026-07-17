import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// 阅读统计卡片 — 3 列数值展示
class WereadStatsCard extends StatelessWidget {
  final int totalReadTime;  // 总阅读时长（秒）
  final int readDays;       // 阅读天数
  final int dailyAvg;       // 日均阅读时长（秒）

  const WereadStatsCard({
    super.key,
    required this.totalReadTime,
    required this.readDays,
    required this.dailyAvg,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.accent.withValues(alpha: 0.1),
                ]
              : [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.accent.withValues(alpha: 0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          _buildStatItem(
            context,
            cs,
            Icons.schedule_rounded,
            _formatDuration(totalReadTime),
            t.get('weread_total_read_time'),
            AppColors.primary,
          ),
          _divider(cs),
          _buildStatItem(
            context,
            cs,
            Icons.calendar_today_rounded,
            '$readDays',
            t.get('weread_read_days'),
            AppColors.accent,
          ),
          _divider(cs),
          _buildStatItem(
            context,
            cs,
            Icons.trending_up_rounded,
            _formatDuration(dailyAvg),
            t.get('weread_daily_avg'),
            AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    ColorScheme cs,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme cs) {
    return Container(
      width: 1,
      height: 48,
      color: cs.outlineVariant.withValues(alpha: 0.3),
    );
  }

  /// 秒 → "12.5h" 或 "45min"
  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0';
    final hours = seconds / 3600;
    if (hours >= 1) {
      return '${hours.toStringAsFixed(1)}h';
    }
    final minutes = seconds ~/ 60;
    return '${minutes}min';
  }
}
