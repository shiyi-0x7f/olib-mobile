import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../services/storage_service.dart';
import 'zlibrary_provider.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

enum DownloadStatus { pending, downloading, completed, error }

class DownloadTask {
  final String id;
  final Book book;
  final double progress;
  final DownloadStatus status;
  final String? filePath;
  final String? error;

  const DownloadTask({
    required this.id,
    required this.book,
    this.progress = 0.0,
    this.status = DownloadStatus.pending,
    this.filePath,
    this.error,
  });

  DownloadTask copyWith({
    String? id,
    Book? book,
    double? progress,
    DownloadStatus? status,
    String? filePath,
    String? error,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      book: book ?? this.book,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
    );
  }
}

class DownloadNotifier extends StateNotifier<List<DownloadTask>> {
  final ZLibraryApi _api;
  final StorageService _storage;
  final Map<String, CancelToken> _cancelTokens = {};

  DownloadNotifier(this._api, this._storage) : super([]) {
    // Load persisted download history on initialization
    _loadDownloadHistory();
  }

  /// Load completed downloads from storage on app startup
  Future<void> _loadDownloadHistory() async {
    try {
      final history = await _storage.getDownloadHistory();
      final List<DownloadTask> loadedTasks = [];
      
      for (final entry in history.entries) {
        final bookId = entry.key;
        final data = entry.value as Map<String, dynamic>;
        
        final filePath = data['filePath'] as String?;
        
        // Only add if file still exists
        if (filePath != null) {
          final file = File(filePath);
          final fileExists = await file.exists();
          
          // Create a minimal Book object from stored data
          final book = Book(
            id: int.tryParse(bookId) ?? 0,
            title: data['title'] as String? ?? 'Unknown',
            author: data['author'] as String?,
            cover: data['cover'] as String?,
            extension: data['extension'] as String?,
          );
          
          loadedTasks.add(DownloadTask(
            id: bookId,
            book: book,
            progress: 1.0,
            status: fileExists ? DownloadStatus.completed : DownloadStatus.error,
            filePath: filePath,
            error: fileExists ? null : 'File not found',
          ));
        }
      }
      
      // Update state with loaded tasks
      if (loadedTasks.isNotEmpty) {
        state = loadedTasks;
      }
    } catch (e) {
      // Ignore errors during loading, start with empty state
    }
  }

  /// Check if we should use MediaStore API (Android 10+)
  bool get _shouldUseMediaStore {
    if (!Platform.isAndroid) return false;
    // Android 10 is API 29
    // We always use MediaStore on Android since downloadsfolder handles version checks internally
    return true;
  }

  /// Check if file already exists for a book
  /// Returns the file path if exists, null otherwise
  Future<String?> checkFileExists(Book book) async {
    // First check download history
    final historyPath = await _storage.getDownloadedFilePath(book.id.toString());
    if (historyPath != null) {
      final file = File(historyPath);
      if (await file.exists()) {
        return historyPath;
      }
    }

    // Also check if file exists in download directory (may have been downloaded elsewhere)
    final savePath = await _buildSavePath(book);
    if (savePath != null) {
      final file = File(savePath);
      if (await file.exists()) {
        return savePath;
      }
    }

    return null;
  }

  /// Build a safe filename for a book
  String _buildSafeFileName(Book book) {
    String safeTitle = book.title.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), '').trim();
    
    if (safeTitle.isEmpty) {
      safeTitle = 'book_${book.id}';
      if (book.author != null && book.author!.isNotEmpty) {
        final safeAuthor = book.author!.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), '').trim();
        if (safeAuthor.isNotEmpty) {
          safeTitle = '$safeAuthor - $safeTitle';
        }
      }
    }
    
    final ext = book.extension ?? 'epub';
    return '$safeTitle.$ext';
  }

  /// Build save path for a book (for non-MediaStore platforms)
  Future<String?> _buildSavePath(Book book) async {
    try {
      String baseDir;
      final customPath = await _storage.getDownloadPath();
      
      if (customPath != null && customPath.isNotEmpty && !Platform.isIOS && !_shouldUseMediaStore) {
        baseDir = customPath;
      } else {
        final appDocDir = await getApplicationDocumentsDirectory();
        baseDir = appDocDir.path;
      }
      
      final fileName = _buildSafeFileName(book);
      return '$baseDir/$fileName';
    } catch (e) {
      return null;
    }
  }

  /// Start a download.
  ///
  /// 默认走 ZLibraryApi（用户自己账号查 URL + 下载）。
  /// [presetUrl] 传入时跳过 URL 获取，直接用此 URL 下文件 —
  /// 用于 AI 寻书结果走 backend 拿到的签名 URL，不消耗用户自己的 z站
  /// 配额（但消耗已在 backend 端记账的免费下载配额）。
  Future<void> startDownload(Book book, {String? presetUrl}) async {
    final id = book.id.toString();

    // Check if already downloading
    if (state.any((t) => t.id == id && t.status == DownloadStatus.downloading)) {
      return;
    }

    // Add or update task to pending
    _updateOrAddTask(DownloadTask(id: id, book: book, status: DownloadStatus.pending));

    try {
      final fileName = _buildSafeFileName(book);
      String finalPath;

      // Determine download directory
      if (Platform.isAndroid) {
        // Request MANAGE_EXTERNAL_STORAGE permission for Android 11+
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        
        if (androidInfo.version.sdkInt >= 30) {
          // Android 11+: Request full storage access
          if (!await Permission.manageExternalStorage.isGranted) {
            final status = await Permission.manageExternalStorage.request();
            if (!status.isGranted) {
              throw Exception("需要文件访问权限才能下载。请在设置中授予权限。");
            }
          }
        } else if (androidInfo.version.sdkInt >= 23) {
          // Android 6-10: Request regular storage permission
          if (!await Permission.storage.isGranted) {
            final status = await Permission.storage.request();
            if (!status.isGranted) {
              throw Exception("需要存储权限才能下载。");
            }
          }
        }
        
        // Use public Downloads folder
        final downloadsDir = Directory('/storage/emulated/0/Download/Olib');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        finalPath = '${downloadsDir.path}/$fileName';
      } else if (Platform.isIOS) {
        // iOS: Use documents directory
        final appDocDir = await getApplicationDocumentsDirectory();
        finalPath = '${appDocDir.path}/$fileName';
      } else {
        // Desktop: Use custom path or documents
        String baseDir;
        final customPath = await _storage.getDownloadPath();
        
        if (customPath != null && customPath.isNotEmpty) {
          baseDir = customPath;
          final dir = Directory(baseDir);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
        } else {
          final appDocDir = await getApplicationDocumentsDirectory();
          baseDir = appDocDir.path;
        }
        finalPath = '$baseDir/$fileName';
      }

      // Update to downloading
      _updateTask(id, (t) => t.copyWith(status: DownloadStatus.downloading, progress: 0.0));

      // Create cancel token
      final cancelToken = CancelToken();
      _cancelTokens[id] = cancelToken;

      // Start download directly to final path
      if (presetUrl != null) {
        // AI 寻书路径：backend 已签发 URL，直接 stream 到本地
        // 用独立 Dio，不带 z站 cookie / auth
        final dio = Dio();
        await dio.download(
          presetUrl,
          finalPath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              final progress = received / total;
              _updateTask(id, (t) => t.copyWith(progress: progress));
            }
          },
          cancelToken: cancelToken,
        );
      } else {
        // 默认路径：用户自己 z站 账号查 URL + 下载
        await _api.downloadBook(
          book.id.toString(),
          book.hash ?? '',
          finalPath,
          onProgress: (received, total) {
            if (total != -1) {
              final progress = received / total;
              _updateTask(id, (t) => t.copyWith(progress: progress));
            }
          },
          cancelToken: cancelToken,
        );
      }

      // Complete
      _updateTask(id, (t) => t.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        filePath: finalPath,
      ));
      
      // Save to download history (with cover and extension for persistence)
      await _storage.addToDownloadHistory(
        book.id.toString(),
        book.title,
        book.author,
        finalPath,
        cover: book.cover,
        extension: book.extension,
      );
      
      _cancelTokens.remove(id);

    } catch (e) {
      _updateTask(id, (t) => t.copyWith(
        status: DownloadStatus.error,
        error: e.toString(),
      ));
      _cancelTokens.remove(id);
    }
  }
  
  /// Cancel a download
  void cancelDownload(String id) {
    if (_cancelTokens.containsKey(id)) {
      _cancelTokens[id]?.cancel();
      _cancelTokens.remove(id);
      
      // Update state
      _updateTask(id, (t) => t.copyWith(
        status: DownloadStatus.error, 
        error: 'Cancelled by user',
      ));
    }
  }

  /// Remove task and delete file
  Future<void> removeTask(String id) async {
    final task = state.firstWhere((t) => t.id == id, orElse: () => throw Exception("Task not found"));
    
    // Delete file if exists
    if (task.filePath != null) {
      final file = File(task.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    // Remove from persistent storage
    await _storage.removeFromDownloadHistory(id);
    
    // Remove from state
    state = state.where((t) => t.id != id).toList();
  }

  void _updateOrAddTask(DownloadTask task) {
    if (state.any((t) => t.id == task.id)) {
      state = state.map((t) => t.id == task.id ? task : t).toList();
    } else {
      state = [...state, task];
    }
  }

  void _updateTask(String id, DownloadTask Function(DownloadTask) updater) {
    state = state.map((t) {
      if (t.id == id) {
        return updater(t);
      }
      return t;
    }).toList();
  }
}

final downloadProvider = StateNotifierProvider<DownloadNotifier, List<DownloadTask>>((ref) {
  final api = ref.watch(zlibraryApiProvider);
  final storage = ref.watch(storageServiceProvider);
  return DownloadNotifier(api, storage);
});
