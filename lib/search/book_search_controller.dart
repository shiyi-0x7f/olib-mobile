import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/display_book.dart';
import '../services/hive_service.dart';
import 'search_source.dart';
import 'search_sources_registry.dart';

/// Hive settings：上次使用的来源（沿用旧 key，老用户的选择不丢）。
const _kSourceKey = 'default_search_source';

/// Hive settings：各来源被记住的筛选（如常用格式），key = 前缀 + 来源 id。
const _kFiltersPrefix = 'search_filters_';

@immutable
class SearchViewState {
  final String sourceId;

  /// 当前来源的筛选选择（未出现的组 = 未选 / 用组默认值）。
  final SearchFilterValues filters;

  /// 最近一次提交的关键词；空表示还没搜。
  final String query;

  /// 产生 [items] 时使用的筛选（打开结果、决定样式时用它，避免改了筛选还没返回时错位）。
  final SearchFilterValues resultFilters;
  final List<DisplayBook> items;
  final Object? nextCursor;
  final int? currentPage;
  final int? totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? loadMoreError;

  const SearchViewState({
    required this.sourceId,
    this.filters = const {},
    this.query = '',
    this.resultFilters = const {},
    this.items = const [],
    this.nextCursor,
    this.currentPage,
    this.totalPages,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  bool get hasSearched => query.isNotEmpty;
  bool get hasMore => nextCursor != null;

  /// 换来源 / 清空时保留来源与筛选，丢掉结果。
  SearchViewState cleared({String? sourceId, SearchFilterValues? filters}) =>
      SearchViewState(
        sourceId: sourceId ?? this.sourceId,
        filters: filters ?? this.filters,
      );
}

/// 所有来源共用的搜索状态机：加载 / 翻页 / 出错 / 过期请求丢弃。
class BookSearchController extends StateNotifier<SearchViewState> {
  final Ref _ref;
  int _requestId = 0;

  BookSearchController(this._ref, String sourceId)
    : super(
        SearchViewState(sourceId: sourceId, filters: _loadFilters(sourceId)),
      );

  SearchSource get source =>
      findSearchSource(_ref.read(searchSourcesProvider), state.sourceId);

  /// [persist] 为 false 时不改「默认来源」（如从微信读书主页带着来源进来）。
  void selectSource(String id, {bool persist = true}) {
    if (id == state.sourceId) return;
    final query = state.query;
    _requestId++;
    state = state.cleared(sourceId: id, filters: _loadFilters(id));
    if (persist) _put(_kSourceKey, id);
    if (query.isNotEmpty) search(query);
  }

  /// 一次改多组筛选（筛选面板关闭时批量提交），只重新搜索一次。
  void setFilters(Map<SearchFilterGroup, String?> changes) {
    if (changes.isEmpty) return;
    final next = {
      ...state.filters,
      for (final e in changes.entries) e.key.id: e.value,
    };
    state = SearchViewState(
      sourceId: state.sourceId,
      filters: next,
      query: state.query,
      resultFilters: state.resultFilters,
      items: state.items,
      nextCursor: state.nextCursor,
      currentPage: state.currentPage,
      totalPages: state.totalPages,
    );
    final remembered = {
      for (final e in changes.entries)
        if (e.key.remember) e.key.id: e.value,
    };
    if (remembered.isNotEmpty) {
      _put('$_kFiltersPrefix${state.sourceId}', {
        ..._loadFilters(state.sourceId),
        ...remembered,
      });
    }
    if (state.query.isNotEmpty) search(state.query);
  }

  /// 提交搜索。来源未就绪时只记下关键词，由界面展示来源的引导。
  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final requestId = ++_requestId;
    final src = source;
    final filters = state.filters;
    if (!_ref.read(src.readyProvider)) {
      state = SearchViewState(sourceId: src.id, filters: filters, query: q);
      return;
    }
    state = SearchViewState(
      sourceId: src.id,
      filters: filters,
      query: q,
      resultFilters: filters,
      isLoading: true,
    );
    try {
      final page = await src.fetch(_ref, q, filters, null);
      if (requestId != _requestId || !mounted) return;
      state = SearchViewState(
        sourceId: src.id,
        filters: state.filters,
        query: q,
        resultFilters: filters,
        items: page.items,
        nextCursor: page.nextCursor,
        currentPage: page.currentPage,
        totalPages: page.totalPages,
      );
    } catch (e, st) {
      if (requestId != _requestId || !mounted) return;
      debugPrint('[Search] ${src.id} 搜索失败: $e\n$st');
      state = SearchViewState(
        sourceId: src.id,
        filters: state.filters,
        query: q,
        resultFilters: filters,
        error: e.toString(),
      );
    }
  }

  /// 滚动触底自动调用；失败后需用户点「重试」（[retry] = true），避免滚动时反复请求。
  Future<void> loadMore({bool retry = false}) async {
    final s = state;
    if (!s.hasMore || s.isLoading || s.isLoadingMore || s.items.isEmpty) return;
    if (s.loadMoreError != null && !retry) return;
    final requestId = _requestId;
    final src = source;
    state = _withPaging(s, isLoadingMore: true);
    try {
      final page = await src.fetch(
        _ref,
        s.query,
        s.resultFilters,
        s.nextCursor,
      );
      if (requestId != _requestId || !mounted) return;
      state = SearchViewState(
        sourceId: s.sourceId,
        filters: state.filters,
        query: s.query,
        resultFilters: s.resultFilters,
        items: [...s.items, ...page.items],
        nextCursor: page.nextCursor,
        currentPage: page.currentPage ?? s.currentPage,
        totalPages: page.totalPages ?? s.totalPages,
      );
    } catch (e, st) {
      if (requestId != _requestId || !mounted) return;
      debugPrint('[Search] ${src.id} 加载更多失败: $e\n$st');
      state = _withPaging(state, loadMoreError: e.toString());
    }
  }

  void clear() {
    _requestId++;
    state = state.cleared();
  }

  SearchViewState _withPaging(
    SearchViewState s, {
    bool isLoadingMore = false,
    String? loadMoreError,
  }) => SearchViewState(
    sourceId: s.sourceId,
    filters: s.filters,
    query: s.query,
    resultFilters: s.resultFilters,
    items: s.items,
    nextCursor: s.nextCursor,
    currentPage: s.currentPage,
    totalPages: s.totalPages,
    isLoadingMore: isLoadingMore,
    loadMoreError: loadMoreError,
  );

  static SearchFilterValues _loadFilters(String sourceId) {
    final raw = HiveService.settingsBox.get('$_kFiltersPrefix$sourceId');
    if (raw is! Map) return {};
    return {
      for (final e in raw.entries)
        if (e.key is String) e.key as String: e.value as String?,
    };
  }

  static void _put(String key, Object value) {
    HiveService.settingsBox.put(key, value).catchError((Object e) {
      debugPrint('[Search] 保存 $key 失败: $e');
    });
  }
}

final bookSearchControllerProvider =
    StateNotifierProvider.autoDispose<BookSearchController, SearchViewState>((
      ref,
    ) {
      final sources = ref.read(searchSourcesProvider);
      final saved = HiveService.settingsBox.get(_kSourceKey) as String?;
      return BookSearchController(ref, findSearchSource(sources, saved).id);
    });
