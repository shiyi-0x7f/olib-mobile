import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/display_book.dart';
import '../../../search/edition_grouping.dart';
import '../../../search/search_source.dart';
import 'result_common.dart';

/// 紧凑结果行；多版本时可就地展开，每个版本都有自己的行尾操作。
class EditionRow extends ConsumerStatefulWidget {
  final EditionGroup group;
  final SearchSource source;
  final SearchFilterValues filters;

  const EditionRow({
    super.key,
    required this.group,
    required this.source,
    required this.filters,
  });

  @override
  ConsumerState<EditionRow> createState() => _EditionRowState();
}

class _EditionRowState extends ConsumerState<EditionRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final src = widget.source;
    final book = widget.group.primary;
    final variants = src.mergesEditions && widget.group.hasVariants;
    final meta = src.describe(book, t);

    return Column(
      children: [
        InkWell(
          onTap: () => src.open(context, ref, book, widget.filters),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                SearchCover(url: book.cover, width: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((book.author ?? '').isNotEmpty)
                        Text(
                          book.author!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(child: ResultMetaLine(parts: meta)),
                          if (variants) ...[
                            const SizedBox(width: 6),
                            _VariantsToggle(
                              count: widget.group.editions.length,
                              expanded: _expanded,
                              onTap: () =>
                                  setState(() => _expanded = !_expanded),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                src.buildRowAction(context, ref, book) ??
                    Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant,
                    ),
              ],
            ),
          ),
        ),
        if (variants && _expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 8, 8),
            child: Column(
              children: [
                for (final e in widget.group.editions)
                  _EditionTile(book: e, source: src, filters: widget.filters),
              ],
            ),
          ),
        Divider(
          height: 1,
          indent: 72,
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}

class _VariantsToggle extends StatelessWidget {
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  const _VariantsToggle({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = AppLocalizations.of(
      context,
    ).get('search_editions').replaceAll('{count}', '$count');
    return Material(
      color: expanded ? cs.primaryContainer : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 1, 2, 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: expanded ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                ),
              ),
              Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 16,
                color: expanded ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditionTile extends ConsumerWidget {
  final DisplayBook book;
  final SearchSource source;
  final SearchFilterValues filters;

  const _EditionTile({
    required this.book,
    required this.source,
    required this.filters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => source.open(context, ref, book, filters),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
          child: Row(
            children: [
              Expanded(
                child: ResultMetaLine(
                  parts: source.describe(book, t),
                  emphasizeFirst: true,
                ),
              ),
              source.buildRowAction(context, ref, book) ??
                  const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
