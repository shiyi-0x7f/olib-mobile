import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../search/book_search_controller.dart';
import '../../../search/edition_grouping.dart';
import '../../../search/search_source.dart';
import '../../../widgets/book_card.dart';
import 'best_match_card.dart';
import 'edition_row.dart';
import 'result_common.dart';

/// 搜索结果：一行概要 → 最佳匹配卡片 → 其余紧凑行（或宫格）→ 翻页尾。
class SearchResultsView extends ConsumerWidget {
  final SearchSource source;
  final SearchViewState state;
  final ScrollController scrollController;
  final bool gridMode;
  final VoidCallback onToggleGrid;
  final VoidCallback onRetryMore;

  const SearchResultsView({
    super.key,
    required this.source,
    required this.state,
    required this.scrollController,
    required this.gridMode,
    required this.onToggleGrid,
    required this.onRetryMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final filters = state.resultFilters;
    final layout = source.layoutFor(filters);
    final isBooks = layout == SearchResultLayout.books;
    final groups = isBooks && source.mergesEditions
        ? groupEditions(state.items)
        : [
            for (final b in state.items) EditionGroup([b]),
          ];

    final slivers = <Widget>[
      SliverToBoxAdapter(child: _summary(context, t, isBooks)),
      if (!isBooks)
        SliverList.builder(
          itemCount: groups.length,
          itemBuilder: (_, i) => TextResultTile(
            item: groups[i].primary,
            source: source,
            filters: filters,
          ),
        )
      else if (gridMode)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              childAspectRatio: 0.60,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: groups.length,
            itemBuilder: (_, i) => BookCard(
              book: groups[i].primary,
              searchResult: true,
              onTap: () =>
                  source.open(context, ref, groups[i].primary, filters),
            ),
          ),
        )
      else ...[
        SliverToBoxAdapter(
          child: BestMatchCard(
            // 关键词变了要重置卡片里选中的版本
            key: ValueKey('best-${state.query}-${groups.first.primary.id}'),
            group: groups.first,
            source: source,
            filters: filters,
          ),
        ),
        if (groups.length > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
              child: Text(
                t.get('search_other_results'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        SliverList.builder(
          itemCount: groups.length - 1,
          itemBuilder: (_, i) => EditionRow(
            key: ValueKey(editionKey(groups[i + 1].primary)),
            group: groups[i + 1],
            source: source,
            filters: filters,
          ),
        ),
      ],
      SliverToBoxAdapter(child: _footer(context, t)),
    ];

    return CustomScrollView(controller: scrollController, slivers: slivers);
  }

  Widget _summary(BuildContext context, AppLocalizations t, bool isBooks) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final count = t
        .get(isBooks ? 'search_results_count' : 'weread_search_results_count')
        .replaceAll('{count}', '${state.items.length}');
    final page = state.totalPages != null && state.totalPages! > 1
        ? ' · ${t.get('search_page_progress').replaceAll('{current}', '${state.currentPage}').replaceAll('{total}', '${state.totalPages}')}'
        : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count$page',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (isBooks)
            IconButton(
              tooltip: t.get(gridMode ? 'list_view' : 'grid_view'),
              icon: Icon(
                gridMode ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              onPressed: onToggleGrid,
            ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, AppLocalizations t) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Row(
          children: [
            Expanded(child: Text(t.get('search_more_failed'))),
            TextButton(
              onPressed: onRetryMore,
              child: Text(t.get('search_retry')),
            ),
          ],
        ),
      );
    }
    return SizedBox(height: MediaQuery.paddingOf(context).bottom + 24);
  }
}
