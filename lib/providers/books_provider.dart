import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../models/display_book.dart';
import '../services/storage_service.dart';
import 'zlibrary_provider.dart';
import 'weread_provider.dart';

// ── Search ──────────────────────────────────────────────────────────

class SearchParams {
  final String? query;
  final int? yearFrom;
  final int? yearTo;
  final List<String>? languages;
  final List<String>? extensions;
  final String? order;
  final int limit;

  SearchParams({
    this.query,
    this.yearFrom,
    this.yearTo,
    this.languages,
    this.extensions,
    this.order,
    this.limit = 20,
  });
}

class SearchState {
  final List<Book> books;
  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasSearched;
  final String? error;

  const SearchState({
    this.books = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasSearched = false,
    this.error,
  });

  SearchState copyWith({
    List<Book>? books,
    int? currentPage,
    int? totalPages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasSearched,
    String? error,
  }) {
    return SearchState(
      books: books ?? this.books,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasSearched: hasSearched ?? this.hasSearched,
      error: error,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final ZLibraryApi _api;
  final Ref _ref;
  SearchParams? _lastParams;
  int _requestId = 0;

  SearchNotifier(this._api, this._ref) : super(const SearchState());

  /// 统一取数入口，search / loadMore 共用。
  Future<ApiResponse<List<Book>>> _fetch(SearchParams params, int page) async {
    return _api.search(
      message: params.query,
      yearFrom: params.yearFrom,
      yearTo: params.yearTo,
      languages: params.languages,
      extensions: params.extensions,
      order: params.order,
      page: page,
      limit: params.limit,
    );
  }

  Future<void> search(SearchParams params) async {
    final requestId = ++_requestId;
    _lastParams = params;
    state = const SearchState(isLoading: true, hasSearched: true);

    try {
      final response = await _fetch(params, 1);
      if (requestId != _requestId) return;
      if (!response.success) {
        throw StateError(response.error ?? 'Search failed');
      }

      final totalPages = response.meta?['total_pages'] ?? 1;
      state = SearchState(
        books: response.data ?? [],
        currentPage: 1,
        totalPages: totalPages is int ? totalPages : 1,
        hasSearched: true,
      );
    } catch (e) {
      if (requestId != _requestId) return;
      state = SearchState(hasSearched: true, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (_lastParams == null ||
        state.isLoadingMore ||
        state.currentPage >= state.totalPages) {
      return;
    }

    final nextPage = state.currentPage + 1;
    final requestId = _requestId;
    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _fetch(_lastParams!, nextPage);
      if (requestId != _requestId) return;
      if (!response.success) {
        throw StateError(response.error ?? 'Search failed');
      }

      state = state.copyWith(
        books: [...state.books, ...response.data ?? []],
        currentPage: nextPage,
        isLoadingMore: false,
      );
    } catch (e) {
      if (requestId != _requestId) return;
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  void reset() {
    _requestId++;
    _lastParams = null;
    state = const SearchState();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
  ref,
) {
  final api = ref.watch(zlibraryApiProvider);
  return SearchNotifier(api, ref);
});

// ── Book Details ────────────────────────────────────────────────────

final bookDetailsProvider = FutureProvider.family<Book, BookIdentifier>((
  ref,
  identifier,
) async {
  final api = ref.watch(zlibraryApiProvider);
  final response = await api.getBookInfo(identifier.bookId, identifier.hashId);
  if (!response.success) {
    throw StateError(response.error ?? 'Failed to load book details');
  }
  final book = response.data;
  if (book == null) {
    throw StateError('Book details response did not contain a book');
  }
  return book;
});

class BookIdentifier {
  final String bookId;
  final String hashId;

  BookIdentifier(this.bookId, this.hashId);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookIdentifier &&
        other.bookId == bookId &&
        other.hashId == hashId;
  }

  @override
  int get hashCode => bookId.hashCode ^ hashId.hashCode;
}

// ── Book Lists ──────────────────────────────────────────────────────

final mostPopularBooksProvider = FutureProvider<List<Book>>((ref) async {
  final api = ref.watch(zlibraryApiProvider);
  final response = await api.getMostPopular();
  return response.data ?? [];
});

final recommendedBooksProvider = FutureProvider<List<Book>>((ref) async {
  final api = ref.watch(zlibraryApiProvider);
  final response = await api.getUserRecommended();
  return response.data ?? [];
});

/// 首页混合推荐：并发拉 z站 + WeRead，合并为 DisplayBook 列表。
/// z站 失败/未登录时 graceful fallback 到仅 WeRead。
final homeRecommendedProvider = Provider<AsyncValue<List<DisplayBook>>>((ref) {
  final zlibAsync = ref.watch(recommendedBooksProvider);
  final wereadAsync = ref.watch(wereadRecommendProvider);

  // 两个来源独立，任一成功即显示
  final zlibBooks =
      zlibAsync
          .whenData((books) => books.map((b) => b.toDisplay()).toList())
          .valueOrNull ??
      <DisplayBook>[];

  final wereadBooks =
      wereadAsync
          .whenData((books) => books.map((b) => b.toDisplay()).toList())
          .valueOrNull ??
      <DisplayBook>[];

  if (zlibAsync is AsyncLoading && wereadAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data([...zlibBooks, ...wereadBooks]);
});

final recentBooksProvider = FutureProvider<List<Book>>((ref) async {
  final api = ref.watch(zlibraryApiProvider);
  final response = await api.getRecently();
  return response.data ?? [];
});

// ── Saved Books ─────────────────────────────────────────────────────

class SavedBooksNotifier extends StateNotifier<AsyncValue<List<Book>>> {
  final ZLibraryApi _api;
  final StorageService _storage;

  SavedBooksNotifier(this._api, this._storage)
    : super(const AsyncValue.loading()) {
    loadSavedBooks();
  }

  Future<void> loadSavedBooks() async {
    state = const AsyncValue.loading();

    try {
      const pageSize = 100;
      final books = <Book>[];
      final seen = <int>{};
      for (var page = 1; page <= 100; page++) {
        final response = await _api.getUserSaved(page: page, limit: pageSize);
        if (!response.success) {
          throw StateError(response.error ?? 'Could not load saved books');
        }
        final batch = response.data ?? <Book>[];
        final before = seen.length;
        for (final book in batch) {
          if (seen.add(book.id)) books.add(book);
        }
        final totalPages = int.tryParse(
          response.meta?['total_pages']?.toString() ?? '',
        );
        if ((totalPages != null && page >= totalPages) ||
            batch.length < pageSize ||
            seen.length == before) {
          break;
        }
      }
      state = AsyncValue.data(books);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> saveBook(String bookId) async {
    try {
      final response = await _api.saveBook(bookId);
      if (!response.success) return false;
      await _storage.addFavorite(bookId);
      await loadSavedBooks();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> unsaveBook(String bookId) async {
    try {
      final response = await _api.unsaveUserBook(bookId);
      if (!response.success) return false;
      await _storage.removeFavorite(bookId);
      await loadSavedBooks();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final savedBooksProvider =
    StateNotifierProvider<SavedBooksNotifier, AsyncValue<List<Book>>>((ref) {
      final api = ref.watch(zlibraryApiProvider);
      final storage = ref.watch(storageServiceProvider);
      return SavedBooksNotifier(api, storage);
    });

// ── Downloaded Books ────────────────────────────────────────────────

final downloadedBooksProvider = FutureProvider<List<Book>>((ref) async {
  final api = ref.watch(zlibraryApiProvider);
  final response = await api.getUserDownloaded(limit: 100);
  return response.data ?? [];
});

// ── Favorites Check ─────────────────────────────────────────────────

final isBookFavoritedProvider = FutureProvider.family<bool, String>((
  ref,
  bookId,
) async {
  final storage = ref.watch(storageServiceProvider);
  return await storage.isFavorite(bookId);
});
