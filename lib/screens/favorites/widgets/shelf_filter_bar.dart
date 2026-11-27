import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/unified_shelf_item.dart';

class ShelfFilterBar extends StatelessWidget {
  const ShelfFilterBar({
    super.key,
    required this.wereadCount,
    required this.libraryCount,
    required this.source,
    required this.onSourceChanged,
    required this.isListView,
    required this.onViewChanged,
  });

  final int wereadCount;
  final int libraryCount;
  final ShelfSource? source;
  final ValueChanged<ShelfSource?> onSourceChanged;
  final bool isListView;
  final ValueChanged<bool> onViewChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(l.get('shelf_all'), null),
                const SizedBox(width: 8),
                _chip(
                  '${l.get('shelf_source_weread')} $wereadCount',
                  ShelfSource.weread,
                ),
                const SizedBox(width: 8),
                _chip(
                  '${l.get('shelf_source_library')} $libraryCount',
                  ShelfSource.library,
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: isListView ? l.get('shelf_view') : l.get('list_view'),
          onPressed: () => onViewChanged(!isListView),
          icon: Icon(
            isListView ? Icons.grid_view_rounded : Icons.view_list_rounded,
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, ShelfSource? value) => ShelfChip(
    label: label,
    selected: source == value,
    onSelected: () => onSourceChanged(value),
  );
}

/// 书架统一的胶囊筛选 chip；[dense] 用于次级（分类）筛选行。
class ShelfChip extends StatelessWidget {
  const ShelfChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      shape: const StadiumBorder(),
      visualDensity: dense ? VisualDensity.compact : null,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: TextStyle(
        fontSize: dense ? 12 : 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
      ),
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? cs.primaryContainer
            : dense
            ? Colors.transparent
            : cs.surface,
      ),
      side: BorderSide(
        color: selected ? cs.primary.withValues(alpha: 0.5) : cs.outlineVariant,
      ),
    );
  }
}
