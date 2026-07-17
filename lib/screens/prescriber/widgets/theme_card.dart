import 'package:flutter/material.dart';

/// 紧凑型主题卡：emoji 大占据上半，短标签居中。
/// 设计目标：3 列网格 ~110dp 宽度下不会溢出，emoji 居于视觉中心。
class ThemeCard extends StatelessWidget {
  final String emoji;
  final String shortLabel;
  final String tooltip;
  final VoidCallback onTap;
  final Color tint;

  const ThemeCard({
    super.key,
    required this.emoji,
    required this.shortLabel,
    required this.tooltip,
    required this.onTap,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tint.withValues(alpha: isDark ? 0.18 : 0.10),
                  tint.withValues(alpha: isDark ? 0.10 : 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: tint.withValues(alpha: isDark ? 0.30 : 0.18),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  shortLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
