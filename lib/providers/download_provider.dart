import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../services/storage_service.dart';
import 'zlibrary_provider.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

enum DownloadStatus { pending, downloading, completed, error, cancelled }

class DownloadTask {
  final String id;
  final Book book;
  final double progress;
  final DownloadStatus status;
  final String? filePath;
  final String? error;
  final DateTime? downloadedAt;
  final int? fileSize;
  final bool needsFreshLink;
  final bool missingFile;

  /// 用户自己 Z 站账号当日下载次数已用尽导致的失败。
  final bool quotaExceeded;

  bool get canRetry =>
      (status == DownloadStatus.error || status == DownloadStatus.cancelled) &&
      !needsFreshLink &&
      !missingFile &&
      book.id > 0 &&
      (book.hash?.isNotEmpty ?? false);

  const DownloadTask({
    required this.id,
    required this.book,
    this.progress = 0.0,
    this.status = DownloadStatus.pending,
    this.filePath,
    this.error,
    this.downloadedAt,
    this.fileSize,
    this.needsFreshLink = false,
    this.missingFile = false,
    this.quotaExceeded = false,
  });

  DownloadTask copyWith({
    String? id,
    Book? book,
    double? progress,
    DownloadStatus? status,
    String? filePath,
    String? error,
    DateTime? downloadedAt,
    int? fileSize,
    bool? needsFreshLink,
    bool? missingFile,
    bool? quotaExceeded,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      book: book ?? this.book,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      fileSize: fileSize ?? this.fileSize,
      needsFreshLink: needsFreshLink ?? this.needsFreshLink,
      missingFile: missingFile ?? this.missingFile,
      quotaExceeded: quotaExceeded ?? this.quotaExceeded,
    );
  }
}

class DownloadNotifier extends StateNotifier<List<DownloadTask>> {
  final ZLibraryApi _api;
  final StorageService _storage;
  final Map<String, CancelToken> _cancelTokens = {};
  late final Future<void> ready;

  DownloadNotifier(this._api, this._storage) : super([]) {
    // Load persisted download history on initialization
    ready = _loadDownloadHistory();
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

          loadedTasks.add(
            DownloadTask(
              id: bookId,
              book: book,
              progress: 1.0,
              status: fileExists
                  ? DownloadStatus.completed
                  : DownloadStatus.error,
              filePath: filePath,
              error: fileExists ? null : 'File not found',
              downloadedAt: DateTime.tryParse(
                data['downloadTime']?.toString() ?? '',
              ),
              fileSize: fileExists ? await file.length() : null,
              missingFile: !fileExists,
            ),
          );
        }
      }

      // Update state with loaded tasks
      if (loadedTasks.isNotEmpty) {
        state = loadedTasks;
      }
    } catch (e) {
      // History failure should not break new downloads.
      debugPrint('Could not load download history: ${e.runtimeType}');
    }
  }

  /// 下载保存目录（各平台统一入口，下载与「文件已存在」判断共用）。
  Future<String> _resolveSaveDir() async {
    if (Platform.isAndroid) return (await _androidDownloadDir()).path;
    if (Platform.isIOS) return (await getApplicationDocumentsDirectory()).path;

    final customPath = await _storage.getDownloadPath();
    if (customPath != null && customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      return customPath;
    }
    return (await getApplicationDocumentsDirectory()).path;
  }

  /// Android 公共下载目录 `<当前用户存储>/Download/Olib`。
  ///
  /// 不能写死 `/storage/emulated/0`：应用分身 / 第二空间 / 工作资料运行在
  /// 其他用户空间，访问 0 号用户存储会被系统拒绝（PathAccessException）。
  /// 公共目录不可用时退回应用专属外部目录（无需任何权限）。
  Future<Directory> _androidDownloadDir() async {
    // 形如 /storage/emulated/<user>/Android/data/<pkg>/files
    final appExternal = await getExternalStorageDirectory();
    if (appExternal == null) return getApplicationDocumentsDirectory();

    final marker = appExternal.path.indexOf('/Android/');
    if (marker > 0) {
      final publicDir = Directory(
        '${appExternal.path.substring(0, marker)}/Download/Olib',
      );
      try {
        if (!await publicDir.exists()) {
          await publicDir.create(recursive: true);
        }
        return publicDir;
      } on FileSystemException catch (e) {
        debugPrint('Public download dir unavailable, fallback: $e');
      }
    }
    return appExternal;
  }

  /// Check if file already exists for a book
  /// Returns the file path if exists, null otherwise
  Future<String?> checkFileExists(Book book) async {
    // First check download history
    final historyPath = await _storage.getDownloadedFilePath(
      book.id.toString(),
    );
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
    String safeTitle = book.title
        .replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), '')
        .trim();

    if (safeTitle.isEmpty) {
      safeTitle = 'book_${book.id}';
      if (book.author != null && book.author!.isNotEmpty) {
        final safeAuthor = book.author!
            .replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), '')
            .trim();
        if (safeAuthor.isNotEmpty) {
          safeTitle = '$safeAuthor - $safeTitle';
        }
      }
    }

    final cleanExtension = (book.extension ?? 'epub')
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toLowerCase();
    final ext = cleanExtension.isEmpty ? 'epub' : cleanExtension;
    return '$safeTitle - ${book.id}.$ext';
  }

  /// Build save path for a book (for non-MediaStore platforms)
  Future<String?> _buildSavePath(Book book) async {
    try {
      final baseDir = await _resolveSaveDir();
      return '$baseDir/${_buildSafeFileName(book)}';
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
    if (state.any(
      (t) =>
          t.id == id &&
          (t.status == DownloadStatus.downloading ||
              t.status == DownloadStatus.pending),
    )) {
      return;
    }

    // Add or update task to pending
    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;
    _updateOrAddTask(
      DownloadTask(
        id: id,
        book: book,
        status: DownloadStatus.pending,
        needsFreshLink: presetUrl != null,
      ),
    );

    String? temporaryPath;
    try {
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
      }

      final finalPath =
          '${await _resolveSaveDir()}/${_buildSafeFileName(book)}';

      if (cancelToken.isCancelled) return;

      temporaryPath =
          '$finalPath.${DateTime.now().microsecondsSinceEpoch}.part';

      // Update to downloading
      _updateTask(
        id,
        (t) => t.copyWith(status: DownloadStatus.downloading, progress: 0.0),
      );

      // Write to a task-specific temporary file so cancellation never leaves
      // a partial book under its final name.
      final alreadyExists = await File(finalPath).exists();
      if (!alreadyExists && presetUrl != null) {
        // AI 寻书路径：backend 已签发 URL，直接 stream 到本地
        // 用独立 Dio，不带 z站 cookie / auth
        final dio = Dio();
        await dio.download(
          presetUrl,
          temporaryPath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              final progress = received / total;
              _updateTask(id, (t) => t.copyWith(progress: progress));
            }
          },
          cancelToken: cancelToken,
        );
      } else if (!alreadyExists) {
        // 默认路径：用户自己 z站 账号查 URL + 下载
        try {
          await _api.downloadBook(
            book.id.toString(),
            book.hash ?? '',
            temporaryPath,
            onProgress: (received, total) {
              if (total != -1) {
                final progress = received / total;
                _updateTask(id, (t) => t.copyWith(progress: progress));
              }
            },
            cancelToken: cancelToken,
          );
        } on DownloadLimitReachedException {
          rethrow;
        } catch (e) {
          // Z 站额度用尽的返回形态不稳定，失败后再查一次资料兜底识别
          if (!cancelToken.isCancelled && await _isOwnQuotaExhausted()) {
            throw DownloadLimitReachedException();
          }
          rethrow;
        }
      }

      if (cancelToken.isCancelled) return;
      if (identical(_cancelTokens[id], cancelToken)) _cancelTokens.remove(id);

      if (await File(temporaryPath).exists()) {
        await File(temporaryPath).rename(finalPath);
      }

      final completedAt = DateTime.now();
      final fileSize = await File(finalPath).length();
      // Save to download history (with cover and extension for persistence)
      await _storage.addToDownloadHistory(
        book.id.toString(),
        book.title,
        book.author,
        finalPath,
        cover: book.cover,
        extension: book.extension,
      );
      _updateTask(
        id,
        (t) => t.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          filePath: finalPath,
          downloadedAt: completedAt,
          fileSize: fileSize,
        ),
      );
    } on DownloadLimitReachedException catch (e) {
      if (!cancelToken.isCancelled) {
        _updateTask(
          id,
          (t) => t.copyWith(
            status: DownloadStatus.error,
            error: e.toString(),
            quotaExceeded: true,
          ),
        );
      }
    } catch (e) {
      if (!cancelToken.isCancelled) {
        _updateTask(
          id,
          (t) => t.copyWith(status: DownloadStatus.error, error: e.toString()),
        );
      }
    } finally {
      if (temporaryPath != null) {
        final partial = File(temporaryPath);
        try {
          if (await partial.exists()) await partial.delete();
        } catch (error) {
          debugPrint('Could not remove partial download: ${error.runtimeType}');
        }
      }
      if (identical(_cancelTokens[id], cancelToken)) _cancelTokens.remove(id);
    }
  }

  Future<bool> _isOwnQuotaExhausted() async {
    try {
      final profile = await _api.getProfile();
      return profile.success &&
          profile.data != null &&
          profile.data!.downloadsLeft <= 0;
    } catch (e) {
      debugPrint('Could not check download quota: ${e.runtimeType}');
      return false;
    }
  }

  /// Cancel a download
  void cancelDownload(String id) {
    final token = _cancelTokens[id];
    if (token == null) return;
    token.cancel();
    _updateTask(id, (t) => t.copyWith(status: DownloadStatus.cancelled));
  }

  void markMissingFile(String id) {
    _updateTask(
      id,
      (task) => task.copyWith(
        status: DownloadStatus.error,
        missingFile: true,
        error: 'File not found',
      ),
    );
  }

  /// Remove task and delete file
  Future<void> removeTask(String id) async {
    cancelDownload(id);
    final task = state.firstWhere(
      (t) => t.id == id,
      orElse: () => throw Exception("Task not found"),
    );

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

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, List<DownloadTask>>((ref) {
      final api = ref.watch(zlibraryApiProvider);
      final storage = ref.watch(storageServiceProvider);
      return DownloadNotifier(api, storage);
    });
