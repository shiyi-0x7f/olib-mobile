import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/unified_shelf_item.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/book_card.dart';
import '../../../widgets/book_list_tile.dart';

/// 书架网格卡片 — 含正版徽章 + 多选 overlay
class ShelfGridItem extends StatelessWidget {
  final UnifiedShelfItem item;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ShelfGridItem({
    super.key,
    required this.item,
    required this.isSelectMode,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isZLib = item.source == ShelfSource.library;

    return Stack(
      children: [
        BookCard(
          book: item.displayBook,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
        // ── 正版徽章 ──
        if (item.isPurchased) _PurchasedBadge(label: l.get('shelf_purchased_badge')),
        // ── 多选勾选 ──
        if (isSelectMode && isZLib)
          _SelectionCheckmark(
            isSelected: isSelected,
            onTap: onTap,
          ),
      ],
    );
  }
}

/// 书架列表行 — 含正版标志 + 多选 checkbox
class ShelfListItem extends StatelessWidget {
  final UnifiedShelfItem item;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleSelect;

  const ShelfListItem({
    super.key,
    required this.item,
    required this.isSelectMode,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isZLib = item.source == ShelfSource.library;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (isSelectMode && isZLib)
              Checkbox(
                value: isSelected,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                onChanged: onToggleSelect != null ? (_) => onToggleSelect!() : null,
              ),
            if (item.isPurchased)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.verified_rounded,
                    size: 14, color: Colors.amber[700]),
              ),
            Expanded(
              child: BookListTile(
                book: item.displayBook,
                onTap: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 内部组件
// ═══════════════════════════════════════════════════════════════════

class _PurchasedBadge extends StatelessWidget {
  final String label;
  const _PurchasedBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 6,
      left: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded, size: 10, color: Colors.white),
            const SizedBox(width: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionCheckmark extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  const _SelectionCheckmark({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: isSelected
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
