import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:android_intent_plus/android_intent.dart';

/// Check if platform supports opening folder in file manager
bool get canOpenFolder {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux || Platform.isAndroid;
}

/// Open the download folder in the system file manager
Future<bool> openDownloadFolder() async {
  try {
    if (Platform.isAndroid) {
      // Use Intent to open the Downloads folder in the system file manager
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: 'content://com.android.externalstorage.documents/document/primary%3ADownload%2FOlib',
          type: 'vnd.android.document/directory',
          flags: <int>[0x10000000], // FLAG_ACTIVITY_NEW_TASK
        );
        await intent.launch();
        return true;
      } catch (_) {
        // Fallback: try to open the general Downloads folder
        try {
          final intent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            data: 'content://com.android.externalstorage.documents/root/primary%3ADownload',
            type: 'vnd.android.document/root',
            flags: <int>[0x10000000],
          );
          await intent.launch();
          return true;
        } catch (_) {
          // Last fallback: open the system file manager app
          try {
            final intent = AndroidIntent(
              action: 'android.intent.action.MAIN',
              category: 'android.intent.category.APP_FILES',
              flags: <int>[0x10000000],
            );
            await intent.launch();
            return true;
          } catch (_) {
            return false;
          }
        }
      }
    } else if (Platform.isWindows) {

      // Get the actual Downloads folder on Windows
      final downloadsDir = await getDownloadsDirectory();
      final path = downloadsDir?.path ?? r'C:\Users\Public\Downloads';
      await Process.run('explorer', [path]);
      return true;
    } else if (Platform.isMacOS) {
      final downloadsDir = await getDownloadsDirectory();
      final path = downloadsDir?.path ?? '~/Downloads';
      await Process.run('open', [path]);
      return true;
    } else if (Platform.isLinux) {
      final downloadsDir = await getDownloadsDirectory();
      final path = downloadsDir?.path ?? '~/Downloads';
      await Process.run('xdg-open', [path]);
      return true;
    }
    return false;
  } catch (e) {
    debugPrint('Failed to open download folder: $e');
    return false;
  }
}

/// Open a file with the system default application
Future<bool> openFile(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      return false;
    }
    final result = await OpenFilex.open(filePath);
    return result.type == ResultType.done;
  } catch (e) {
    debugPrint('Failed to open file: $e');
    return false;
  }
}

/// Get file size as human-readable string
String formatFileSize(int bytes) {
  if (bytes > 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  } else if (bytes > 1024) {
    return '${(bytes / 1024).toStringAsFixed(2)} KB';
  } else {
    return '$bytes B';
  }
}

/// Build a safe filename for saving files
String buildSafeFileName(String name, {String? extension}) {
  String safeName = name.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), '').trim();
  if (safeName.isEmpty) {
    safeName = 'file_${DateTime.now().millisecondsSinceEpoch}';
  }
  if (extension != null && extension.isNotEmpty) {
    return '$safeName.$extension';
  }
  return safeName;
}
