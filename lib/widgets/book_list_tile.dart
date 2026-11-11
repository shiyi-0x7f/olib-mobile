import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/display_book.dart';
import '../theme/app_colors.dart';

/// Compact list tile for books.
class BookListTile extends StatelessWidget {
  final DisplayBook book;
  final VoidCallback? onTap;
  final bool showCover;
  final Widget? trailing;
  final String? extraLabel;

  const BookListTile({
    super.key,
    required this.book,
    this.onTap,
    this.showCover = false,
    this.trailing,
    this.extraLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: showCover
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 48,
                  height: 68,
                  child: book.cover != null && book.cover!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: book.cover!,
                          fit: BoxFit.cover,
                          memCacheWidth:
                              (48 * MediaQuery.devicePixelRatioOf(context))
                                  .ceil(),
                          placeholder: (context, url) => _coverPlaceholder(cs),
                          errorWidget: (context, url, error) =>
                              _coverPlaceholder(cs),
                        )
                      : _coverPlaceholder(cs),
                ),
              )
            : Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: cs.primary,
                  size: 22,
                ),
              ),
        title: Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.author != null && book.author!.isNotEmpty)
              Text(
                book.author!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (extraLabel != null && extraLabel!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                extraLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.primary),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                // Tag badge (format/category)
                if (book.tag != null && book.tag!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      book.tag!,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (book.tag != null && book.meta != null)
                  const SizedBox(width: 8),
                // Meta info
                if (book.meta != null)
                  Text(
                    book.meta!,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                const Spacer(),
                // Year or other extra detail; search results keep rating in score.
                if (book.tagExtra != null && book.tagExtra!.isNotEmpty)
                  Text(
                    book.tagExtra!,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                if ((book.tagExtra == null || book.tagExtra!.isEmpty) &&
                    book.score != null &&
                    book.score!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        book.score!,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
        trailing:
            trailing ?? Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }

  Widget _coverPlaceholder(ColorScheme cs) {
    return ColoredBox(
      color: cs.primary.withValues(alpha: 0.1),
      child: Center(
        child: Icon(Icons.menu_book_rounded, color: cs.primary, size: 22),
      ),
    );
  }
}
