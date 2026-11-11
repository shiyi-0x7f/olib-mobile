import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/unified_shelf_item.dart';
import '../../../theme/app_colors.dart';

/// 封面 + 书名/作者的网格卡片，与首页、搜索页的卡片语言保持一致。
class ShelfGridItem extends StatelessWidget {
  const ShelfGridItem({
    super.key,
    required this.item,
    required this.isSelectMode,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.categoryName,
    this.isDownloaded = false,
  });

  /// 封面宽高比（宽 / 高）。
  static const coverAspectRatio = 0.7;

  /// 封面下方书名 + 作者区域的高度。
  static const captionHeight = 48.0;

  final UnifiedShelfItem item;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? categoryName;
  final bool isDownloaded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final book = item.displayBook;
    final selectable = isSelectMode && item.source == ShelfSource.library;
    final selected = selectable && isSelected;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: coverAspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ShelfCover(
                  key: ValueKey(item.categoryKey),
                  title: book.title,
                  cover: book.cover,
                  selected: selected,
                ),
                if (categoryName != null)
                  Positioned(
                    left: 6,
                    top: 6,
                    right: 30,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: _CoverPill(text: categoryName!),
                    ),
                  ),
                if (isDownloaded)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _CircleBadge(
                      color: AppColors.primary,
                      child: const Icon(
                        Icons.download_done_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (selectable)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: _SelectMark(selected: selected),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: captionHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 7, 2, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  if (book.author?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      book.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 列表模式的卡片行，样式对齐下载页。
class ShelfListItem extends StatelessWidget {
  const ShelfListItem({
    super.key,
    required this.item,
    required this.isSelectMode,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.categoryName,
    this.isDownloaded = false,
  });

  final UnifiedShelfItem item;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? categoryName;
  final bool isDownloaded;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final book = item.displayBook;
    final badges = <({IconData? icon, String text, bool highlighted})>[
      if (categoryName != null)
        (
          icon: Icons.label_outline_rounded,
          text: categoryName!,
          highlighted: true,
        ),
      if (book.tag?.isNotEmpty == true)
        (icon: null, text: book.tag!, highlighted: false),
      if (book.tagExtra?.isNotEmpty == true)
        (icon: null, text: book.tagExtra!, highlighted: false),
      if (book.meta?.isNotEmpty == true)
        (icon: null, text: book.meta!, highlighted: false),
      if (book.score?.isNotEmpty == true && book.tagExtra != book.score)
        (icon: Icons.star_rounded, text: book.score!, highlighted: false),
      if (item.isPersonalImport)
        (
          icon: Icons.person_outline_rounded,
          text: l.get('shelf_personal_import'),
          highlighted: false,
        ),
      if (isDownloaded)
        (
          icon: Icons.download_done_rounded,
          text: l.get('shelf_downloaded'),
          highlighted: true,
        ),
    ];
    final selectable = isSelectMode && item.source == ShelfSource.library;
    final selected = selectable && isSelected;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? BorderSide(color: cs.primary, width: 1.5)
            : theme.brightness == Brightness.dark
            ? BorderSide(color: cs.outlineVariant)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                height: 78,
                child: _ShelfCover(
                  key: ValueKey('list-${item.categoryKey}'),
                  title: book.title,
                  cover: book.cover,
                  selected: false,
                  radius: 8,
                  compact: true,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (book.author?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        book.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < badges.length; i++) ...[
                              if (i > 0) const SizedBox(width: 5),
                              _ListBadge(
                                icon: badges[i].icon,
                                text: badges[i].text,
                                highlighted: badges[i].highlighted,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selectable)
                _SelectMark(selected: selected)
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 圆角封面：带柔和阴影，无封面时用主色渐变 + 书名兜底（同首页卡片）。
class _ShelfCover extends StatelessWidget {
  const _ShelfCover({
    super.key,
    required this.title,
    required this.cover,
    required this.selected,
    this.radius = 10,
    this.compact = false,
  });

  final String title;
  final String? cover;
  final bool selected;
  final double radius;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(radius);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cacheWidth =
            (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .ceil();
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: selected ? Border.all(color: cs.primary, width: 2.5) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.3 : 0.1),
                blurRadius: compact ? 6 : 12,
                offset: Offset(0, compact ? 2 : 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: cover?.isNotEmpty == true
                ? CachedNetworkImage(
                    imageUrl: cover!,
                    fit: BoxFit.cover,
                    memCacheWidth: cacheWidth > 0 ? cacheWidth : null,
                    fadeInDuration: const Duration(milliseconds: 250),
                    placeholder: (_, __) => _fallback(dark),
                    errorWidget: (_, __, ___) => _fallback(dark),
                  )
                : _fallback(dark),
          ),
        );
      },
    );
  }

  Widget _fallback(bool dark) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? [
                AppColors.primary.withValues(alpha: 0.45),
                AppColors.primary.withValues(alpha: 0.2),
              ]
            : [
                AppColors.primary.withValues(alpha: 0.85),
                AppColors.primary.withValues(alpha: 0.6),
              ],
      ),
    ),
    child: Padding(
      padding: EdgeInsets.all(compact ? 5 : 10),
      child: Center(
        child: compact
            ? Icon(
                Icons.auto_stories_rounded,
                size: 22,
                color: Colors.white.withValues(alpha: 0.8),
              )
            : Text(
                title,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
      ),
    ),
  );
}

class _CoverPill extends StatelessWidget {
  const _CoverPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class _CircleBadge extends StatelessWidget {
  const _CircleBadge({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 多选模式下的勾选标记：选中为主色实心勾，未选中为半透明空心圈。
class _SelectMark extends StatelessWidget {
  const _SelectMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: selected
          ? _CircleBadge(
              key: const ValueKey(true),
              color: cs.primary,
              child: Icon(Icons.check_rounded, size: 14, color: cs.onPrimary),
            )
          : _CircleBadge(
              key: const ValueKey(false),
              color: Colors.black.withValues(alpha: 0.25),
              child: const SizedBox.shrink(),
            ),
    );
  }
}

class _ListBadge extends StatelessWidget {
  const _ListBadge({required this.text, this.icon, this.highlighted = false});

  final String text;
  final IconData? icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foreground = highlighted ? cs.primary : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: highlighted ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontSize: 10,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
