import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../models/display_book.dart';
import '../services/storage_service.dart';
import 'zlibrary_provider.dart';
import 'weread_provider.dart';

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
