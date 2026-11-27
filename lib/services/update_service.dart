import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'hive_service.dart';
import 'update/mindset_update.dart';

export 'update/mindset_update.dart' show UpdateLink;

/// Update checker service for checking new app versions.
///
/// 数据源：MindSet（www.11xy.cn）项目查更新接口，国内可直连（同电脑端 update_check.rs）：
/// - `update-check?current=` → 最新版本、是否强制更新、各版本说明、项目页（判定在服务端）
/// - `sources`               → 公开网盘下载链接（取不到只剩官网 / GitHub 按钮）
///
/// 网络请求 24h 一次，但每次的响应会连同当时的版本号缓存进 Hive：跳过请求时用缓存
/// 重新计算状态，保证强制更新在 App 重启后依然生效；App 升级后缓存自动作废。
class UpdateService {
  static const String _apiBase = 'https://www.11xy.cn/api/projects/olib-mobile';

  /// GitHub Releases 页：备用下载渠道
  static const String _githubReleasesUrl =
      'https://github.com/shiyi-0x7f/olib-mobile/releases/latest';

  static const String _lastCheckKey = 'last_update_check';
  static const String _dismissedVersionKey = 'dismissed_version';
  static const String _cachedUpdateKey = 'update_cached_mindset';
  static const String _cachedSourcesKey = 'update_cached_sources';
  static const String _cachedForVersionKey = 'update_cached_for_version';

  /// Check interval: once per day
  static const Duration _checkInterval = Duration(hours: 24);
  static const Duration _timeout = Duration(seconds: 10);

  /// Remote version info
  static String? latestVersion;
  static String? currentVersion;
  static String? downloadUrl = mindsetProjectPageUrl;
  static String? releaseUrl = _githubReleasesUrl;
  static Map<String, String>? changelog;
  static List<UpdateLink> links = const [];
  static bool forceUpdate = false;
  static bool hasUpdate = false;

  /// Flag to indicate app is blocked due to force update
  /// When true, search and download features should be disabled
  static bool isBlocked = false;

  /// Check for updates (non-blocking, silent on errors)
  ///
  /// 未到检查间隔时不发请求，直接用上次缓存的 Release 计算结果。
  static Future<bool> checkForUpdate({bool force = false}) async {
    try {
      currentVersion ??= (await PackageInfo.fromPlatform()).version;

      if (!force && !_shouldCheck()) {
        debugPrint(
          'UpdateService: Skipping request (checked recently), using cache',
        );
        return _applyCached();
      }

      final current = currentVersion!;
      // 查更新与下载渠道并发；渠道失败只记日志，退回官网 / GitHub 按钮
      final results = await Future.wait([
        _getJson(
          Uri.parse(
            '$_apiBase/update-check',
          ).replace(queryParameters: {'current': current}),
        ),
        _getJson(Uri.parse('$_apiBase/sources')).catchError((Object e) {
          debugPrint('UpdateService: sources failed: $e');
          return null;
        }),
      ]);
      final update = results[0];
      if (update is! Map<String, dynamic>) {
        debugPrint('UpdateService: unexpected update-check response');
        return _applyCached();
      }
      final sources = results[1] is List ? results[1] as List : const [];

      final box = HiveService.settingsBox;
      await box.put(_cachedUpdateKey, json.encode(update));
      await box.put(_cachedSourcesKey, json.encode(sources));
      await box.put(_cachedForVersionKey, current);
      await box.put(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      return _apply(update, sources);
    } catch (e) {
      debugPrint('UpdateService: Error checking for update: $e');
      return _applyCached();
    }
  }

  static Future<Object?> _getJson(Uri uri) async {
    final response = await http
        .get(uri, headers: {'User-Agent': 'Olib-Mobile'})
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} for ${uri.path}');
    }
    return json.decode(utf8.decode(response.bodyBytes));
  }

  /// 缓存只在版本号未变时有效：服务端结论是相对于请求时上报的版本算出的
  static bool _applyCached() {
    final box = HiveService.settingsBox;
    final raw = box.get(_cachedUpdateKey) as String?;
    if (raw == null ||
        currentVersion == null ||
        box.get(_cachedForVersionKey) != currentVersion) {
      return false;
    }
    try {
      final update = json.decode(raw);
      final sources = json.decode(
        box.get(_cachedSourcesKey) as String? ?? '[]',
      );
      if (update is! Map<String, dynamic>) return false;
      return _apply(update, sources is List ? sources : const []);
    } on FormatException catch (e) {
      debugPrint('UpdateService: bad update cache: $e');
      return false;
    }
  }

  static bool _apply(Map<String, dynamic> updateJson, List<dynamic> sources) {
    final current = currentVersion!;
    final update = MindsetUpdate.fromJson(updateJson, current);

    latestVersion = update.latestVersion;
    downloadUrl = update.pageUrl;
    links = parseSourceLinks(sources);
    changelog = {'zh': update.notes, 'en': update.notes};
    hasUpdate = update.hasUpdate;
    forceUpdate = update.hasUpdate && update.force;
    isBlocked = forceUpdate;

    debugPrint(
      'UpdateService: Current=$current, Latest=$latestVersion, '
      'HasUpdate=$hasUpdate, Force=$forceUpdate, Links=${links.length}',
    );
    return hasUpdate;
  }

  /// Check if we should perform update check
  static bool _shouldCheck() {
    final lastCheck = HiveService.settingsBox.get(_lastCheckKey);
    if (lastCheck == null) return true;

    final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheck as int);
    return DateTime.now().difference(lastCheckTime) > _checkInterval;
  }

  /// Check if user has dismissed this version
  static bool isVersionDismissed() {
    final dismissed = HiveService.settingsBox.get(_dismissedVersionKey);
    return dismissed == latestVersion;
  }

  /// Dismiss the current update notification
  static Future<void> dismissUpdate() async {
    if (latestVersion != null) {
      await HiveService.settingsBox.put(_dismissedVersionKey, latestVersion);
    }
  }

  /// Get changelog text for current locale
  static String getChangelog(String locale) {
    if (changelog == null) return '';
    return changelog![locale] ?? changelog!['en'] ?? '';
  }
}
