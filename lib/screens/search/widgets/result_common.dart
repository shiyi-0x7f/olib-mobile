import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/display_book.dart';
import '../../../search/search_source.dart';

/// 纯文本结果（如微信读书公众号 / 文章）。
class TextResultTile extends ConsumerWidget {
  final DisplayBook item;
  final SearchSource source;
  final SearchFilterValues filters;

  const TextResultTile({
    super.key,
    required this.item,
    required this.source,
    required this.filters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: () => source.open(context, ref, item, filters),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isEmpty
                        ? t.get('weread_untitled_content')
                        : item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if ((item.author ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if ((item.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      item.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// 「EPUB · 2.1 MB · 2008」一行；首项可加重（格式）。
class ResultMetaLine extends StatelessWidget {
  final List<String> parts;
  final bool emphasizeFirst;

  const ResultMetaLine({
    super.key,
    required this.parts,
    this.emphasizeFirst = true,
  });

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final base = TextStyle(
      fontSize: 12,
      color: cs.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(
            text: parts.first,
            style: emphasizeFirst
                ? TextStyle(color: cs.primary, fontWeight: FontWeight.w700)
                : null,
          ),
          if (parts.length > 1)
            TextSpan(text: ' · ${parts.skip(1).join(' · ')}'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class SearchCover extends StatelessWidget {
  final String? url;
  final double width;

  const SearchCover({super.key, required this.url, required this.width});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: cs.primary.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          color: cs.primary,
          size: width * 0.4,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: width * 1.45,
        child: url == null || url!.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                memCacheWidth: (width * MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
