import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/weread/weread_api.dart';
import '../services/weread/weread_models.dart';
import '../services/weread/weread_mobile_client.dart';

final wereadMobileClientProvider = Provider<WereadMobileClient>((ref) {
  return WereadMobileClient();
});

/// The QR session is the single connection used by every WeRead feature.
class WereadConnectionNotifier extends StateNotifier<AsyncValue<bool>> {
  final WereadMobileClient _client;
  int _revision = 0;

  WereadConnectionNotifier(this._client) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    final revision = ++_revision;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _client.isConnected);
    if (mounted && revision == _revision) state = result;
  }

  void setConnected(bool connected) {
    _revision++;
    state = AsyncValue.data(connected);
  }
}

final wereadConnectionProvider =
    StateNotifierProvider<WereadConnectionNotifier, AsyncValue<bool>>((ref) {
      return WereadConnectionNotifier(ref.watch(wereadMobileClientProvider));
    });

final isWereadConnectedProvider = Provider<bool>((ref) {
  return ref.watch(wereadConnectionProvider).valueOrNull == true;
});

// ═══════════════════════════════════════════════════════════════════
// API 实例
// ═══════════════════════════════════════════════════════════════════

/// WeRead data adapter, available after QR connection.
final wereadApiProvider = Provider<WereadApi?>((ref) {
  if (!ref.watch(isWereadConnectedProvider)) return null;
  return WereadApi(ref.watch(wereadMobileClientProvider));
});

// ═══════════════════════════════════════════════════════════════════
// 数据 Providers
// ═══════════════════════════════════════════════════════════════════

/// 书架数据
final wereadShelfProvider = FutureProvider<ShelfSyncResponse?>((ref) async {
  final api = ref.watch(wereadApiProvider);
  if (api == null) return null;
  return await api.shelfSync();
});

/// 阅读统计（累计）
final wereadStatsProvider = FutureProvider<ReadDataResponse?>((ref) async {
  final api = ref.watch(wereadApiProvider);
  if (api == null) return null;
  // mode 参数是必须的，不传会 499；'overall' 返回累计数据
  return await api.readDataDetail(mode: 'overall');
});

/// 首页只读取本周数据，用于今日进度和最近七天的阅读趋势。
final wereadWeeklyStatsProvider = FutureProvider<ReadDataResponse?>((
  ref,
) async {
  final api = ref.watch(wereadApiProvider);
  if (api == null) return null;
  return api.readDataDetail(mode: 'weekly');
});

/// 首页先取一页笔记，完整笔记本仅在用户主动打开时加载。
final wereadRecentNotebooksProvider = FutureProvider<NotebooksResponse?>((
  ref,
) async {
  final api = ref.watch(wereadApiProvider);
  if (api == null) return null;
  return api.notebooks(count: 30);
});

class WereadHomeHighlight {
  final NotebookBook notebook;
  final List<Bookmark> bookmarks;

  const WereadHomeHighlight({required this.notebook, required this.bookmarks});
}

/// 从最近有划线的书中取少量原文，作为首页的主动回顾入口。
final wereadHomeHighlightProvider = FutureProvider<WereadHomeHighlight?>((
  ref,
) async {
  final api = ref.watch(wereadApiProvider);
  final notebooks = await ref.watch(wereadRecentNotebooksProvider.future);
  if (api == null || notebooks == null) return null;
  Object? lastError;
  StackTrace? lastStackTrace;
  for (final notebook
      in notebooks.books.where((book) => book.noteCount > 0).take(3)) {
    try {
      final response = await api.bookmarks(notebook.bookId);
      final bookmarks = response.updated
          .where((bookmark) => bookmark.markText.trim().isNotEmpty)
          .take(16)
          .toList();
      if (bookmarks.isNotEmpty) {
        return WereadHomeHighlight(notebook: notebook, bookmarks: bookmarks);
      }
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
    }
  }
  if (lastError != null) Error.throwWithStackTrace(lastError, lastStackTrace!);
  return null;
});

/// 笔记概览 — 拉取所有页（使用 lastSort 游标自动翻页）
final wereadNotebooksProvider = FutureProvider<NotebooksResponse?>((ref) async {
  final api = ref.watch(wereadApiProvider);
  if (api == null) return null;

  // First page to get totalNoteCount / totalBookCount
  final firstPage = await api.notebooks(count: 100);
  final allBooks = List<NotebookBook>.from(firstPage.books);

  // Auto-paginate if there are more
  if (firstPage.hasMoreResults && allBooks.isNotEmpty) {
    int? lastSort = allBooks.last.sort;
    final seenSorts = <int?>{lastSort};
    while (true) {
      final page = await api.notebooks(count: 100, lastSort: lastSort);
      if (page.books.isEmpty) break;
      allBooks.addAll(page.books);
      if (!page.hasMoreResults) break;
      lastSort = page.books.last.sort;
      if (!seenSorts.add(lastSort)) break;
    }
  }

  return NotebooksResponse(
    totalBookCount: firstPage.totalBookCount,
    totalNoteCount: firstPage.totalNoteCount,
    hasMore: 0,
    books: allBooks,
  );
});

/// 个性化推荐（分页）
class WereadRecommendNotifier
    extends StateNotifier<AsyncValue<List<RecommendBook>>> {
  final WereadApi? _api;
  static const _initialCount = 20;
  static const _pageSize = 40;
  int _nextOffset = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  WereadRecommendNotifier(this._api) : super(const AsyncValue.loading()) {
    _loadInitial();
  }

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;

  Future<void> _loadInitial() async {
    if (_api == null) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      final resp = await _api.recommend(count: _initialCount);
      _nextOffset = resp.books.length;
      _hasMore = resp.books.length >= _initialCount;
      state = AsyncValue.data(resp.books);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _api == null) return;
    _isLoadingMore = true;
    try {
      final resp = await _api.recommend(count: _pageSize, maxIdx: _nextOffset);
      if (resp.books.isEmpty) {
        _hasMore = false;
      } else {
        final existing = state.valueOrNull ?? [];
        final existingIds = existing.map((b) => b.bookId).toSet();
        final newBooks = resp.books
            .where((b) => !existingIds.contains(b.bookId))
            .toList();
        _nextOffset += resp.books.length;
        state = AsyncValue.data([...existing, ...newBooks]);
      }
    } catch (_) {
      // 静默失败，保留已有数据
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    _nextOffset = 0;
    _hasMore = true;
    state = const AsyncValue.loading();
    await _loadInitial();
  }
}

final wereadRecommendProvider =
    StateNotifierProvider<
      WereadRecommendNotifier,
      AsyncValue<List<RecommendBook>>
    >((ref) {
      final api = ref.watch(wereadApiProvider);
      return WereadRecommendNotifier(api);
    });

/// 用户资料概况
final wereadProfileProvider = FutureProvider<ProfileSummary?>((ref) async {
  final api = ref.watch(wereadApiProvider);
  if (api == null) return null;
  return await api.profileSummary();
});

// ═══════════════════════════════════════════════════════════════════
// 搜索
// ═══════════════════════════════════════════════════════════════════

class WereadSearchState {
  final List<SearchResultBook> results;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasSearched;
  final bool hasMore;
  final String? error;

  const WereadSearchState({
    this.results = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasSearched = false,
    this.hasMore = false,
    this.error,
  });

  WereadSearchState copyWith({
    List<SearchResultBook>? results,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasSearched,
    bool? hasMore,
    String? error,
  }) {
    return WereadSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasSearched: hasSearched ?? this.hasSearched,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class WereadSearchNotifier extends StateNotifier<WereadSearchState> {
  final WereadApi? _api;
  String? _keyword;
  int _scope = 10;
  int _requestId = 0;

  WereadSearchNotifier(this._api) : super(const WereadSearchState());

  Future<void> search(String keyword, {int scope = 10}) async {
    final query = keyword.trim();
    if (query.isEmpty) return;
    final requestId = ++_requestId;
    _keyword = query;
    _scope = scope;
    if (_api == null) {
      state = const WereadSearchState(
        hasSearched: true,
        error: 'Connect WeRead first',
      );
      return;
    }

    state = const WereadSearchState(isLoading: true, hasSearched: true);

    try {
      final response = await _api.search(keyword: query, scope: scope);
      if (requestId != _requestId) return;
      final books = <SearchResultBook>[];
      for (final group in response.results) {
        books.addAll(group.books);
      }
      state = WereadSearchState(
        results: books,
        hasSearched: true,
        hasMore: response.hasMoreResults && books.isNotEmpty,
      );
    } catch (e) {
      if (requestId != _requestId) return;
      state = WereadSearchState(hasSearched: true, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (_api == null ||
        _keyword == null ||
        !state.hasMore ||
        state.isLoading ||
        state.isLoadingMore ||
        state.results.isEmpty) {
      return;
    }

    final requestId = _requestId;
    state = state.copyWith(isLoadingMore: true);
    try {
      final response = await _api.search(
        keyword: _keyword!,
        scope: _scope,
        maxIdx: state.results.last.searchIdx,
      );
      if (requestId != _requestId) return;
      final books = response.results.expand((group) => group.books).toList();
      state = state.copyWith(
        results: [...state.results, ...books],
        isLoadingMore: false,
        hasMore: response.hasMoreResults && books.isNotEmpty,
      );
    } catch (e) {
      if (requestId != _requestId) return;
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  void reset() {
    _requestId++;
    _keyword = null;
    state = const WereadSearchState();
  }
}

final wereadSearchProvider =
    StateNotifierProvider<WereadSearchNotifier, WereadSearchState>((ref) {
      final api = ref.watch(wereadApiProvider);
      return WereadSearchNotifier(api);
    });
