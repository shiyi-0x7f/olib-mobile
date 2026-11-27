import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../models/display_book.dart';
import '../../providers/download_provider.dart';
import '../../search/book_search_controller.dart';
import '../../search/recent_searches.dart';
import '../../search/search_source.dart';
import '../../search/search_sources_registry.dart';
import '../../services/update_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/report_problem_button.dart';
import '../../widgets/update_dialog.dart';
import '../book_detail/widgets/download_quota_dialog.dart';
import 'widgets/search_filter_bar.dart';
import 'widgets/search_idle_view.dart';
import 'widgets/search_results_view.dart';
import 'widgets/search_top_bar.dart';

/// 搜索页壳层：只负责把来源、筛选、结果几个部件接起来。
///
/// 具体来源的行为全部在 `lib/search/sources/`，这里不出现任何来源判断。
class SearchScreen extends ConsumerStatefulWidget {
  /// 从某个来源的入口进来时指定（不改用户的默认来源）。
  final BookSource? initialSource;

  const SearchScreen({super.key, this.initialSource});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _gridMode = false;

  BookSearchController get _search =>
      ref.read(bookSearchControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final initial = widget.initialSource;
      if (initial != null) _search.selectSource(initial.name, persist: false);
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final p = _scrollController.position;
    if (p.pixels >= p.maxScrollExtent - 300) _search.loadMore();
  }

  void _submit([String? keyword]) {
    if (keyword != null) {
      _textController.value = TextEditingValue(
        text: keyword,
        selection: TextSelection.collapsed(offset: keyword.length),
      );
    }
    final query = _textController.text.trim();
    if (query.isEmpty) return;
    if (UpdateService.isBlocked) {
      showUpdateDialog(context);
      return;
    }
    _focusNode.unfocus();
    _search.search(query);
    _rememberQuery(query);
  }

  void _fill(String keyword) {
    _textController.value = TextEditingValue(
      text: keyword,
      selection: TextSelection.collapsed(offset: keyword.length),
    );
    _focusNode.requestFocus();
  }

  void _clear() {
    _textController.clear();
    _search.clear();
    _focusNode.requestFocus();
  }

  void _rememberQuery(String query) {
    unawaited(
      _saveRecent(
        () => ref.read(recentSearchesProvider.notifier).remember(query),
      ),
    );
  }

  Future<void> _saveRecent(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      debugPrint('[Search] 保存搜索记录失败: $e');
      if (!mounted) return;
      AppToast.error(
        AppLocalizations.of(context).get('search_history_save_failed'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final sources = ref.watch(searchSourcesProvider);
    final state = ref.watch(bookSearchControllerProvider);
    final source = findSearchSource(sources, state.sourceId);
    final groups = source.filters(t, locale);

    // 行内下载因账号额度用尽失败时提醒一次（详情页在上层时由详情页负责）
    ref.listen<List<DownloadTask>>(downloadProvider, (prev, next) {
      bool hit(DownloadTask task) => task.quotaExceeded;
      final newly = next.where(hit).map((e) => e.id).toSet()
        ..removeAll(prev?.where(hit).map((e) => e.id) ?? const <String>[]);
      if (newly.isNotEmpty && ModalRoute.of(context)?.isCurrent == true) {
        showDownloadQuotaDialog(context);
      }
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SearchTopBar(
              controller: _textController,
              focusNode: _focusNode,
              hint: source.hint(t, state.filters),
              onSubmitted: (_) => _submit(),
              onClear: _clear,
            ),
            SearchFilterBar(
              sources: sources,
              current: source,
              groups: groups,
              values: state.filters,
              onSourceSelected: (s) => _search.selectSource(s.id),
              onFiltersChanged: _search.setFilters,
            ),
            const SizedBox(height: 4),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _textController,
                builder: (context, text, _) => _body(
                  context,
                  t,
                  sources,
                  source,
                  state,
                  text.text.trim().isEmpty,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations t,
    List<SearchSource> sources,
    SearchSource source,
    SearchViewState state,
    bool fieldEmpty,
  ) {
    if (!ref.watch(source.readyProvider)) {
      return source.buildSetup(context, ref);
    }

    if (fieldEmpty || !state.hasSearched) {
      final recents = ref.read(recentSearchesProvider.notifier);
      return SearchIdleView(
        recent: ref.watch(recentSearchesProvider),
        onSearch: _submit,
        onFill: _fill,
        onRemove: (k) => _saveRecent(() => recents.remove(k)),
        onClear: () => _saveRecent(recents.clear),
      );
    }

    if (state.isLoading) {
      return LoadingWidget(message: t.get('searching_books'));
    }

    if (state.error != null && state.items.isEmpty) {
      return EmptyState(
        icon: Icons.error_outline,
        title: t.get('search_failed'),
        message: state.error,
        action: Column(
          children: [
            FilledButton(
              onPressed: () => _search.search(state.query),
              child: Text(t.get('search_retry')),
            ),
            const SizedBox(height: 8),
            ReportProblemButton(
              area: 'search',
              errorDetail:
                  '[${source.id}] "${state.query}"\n${state.error ?? ''}',
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      final others = sources.where((s) => s.id != source.id).toList();
      return EmptyState(
        icon: Icons.search_off,
        title: t.get('no_results'),
        message: others.isEmpty
            ? t.get('try_different_keywords')
            : t.get('search_no_results_switch'),
        action: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final s in others)
              FilledButton.tonalIcon(
                onPressed: () => _search.selectSource(s.id),
                icon: Icon(s.icon, size: 18),
                label: Text('${t.get('search_try_source')} ${s.label(t)}'),
              ),
          ],
        ),
      );
    }

    return SearchResultsView(
      source: source,
      state: state,
      scrollController: _scrollController,
      gridMode: _gridMode,
      onToggleGrid: () => setState(() => _gridMode = !_gridMode),
      onRetryMore: () => _search.loadMore(retry: true),
    );
  }
}
