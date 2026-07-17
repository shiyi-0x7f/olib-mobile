import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hive_service.dart';
import '../services/weread/weread_api.dart';
import '../services/weread/weread_models.dart';

// ═══════════════════════════════════════════════════════════════════
// API Key 管理
// ═══════════════════════════════════════════════════════════════════

const _kWereadApiKey = 'WEREAD_API_KEY';

/// WeRead API Key 状态 — 读写 Hive settings box
class WereadApiKeyNotifier extends StateNotifier<String?> {
  WereadApiKeyNotifier() : super(null) {
    _load();
  }

  void _load() {
    final box = HiveService.settingsBox;
    state = box.get(_kWereadApiKey) as String?;
  }

  Future<void> setApiKey(String key) async {
    final box = HiveService.settingsBox;
    await box.put(_kWereadApiKey, key);
    state = key;
  }

  Future<void> clearApiKey() async {
    final box = HiveService.settingsBox;
    await box.delete(_kWereadApiKey);
    state = null;
  }
}

final wereadApiKeyProvider =
    StateNotifierProvider<WereadApiKeyNotifier, String?>((ref) {
  return WereadApiKeyNotifier();
});

/// 是否已配置 WeRead API Key
final isWereadConfiguredProvider = Provider<bool>((ref) {
  final key = ref.watch(wereadApiKeyProvider);
  return key != null && key.isNotEmpty;
});

// ═══════════════════════════════════════════════════════════════════
// API 实例
// ═══════════════════════════════════════════════════════════════════

/// WereadApi 实例 — apiKey 变化时自动重建
final wereadApiProvider = Provider<WereadApi?>((ref) {
  final key = ref.watch(wereadApiKeyProvider);
  if (key == null || key.isEmpty) return null;
  return WereadApi(apiKey: key);
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

/// 笔记概览 — 拉取所有页（使用 lastSort 游标自动翻页）
final wereadNotebooksProvider =
    FutureProvider<NotebooksResponse?>((ref) async {
  final api = ref.watch(wereadApiProvider);
  if (api == null) return null;

  // First page to get totalNoteCount / totalBookCount
  final firstPage = await api.notebooks(count: 100);
  final allBooks = List<NotebookBook>.from(firstPage.books);

  // Auto-paginate if there are more
  if (firstPage.hasMoreResults && allBooks.isNotEmpty) {
    int? lastSort = allBooks.last.sort;
    while (true) {
      final page = await api.notebooks(count: 100, lastSort: lastSort);
      if (page.books.isEmpty) break;
      allBooks.addAll(page.books);
      if (!page.hasMoreResults) break;
      lastSort = page.books.last.sort;
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
class WereadRecommendNotifier extends StateNotifier<AsyncValue<List<RecommendBook>>> {
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
      final resp = await _api!.recommend(count: _initialCount);
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
      final resp = await _api!.recommend(count: _pageSize, maxIdx: _nextOffset);
      if (resp.books.isEmpty) {
        _hasMore = false;
      } else {
        final existing = state.valueOrNull ?? [];
        final existingIds = existing.map((b) => b.bookId).toSet();
        final newBooks = resp.books.where((b) => !existingIds.contains(b.bookId)).toList();
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
    StateNotifierProvider<WereadRecommendNotifier, AsyncValue<List<RecommendBook>>>((ref) {
  final api = ref.watch(wereadApiProvider);
  return WereadRecommendNotifier(api);
});

/// 用户资料概况
final wereadProfileProvider =
    FutureProvider<ProfileSummary?>((ref) async {
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
  final bool hasSearched;
  final String? error;

  const WereadSearchState({
    this.results = const [],
    this.isLoading = false,
    this.hasSearched = false,
    this.error,
  });

  WereadSearchState copyWith({
    List<SearchResultBook>? results,
    bool? isLoading,
    bool? hasSearched,
    String? error,
  }) {
    return WereadSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      hasSearched: hasSearched ?? this.hasSearched,
      error: error,
    );
  }
}

class WereadSearchNotifier extends StateNotifier<WereadSearchState> {
  final WereadApi? _api;

  WereadSearchNotifier(this._api) : super(const WereadSearchState());

  Future<void> search(String keyword) async {
    if (_api == null || keyword.trim().isEmpty) return;

    state = state.copyWith(isLoading: true, hasSearched: true, error: null);

    try {
      final response = await _api!.search(keyword: keyword);
      final books = <SearchResultBook>[];
      for (final group in response.results) {
        books.addAll(group.books);
      }
      state = state.copyWith(results: books, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const WereadSearchState();
  }
}

final wereadSearchProvider =
    StateNotifierProvider<WereadSearchNotifier, WereadSearchState>((ref) {
  final api = ref.watch(wereadApiProvider);
  return WereadSearchNotifier(api);
});
