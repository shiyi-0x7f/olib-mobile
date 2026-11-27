import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/display_book.dart';
import '../../../search/edition_grouping.dart';
import '../../../search/search_source.dart';
import 'result_common.dart';

/// 「最佳匹配」：排第一的结果用大卡片，可切换版本，主按钮直接下载（由来源提供）。
class BestMatchCard extends ConsumerStatefulWidget {
  final EditionGroup group;
  final SearchSource source;
  final SearchFilterValues filters;

  const BestMatchCard({
    super.key,
    required this.group,
    required this.source,
    required this.filters,
  });

  @override
  ConsumerState<BestMatchCard> createState() => _BestMatchCardState();
}

class _BestMatchCardState extends ConsumerState<BestMatchCard> {
  int _selected = 0;

  @override
  void didUpdateWidget(BestMatchCard old) {
    super.didUpdateWidget(old);
    if (_selected >= widget.group.editions.length) _selected = 0;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final src = widget.source;
    final editions = widget.group.editions;
    final book = editions[_selected];
    final primary = src.buildPrimaryAction(context, ref, book);
    final byline = [
      book.author,
      book.publisher,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.get('search_best_match'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.tertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => src.open(context, ref, book, widget.filters),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchCover(url: book.cover, width: 80),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      if (byline.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          byline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (src.mergesEditions && widget.group.hasVariants)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final (i, e) in editions.indexed)
                              ChoiceChip(
                                label: Text(src.editionLabel(e)),
                                selected: i == _selected,
                                showCheckmark: false,
                                visualDensity: VisualDensity.compact,
                                labelStyle: theme.textTheme.labelSmall,
                                onSelected: (_) =>
                                    setState(() => _selected = i),
                              ),
                          ],
                        )
                      else
                        ResultMetaLine(parts: src.describe(book, t)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (primary != null) ...[
                Expanded(child: primary),
                const SizedBox(width: 8),
              ],
              // 来源没有主操作（如微信读书）时，「详情」占满整行
              if (primary == null)
                Expanded(child: _detailsButton(t, book))
              else
                _detailsButton(t, book),
            ],
          ),
        ],
      ),
    );
  }
}

extension on _BestMatchCardState {
  Widget _detailsButton(AppLocalizations t, DisplayBook book) => SizedBox(
    height: 44,
    child: OutlinedButton(
      onPressed: () => widget.source.open(context, ref, book, widget.filters),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(t.get('search_details')),
    ),
  );
}
