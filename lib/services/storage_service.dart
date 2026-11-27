import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hive_service.dart';

/// Riverpod provider for StorageService (singleton)
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  static const String _keyFavorites = 'favorite_books';
  static const String _keyDownloads = 'downloaded_books';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyDownloadPath = 'download_path';
  static const String _keyDownloadHistory = 'download_history';

  /// Save favorite book IDs
  Future<void> saveFavorites(List<String> bookIds) async {
    await HiveService.settingsBox.put(_keyFavorites, bookIds);
  }

  /// Get favorite book IDs
  List<String> getFavoritesSync() {
    final data = HiveService.settingsBox.get(_keyFavorites);
    if (data == null) return [];
    return List<String>.from(data);
  }

  /// Get favorite book IDs (async for API compatibility)
  Future<List<String>> getFavorites() async {
    return getFavoritesSync();
  }

  /// Add book to favorites
  Future<void> addFavorite(String bookId) async {
    final favorites = getFavoritesSync();
    if (!favorites.contains(bookId)) {
      favorites.add(bookId);
      await saveFavorites(favorites);
    }
  }

  /// Remove book from favorites
  Future<void> removeFavorite(String bookId) async {
    final favorites = getFavoritesSync();
    favorites.remove(bookId);
    await saveFavorites(favorites);
  }

  /// Check if book is favorited
  Future<bool> isFavorite(String bookId) async {
    final favorites = getFavoritesSync();
    return favorites.contains(bookId);
  }

  /// Save downloaded book info
  Future<void> saveDownloadedBook(Map<String, dynamic> bookInfo) async {
    final data = HiveService.settingsBox.get(_keyDownloads);
    final downloads = data != null ? List<String>.from(data) : <String>[];
    downloads.add(bookInfo.toString());
    await HiveService.settingsBox.put(_keyDownloads, downloads);
  }

  /// Get theme mode (0: system, 1: light, 2: dark)
  Future<int> getThemeMode() async {
    return HiveService.settingsBox.get(_keyThemeMode, defaultValue: 0) as int;
  }

  /// Set theme mode
  Future<void> setThemeMode(int mode) async {
    await HiveService.settingsBox.put(_keyThemeMode, mode);
  }

  /// Get download path
  Future<String?> getDownloadPath() async {
    return HiveService.settingsBox.get(_keyDownloadPath) as String?;
  }

  /// Set download path
  Future<void> setDownloadPath(String path) async {
    await HiveService.settingsBox.put(_keyDownloadPath, path);
  }

  // ===== Download History Methods =====
  
  /// Add book to download history
  /// Stores: {bookId: {title, author, filePath, cover, extension, downloadTime}}
  Future<void> addToDownloadHistory(
    String bookId, 
    String title, 
    String? author, 
    String filePath, 
    {String? cover, String? extension}
  ) async {
    final historyJson = HiveService.settingsBox.get(_keyDownloadHistory, defaultValue: '{}') as String;
    final history = Map<String, dynamic>.from(jsonDecode(historyJson));
    
    history[bookId] = {
      'title': title,
      'author': author,
      'filePath': filePath,
      'cover': cover,
      'extension': extension,
      'downloadTime': DateTime.now().toIso8601String(),
    };
    
    await HiveService.settingsBox.put(_keyDownloadHistory, jsonEncode(history));
  }

  /// Get all download history
  Future<Map<String, dynamic>> getDownloadHistory() async {
    final historyJson = HiveService.settingsBox.get(_keyDownloadHistory, defaultValue: '{}') as String;
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
    final historyJson = HiveService.settingsBox.get(_keyDownloadHistory, defaultValue: '{}') as String;
    final history = Map<String, dynamic>.from(jsonDecode(historyJson));
    
    history.remove(bookId);
    
    await HiveService.settingsBox.put(_keyDownloadHistory, jsonEncode(history));
  }
}
