import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/unified_shelf_item.dart';
import '../../../providers/shelf_provider.dart';
import '../../../theme/app_colors.dart';

/// 书架筛选栏：来源 Chips + 视图切换
class ShelfFilterBar extends ConsumerWidget {
  final int wereadCount;
  final int libraryCount;
  final bool isListView;
  final ValueChanged<bool> onViewChanged;

  const ShelfFilterBar({
    super.key,
    required this.wereadCount,
    required this.libraryCount,
    required this.isListView,
    required this.onViewChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final filter = ref.watch(shelfFilterProvider);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Chip 区可横向滚动，避免窄屏/长文案时整行溢出
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: l.get('shelf_all'),
                      value: null,
                      current: filter,
                      onSelected: () =>
                          ref.read(shelfFilterProvider.notifier).state = null,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '${l.get('shelf_source_weread')} ($wereadCount)',
                      value: ShelfSource.weread,
                      current: filter,
                      onSelected: () =>
                          ref.read(shelfFilterProvider.notifier).state =
                              ShelfSource.weread,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '${l.get('shelf_source_library')} ($libraryCount)',
                      value: ShelfSource.library,
                      current: filter,
                      onSelected: () =>
                          ref.read(shelfFilterProvider.notifier).state =
                              ShelfSource.library,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ViewToggle(isListView: isListView, onChanged: onViewChanged),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final ShelfSource? value;
  final ShelfSource? current;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
      side: BorderSide(
        color: selected
            ? AppColors.primary
            : Theme.of(context).colorScheme.outlineVariant,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final bool isListView;
  final ValueChanged<bool> onChanged;

  const _ViewToggle({required this.isListView, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggle(
            context,
            Icons.grid_view_rounded,
            !isListView,
            () => onChanged(false),
          ),
          _toggle(
            context,
            Icons.view_list_rounded,
            isListView,
            () => onChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _toggle(
    BuildContext context,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected
              ? AppColors.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
