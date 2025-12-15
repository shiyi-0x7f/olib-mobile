import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _keyFavorites = 'favorite_books';
  static const String _keyDownloads = 'downloaded_books';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyDownloadPath = 'download_path';
  static const String _keyDownloadHistory = 'download_history';

  /// Save favorite book IDs
  Future<void> saveFavorites(List<String> bookIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyFavorites,
      bookIds,
    );
  }

  /// Get favorite book IDs
  Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyFavorites) ?? [];
  }

  /// Add book to favorites
  Future<void> addFavorite(String bookId) async {
    final favorites = await getFavorites();
    if (!favorites.contains(bookId)) {
      favorites.add(bookId);
      await saveFavorites(favorites);
    }
  }

  /// Remove book from favorites
  Future<void> removeFavorite(String bookId) async {
    final favorites = await getFavorites();
    favorites.remove(bookId);
    await saveFavorites(favorites);
  }

  /// Check if book is favorited
  Future<bool> isFavorite(String bookId) async {
    final favorites = await getFavorites();
    return favorites.contains(bookId);
  }

  /// Save downloaded book info
  Future<void> saveDownloadedBook(Map<String, dynamic> bookInfo) async {
    final prefs = await SharedPreferences.getInstance();
    final downloads = prefs.getStringList(_keyDownloads) ?? [];
    // Store as JSON string
    downloads.add(bookInfo.toString());
    await prefs.setStringList(_keyDownloads, downloads);
  }

  /// Get theme mode (0: system, 1: light, 2: dark)
  Future<int> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyThemeMode) ?? 0;
  }

  /// Set theme mode
  Future<void> setThemeMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode);
  }

  /// Get download path
  Future<String?> getDownloadPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDownloadPath);
  }

  /// Set download path
  Future<void> setDownloadPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDownloadPath, path);
  }

  // ===== Download History Methods =====
  
  /// Add book to download history
  /// Stores: {bookId: {title, author, filePath, downloadTime}}
  Future<void> addToDownloadHistory(String bookId, String title, String? author, String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_keyDownloadHistory) ?? '{}';
    final history = Map<String, dynamic>.from(jsonDecode(historyJson));
    
    history[bookId] = {
      'title': title,
      'author': author,
      'filePath': filePath,
      'downloadTime': DateTime.now().toIso8601String(),
    };
    
    await prefs.setString(_keyDownloadHistory, jsonEncode(history));
  }

  /// Get all download history
  Future<Map<String, dynamic>> getDownloadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_keyDownloadHistory) ?? '{}';
    return Map<String, dynamic>.from(jsonDecode(historyJson));
  }

  /// Check if book was previously downloaded
  Future<bool> isBookDownloaded(String bookId) async {
    final history = await getDownloadHistory();
    return history.containsKey(bookId);
  }

  /// Get downloaded file path for a book
  Future<String?> getDownloadedFilePath(String bookId) async {
    final history = await getDownloadHistory();
    if (history.containsKey(bookId)) {
      return history[bookId]['filePath'] as String?;
    }
    return null;
  }

  /// Remove book from download history
  Future<void> removeFromDownloadHistory(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_keyDownloadHistory) ?? '{}';
    final history = Map<String, dynamic>.from(jsonDecode(historyJson));
    
    history.remove(bookId);
    
    await prefs.setString(_keyDownloadHistory, jsonEncode(history));
  }
}
