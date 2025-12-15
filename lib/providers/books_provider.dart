import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../services/zlibrary_api.dart';
import '../services/storage_service.dart';
import 'zlibrary_provider.dart';

/// Search results provider (family for different queries)
final searchResultsProvider =
    FutureProvider.family<List<Book>, SearchParams>((ref, params) async {
  final api = ref.watch(zlibraryApiProvider);
  
  final response = await api.search(
    message: params.query,
    yearFrom: params.yearFrom,
    yearTo: params.yearTo,
    languages: params.languages,
    extensions: params.extensions,
    order: params.order,
    page: params.page,
    limit: params.limit,
  );

  final success = response['success'];
  if ((success == true || success == 1) && response.containsKey('books')) {
    final booksData = response['books'] as List<dynamic>;
    return booksData.map((json) => Book.fromJson(json)).toList();
  }
  
  return [];
});

class SearchParams {
  final String? query;
  final int? yearFrom;
  final int? yearTo;
  final List<String>? languages;
  final List<String>? extensions;
  final String? order;
  final int? page;
  final int? limit;

  SearchParams({
    this.query,
    this.yearFrom,
    this.yearTo,
    this.languages,
    this.extensions,
    this.order,
    this.page,
    this.limit,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchParams &&
        other.query == query &&
        other.yearFrom == yearFrom &&
        other.yearTo == yearTo &&
        _listEquals(other.languages, languages) &&
        _listEquals(other.extensions, extensions) &&
        other.order == order &&
        other.page == page &&
        other.limit == limit;
  }
  
  bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      query.hashCode ^
      yearFrom.hashCode ^
      yearTo.hashCode ^
      languages.hashCode ^
      extensions.hashCode ^
      order.hashCode ^
      page.hashCode ^
      limit.hashCode;
}

/// Book details provider
final bookDetailsProvider =
    FutureProvider.family<Book?, BookIdentifier>((ref, identifier) async {
  final api = ref.watch(zlibraryApiProvider);
  
  final response =
      await api.getBookInfo(identifier.bookId, identifier.hashId);

  final success = response['success'];
  if ((success == true || success == 1) && response.containsKey('book')) {
    return Book.fromJson(response['book']);
  }
  
  return null;
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

/// Most popular books provider
final mostPopularBooksProvider = FutureProvider<List<Book>>((ref) async {
  final api = ref.watch(zlibraryApiProvider);
  
  final response = await api.getMostPopular();

  final success = response['success'];
  if ((success == true || success == 1) && response.containsKey('books')) {
    final booksData = response['books'] as List<dynamic>;
    return booksData.map((json) => Book.fromJson(json)).toList();
  }
  
  return [];
});

/// User recommended books provider (for Trending section)
final recommendedBooksProvider = FutureProvider<List<Book>>((ref) async {
  final api = ref.watch(zlibraryApiProvider);
  
  final response = await api.getUserRecommended();

  final success = response['success'];
  if ((success == true || success == 1) && response.containsKey('books')) {
    final booksData = response['books'] as List<dynamic>;
    return booksData.map((json) => Book.fromJson(json)).toList();
  }
  
  return [];
});

/// Recently added books provider
final recentBooksProvider = FutureProvider<List<Book>>((ref) async {
  final api = ref.watch(zlibraryApiProvider);
  
  final response = await api.getRecently();

  final success = response['success'];
  if ((success == true || success == 1) && response.containsKey('books')) {
    final booksData = response['books'] as List<dynamic>;
    return booksData.map((json) => Book.fromJson(json)).toList();
  }
  
  return [];
});

/// Saved books state notifier
class SavedBooksNotifier extends StateNotifier<AsyncValue<List<Book>>> {
  final ZLibraryApi _api;
  final StorageService _storage;

  SavedBooksNotifier(this._api, this._storage) : super(const AsyncValue.loading()) {
    loadSavedBooks();
  }

  Future<void> loadSavedBooks() async {
    state = const AsyncValue.loading();
    
    try {
      final response = await _api.getUserSaved(limit: 100);
      
      final success = response['success'];
      if ((success == true || success == 1) && response.containsKey('books')) {
        final booksData = response['books'] as List<dynamic>;
        final books = booksData.map((json) => Book.fromJson(json)).toList();
        state = AsyncValue.data(books);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> saveBook(String bookId) async {
    try {
      await _api.saveBook(bookId);
      await _storage.addFavorite(bookId);
      await loadSavedBooks(); // Refresh list
    } catch (e) {
      // Handle error
    }
  }

  Future<void> unsaveBook(String bookId) async {
    try {
      await _api.unsaveUserBook(bookId);
      await _storage.removeFavorite(bookId);
      await loadSavedBooks(); // Refresh list
    } catch (e) {
      // Handle error
    }
  }
}

/// Saved books provider
final savedBooksProvider =
    StateNotifierProvider<SavedBooksNotifier, AsyncValue<List<Book>>>((ref) {
  final api = ref.watch(zlibraryApiProvider);
  final storage = StorageService();
  return SavedBooksNotifier(api, storage);
});

/// Downloaded books provider (similar to saved books)
final downloadedBooksProvider = FutureProvider<List<Book>>((ref) async {
  final api = ref.watch(zlibraryApiProvider);
  
  final response = await api.getUserDownloaded(limit: 100);

  final success = response['success'];
  if ((success == true || success == 1) && response.containsKey('books')) {
    final booksData = response['books'] as List<dynamic>;
    return booksData.map((json) => Book.fromJson(json)).toList();
  }
  
  return [];
});

/// Check if a book is favorited
final isBookFavoritedProvider =
    FutureProvider.family<bool, String>((ref, bookId) async {
  final storage = StorageService();
  return await storage.isFavorite(bookId);
});
