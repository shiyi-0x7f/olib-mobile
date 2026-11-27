import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../models/prescription.dart';
import '../../../theme/app_colors.dart';

class PrescriberResultSection extends StatelessWidget {
  final ReadingBag bag;
  final bool isZh;
  final Animation<double> fadeAnimation;
  final VoidCallback onReset;
  final void Function(ReadingTip tip) onGetBook;

  const PrescriberResultSection({
    super.key,
    required this.bag,
    required this.isZh,
    required this.fadeAnimation,
    required this.onReset,
    required this.onGetBook,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.list(
        children: [
          const SizedBox(height: 4),

          // ── 诊断引用 ───────────────────────────────────
          FadeTransition(
            opacity: fadeAnimation,
            child: _DiagnosisQuote(text: bag.diagnosis),
          ),
          const SizedBox(height: 20),

          // ── 标题 ──────────────────────────────────────
          FadeTransition(
            opacity: fadeAnimation,
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  isZh
                      ? '为你挑了 ${bag.tips.length} 本'
                      : 'Picked ${bag.tips.length} for you',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 书架卡片 ───────────────────────────────────
          ...bag.tips.asMap().entries.map((entry) {
            return FadeTransition(
              opacity: fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BookShelfCard(
                  tip: entry.value,
                  isZh: isZh,
                  onTap: onGetBook,
                ),
              ),
            );
          }),

          const SizedBox(height: 4),

          // ── 再寻一次 ───────────────────────────────────
          FadeTransition(
            opacity: fadeAnimation,
            child: Center(
              child: TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(isZh ? '再寻一次' : 'Try again'),
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Diagnosis quote (left primary bar + italic) ────────────────────

class _DiagnosisQuote extends StatelessWidget {
  final String text;

  const _DiagnosisQuote({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: cs.onSurface,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Book shelf card (cover left + content right) ───────────────────

/// 书架卡：左侧封面缩略图，右侧书名/作者/类别/理由/CTA。
/// - 匹配到的书走 CachedNetworkImage 展示真实封面
/// - 未匹配 / 加载中 走类别色 placeholder + emoji 占位
class _BookShelfCard extends StatelessWidget {
  final ReadingTip tip;
  final bool isZh;
  final void Function(ReadingTip tip) onTap;

  const _BookShelfCard({
    required this.tip,
    required this.isZh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final matched = tip.matchedBook != null;
    final categoryColor = _CategoryStyle.colorFor(tip.category);

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: tip.isSearching ? null : () => onTap(tip),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面（书脊感）
              _BookCover(
                coverUrl: tip.matchedBook?.cover,
                categoryColor: categoryColor,
                isSearching: tip.isSearching,
              ),
              const SizedBox(width: 14),

              // 右侧内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 类别 chip（小、低调，放最上面）
                    if (tip.category.isNotEmpty) ...[
                      _CategoryChip(category: tip.category, color: categoryColor),
                      const SizedBox(height: 6),
                    ],

                    // 书名
                    Text(
                      tip.bookName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tip.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 推荐理由
                    Text(
                      tip.reason,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // CTA
                    _BookCTA(tip: tip, matched: matched, isZh: isZh, onTap: onTap),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Book cover ────────────────────────────────────────────────────

class _BookCover extends StatelessWidget {
  final String? coverUrl;
  final Color categoryColor;
  final bool isSearching;

  const _BookCover({
    required this.coverUrl,
    required this.categoryColor,
    required this.isSearching,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 92,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor.withValues(alpha: 0.18),
            categoryColor.withValues(alpha: 0.10),
          ],
        ),
        // 书脊感：左侧深色边
        border: Border(
          left: BorderSide(color: categoryColor.withValues(alpha: 0.6), width: 3),
        ),
      ),
      alignment: Alignment.center,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isSearching) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: categoryColor,
        ),
      );
    }
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: coverUrl!,
        fit: BoxFit.cover,
        width: 64,
        height: 92,
        memCacheWidth: 200,
        placeholder: (_, __) => _placeholderIcon(),
        errorWidget: (_, __, ___) => _placeholderIcon(),
      );
    }
    return _placeholderIcon();
  }

  Widget _placeholderIcon() {
    return Icon(
      Icons.menu_book_rounded,
      size: 28,
      color: categoryColor.withValues(alpha: 0.6),
    );
  }
}

// ─── Category chip ─────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String category;
  final Color color;

  const _CategoryChip({required this.category, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 10.5,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Category color (by string) ────────────────────────────────────

class _CategoryStyle {
  static Color colorFor(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('治愈') || c.contains('heal') || c.contains('comfort')) {
      return AppColors.success;
    }
    if (c.contains('技能') || c.contains('学') ||
        c.contains('skill') || c.contains('learn')) {
      return AppColors.info;
    }
    if (c.contains('娱乐') || c.contains('放松') ||
        c.contains('relax') || c.contains('fun')) {
      return AppColors.accent;
    }
    return AppColors.primary;
  }
}

// ─── CTA button ────────────────────────────────────────────────────

class _BookCTA extends StatelessWidget {
  final ReadingTip tip;
  final bool matched;
  final bool isZh;
  final void Function(ReadingTip tip) onTap;

  const _BookCTA({
    required this.tip,
    required this.matched,
    required this.isZh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (tip.isSearching) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isZh ? '匹配中…' : 'Searching…',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    final cs = Theme.of(context).colorScheme;
    if (matched) {
      return SizedBox(
        height: 34,
        child: ElevatedButton.icon(
          onPressed: () => onTap(tip),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: Text(
            isZh ? '查看并下载' : 'View & Download',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: () => onTap(tip),
        icon: const Icon(Icons.search_rounded, size: 16),
        label: Text(
          isZh ? '去找这本书' : 'Search for it',
          style: const TextStyle(fontSize: 12.5),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurfaceVariant,
          side: BorderSide(color: cs.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
