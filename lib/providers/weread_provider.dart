import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/weread/weread_api.dart';
import '../services/weread/weread_models.dart';
import '../services/weread/weread_mobile_client.dart';
import '../services/weread/weread_recommend_pool.dart';

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

/// 个性化推荐（分页）：书架种子相似书推荐池，见 [WereadRecommendPool]
class WereadRecommendNotifier
    extends StateNotifier<AsyncValue<List<RecommendBook>>> {
  final WereadApi? _api;
  static const _initialCount = 20;
  static const _pageSize = 12;
  WereadRecommendPool? _pool;
  // 每次刷新 +1；异步返回时代数不符说明已被新一轮刷新取代，结果作废
  int _generation = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  WereadRecommendNotifier(this._api) : super(const AsyncValue.loading()) {
    _loadInitial();
  }

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;

  bool _isStale(int generation) => !mounted || generation != _generation;

  Future<void> _loadInitial() async {
    final api = _api;
    if (api == null) {
      _hasMore = false;
      state = const AsyncValue.data([]);
      return;
    }
    final generation = _generation;
    try {
      final shelf = await api.shelfSync();
      if (_isStale(generation)) return;
      final pool = WereadRecommendPool.fromShelf(shelf);
      _pool = pool;
      final batch = await pool.next(api, _initialCount);
      if (_isStale(generation)) return;
      _hasMore = !batch.exhausted;
      state = AsyncValue.data(batch.books);
    } catch (e, st) {
      if (_isStale(generation)) return;
      _hasMore = false;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final api = _api;
    final pool = _pool;
    if (_isLoadingMore || !_hasMore || api == null || pool == null) return;
    final generation = _generation;
    _isLoadingMore = true;
    try {
      final batch = await pool.next(api, _pageSize);
      if (_isStale(generation)) return;
      final existing = state.valueOrNull ?? [];
      final existingIds = existing.map((b) => b.bookId).toSet();
      final newBooks = batch.books
          .where((b) => !existingIds.contains(b.bookId))
          .toList();
      // 无新书（含耗尽后的轮转批次）即终止，避免列表末尾反复触发加载
      if (newBooks.isEmpty || batch.exhausted) _hasMore = false;
      state = AsyncValue.data([...existing, ...newBooks]);
    } catch (e) {
      debugPrint('WeRead recommend loadMore failed: $e');
      if (_isStale(generation)) return;
      // 停止自动续页（下拉刷新可重来），并通知 UI 移除加载指示
      _hasMore = false;
      state = AsyncValue.data(state.valueOrNull ?? []);
    } finally {
      if (generation == _generation) _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    _generation++;
    _pool = null;
    _isLoadingMore = false;
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
