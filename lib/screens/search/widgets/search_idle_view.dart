import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

/// 还没搜索时：最近搜索（点一下直接搜，箭头只填入搜索框）+ 搜索方式提示。
class SearchIdleView extends StatelessWidget {
  final List<String> recent;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onFill;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  const SearchIdleView({
    super.key,
    required this.recent,
    required this.onSearch,
    required this.onFill,
    required this.onRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final headStyle = theme.textTheme.labelLarge?.copyWith(
      color: cs.onSurfaceVariant,
    );

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(t.get('search_history_title'), style: headStyle),
              ),
              TextButton(
                onPressed: onClear,
                child: Text(t.get('search_history_clear')),
              ),
            ],
          ),
          for (final k in recent)
            Dismissible(
              key: ValueKey('recent-$k'),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => onRemove(k),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: cs.errorContainer,
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: cs.onErrorContainer,
                ),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 4),
                leading: Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                title: Text(k, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  tooltip: t.get('search_fill_query'),
                  icon: Icon(
                    Icons.north_west_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: () => onFill(k),
                ),
                onTap: () => onSearch(k),
              ),
            ),
          const SizedBox(height: 20),
        ],
        Text(t.get('search_tips_title'), style: headStyle),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final key in const [
              'search_tip_title',
              'search_tip_author',
              'search_tip_isbn',
            ])
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text(t.get(key), style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ],
    );
  }
}
