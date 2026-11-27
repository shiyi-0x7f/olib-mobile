import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../search/search_source.dart';

typedef SearchFiltersChanged =
    void Function(Map<SearchFilterGroup, String?> changes);

/// 顶栏下的一行：[来源…] | [inline 筛选…] | [筛选 ▾]。
///
/// 来源与筛选都来自 [SearchSource] 声明，新增来源 / 筛选无需改这里。
/// inline 组（如微信读书范围）平铺为标签；其余 sheet 组合并成一个「筛选」按钮，
/// 选中后按钮显示当前值摘要，点开一个面板统一调整，关闭时一次提交。
class SearchFilterBar extends ConsumerWidget {
  final List<SearchSource> sources;
  final SearchSource current;
  final List<SearchFilterGroup> groups;
  final SearchFilterValues values;
  final ValueChanged<SearchSource> onSourceSelected;
  final SearchFiltersChanged onFiltersChanged;

  const SearchFilterBar({
    super.key,
    required this.sources,
    required this.current,
    required this.groups,
    required this.values,
    required this.onSourceSelected,
    required this.onFiltersChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final inline = groups.where((g) => g.display == SearchFilterDisplay.inline);
    final sheet = groups
        .where((g) => g.display == SearchFilterDisplay.sheet)
        .toList();
    final children = <Widget>[
      for (final s in sources)
        _SourceChip(
          source: s,
          label: s.label(t),
          selected: s.id == current.id,
          ready: ref.watch(s.readyProvider),
          onTap: () => onSourceSelected(s),
        ),
      for (final g in inline) ...[
        _divider(cs),
        for (final o in g.options)
          _FilterChip(
            label: o.label,
            selected: (values[g.id] ?? g.defaultValue) == o.value,
            onTap: () {
              final selected = (values[g.id] ?? g.defaultValue) == o.value;
              // required 组不可取消；普通组再点一次回到「全部」
              if (selected && g.required) return;
              onFiltersChanged({g: selected ? null : o.value});
            },
          ),
      ],
      if (sheet.isNotEmpty) ...[
        _divider(cs),
        _FiltersChip(
          groups: sheet,
          values: values,
          onChanged: onFiltersChanged,
        ),
      ],
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) => Center(child: children[i]),
      ),
    );
  }

  Widget _divider(ColorScheme cs) =>
      Container(width: 1, height: 20, color: cs.outlineVariant);
}

class _SourceChip extends StatelessWidget {
  final SearchSource source;
  final String label;
  final bool selected;
  final bool ready;
  final VoidCallback onTap;

  const _SourceChip({
    required this.source,
    required this.label,
    required this.selected,
    required this.ready,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      avatar: Icon(
        ready ? source.icon : Icons.link_off_rounded,
        size: 16,
        color: selected ? cs.onPrimary : cs.onSurfaceVariant,
      ),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: cs.primary,
      labelStyle: TextStyle(
        color: selected ? cs.onPrimary : cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onTap(),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: cs.primaryContainer,
      labelStyle: TextStyle(
        color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onTap(),
    );
  }
}

/// 所有 sheet 组合并成的一个按钮：未选显示「筛选」，选了显示「EPUB · 简体中文」。
class _FiltersChip extends StatelessWidget {
  final List<SearchFilterGroup> groups;
  final SearchFilterValues values;
  final SearchFiltersChanged onChanged;

  const _FiltersChip({
    required this.groups,
    required this.values,
    required this.onChanged,
  });

  String? _valueOf(SearchFilterGroup g) => values[g.id] ?? g.defaultValue;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final summary = [
      for (final g in groups)
        if (_valueOf(g) != null && _valueOf(g) != g.defaultValue)
          g.labelOf(_valueOf(g)),
    ];
    final active = summary.isNotEmpty;
    return ActionChip(
      avatar: Icon(
        Icons.tune_rounded,
        size: 16,
        color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant,
      ),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(
          active ? summary.join(' · ') : t.get('search_filter'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      labelStyle: TextStyle(
        color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: active ? cs.primaryContainer : null,
      side: BorderSide(color: active ? cs.primary : cs.outlineVariant),
      visualDensity: VisualDensity.compact,
      onPressed: () => _open(context),
    );
  }

  Future<void> _open(BuildContext context) async {
    final draft = <String, String?>{for (final g in groups) g.id: _valueOf(g)};
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _FiltersSheet(groups: groups, draft: draft),
    );
    // 不论点「完成」还是下滑关闭，都按面板里的选择一次提交
    final changes = <SearchFilterGroup, String?>{
      for (final g in groups)
        if (draft[g.id] != _valueOf(g)) g: draft[g.id],
    };
    if (changes.isNotEmpty) onChanged(changes);
  }
}

class _FiltersSheet extends StatefulWidget {
  final List<SearchFilterGroup> groups;

  /// 面板内的草稿，原地修改，关闭后由调用方比对提交。
  final Map<String, String?> draft;

  const _FiltersSheet({required this.groups, required this.draft});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  void _pick(SearchFilterGroup g, String? value) {
    setState(() {
      final selected = widget.draft[g.id] == value;
      // 再点已选项回到「全部」；required 组不可取消
      widget.draft[g.id] = selected && !g.required ? g.defaultValue : value;
    });
  }

  void _reset() => setState(() {
    for (final g in widget.groups) {
      widget.draft[g.id] = g.defaultValue;
    }
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final g in widget.groups) ...[
                      Text(g.title, style: text.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final o in g.options)
                            ChoiceChip(
                              label: Text(o.label),
                              selected: widget.draft[g.id] == o.value,
                              onSelected: (_) => _pick(g, o.value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _reset,
                    child: Text(t.get('search_filter_reset')),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t.get('done')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
