import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'hive_service.dart';
import 'update/update_manifest.dart';

export 'update/update_manifest.dart' show UpdateLink;

/// Update checker service for checking new app versions.
///
/// 数据源：GitHub Releases API。tag push 后 CI workflow 自动建 Release，
/// 这里直接拉 `releases/latest`：
/// - tag_name (去掉 v 前缀) → 最新版本号
/// - body                   → changelog + 更新清单（强制更新 / 网盘渠道，
///   见 [UpdateManifest]）
///
/// 网络请求 24h 一次，但每次拿到的 Release 会缓存进 Hive：跳过请求时用缓存
/// 重新计算状态，保证强制更新在 App 重启后依然生效。
class UpdateService {
  /// GitHub Releases 数据源
  static const String _releaseApiUrl =
      'https://api.github.com/repos/shiyi-0x7f/olib-mobile/releases/latest';

  /// 官网项目页（MindSet `olib-mobile`），PanSync 发版时同步网盘链接到这里
  static const String _downloadUrl = 'https://www.11xy.cn/projects/olib-mobile';

  static const String _lastCheckKey = 'last_update_check';
  static const String _dismissedVersionKey = 'dismissed_version';
  static const String _cachedTagKey = 'update_cached_tag';
  static const String _cachedBodyKey = 'update_cached_body';
  static const String _cachedReleaseUrlKey = 'update_cached_release_url';

  /// Check interval: once per day
  static const Duration _checkInterval = Duration(hours: 24);

  /// Remote version info
  static String? latestVersion;
  static String? currentVersion;
  static String? downloadUrl = _downloadUrl;
  static String? releaseUrl;
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

      final response = await http
          .get(
            Uri.parse(_releaseApiUrl),
            headers: {
              // 不带 token 走匿名 60 次/小时/IP — 对 24h 检查间隔够用
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final body = response.body;
        debugPrint(
          'UpdateService: GitHub releases API ${response.statusCode}: '
          '${body.length > 200 ? body.substring(0, 200) : body}',
        );
        return _applyCached();
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String?;
      if (tagName == null || tagName.isEmpty) {
        debugPrint('UpdateService: release missing tag_name');
        return _applyCached();
      }
      final body = (data['body'] as String? ?? '').trim();
      final htmlUrl = data['html_url'] as String?;

      final box = HiveService.settingsBox;
      await box.put(_cachedTagKey, tagName);
      await box.put(_cachedBodyKey, body);
      await box.put(_cachedReleaseUrlKey, htmlUrl);
      await box.put(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      return _apply(tagName, body, htmlUrl);
    } catch (e) {
      debugPrint('UpdateService: Error checking for update: $e');
      return _applyCached();
    }
  }

  static bool _applyCached() {
    final box = HiveService.settingsBox;
    final tag = box.get(_cachedTagKey) as String?;
    if (tag == null || currentVersion == null) return false;
    return _apply(
      tag,
      box.get(_cachedBodyKey) as String? ?? '',
      box.get(_cachedReleaseUrlKey) as String?,
    );
  }

  static bool _apply(String tagName, String body, String? htmlUrl) {
    final current = currentVersion!;
    final latest = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    final manifest = UpdateManifest.parse(body);

    latestVersion = latest;
    releaseUrl = htmlUrl;
    links = manifest.links;
    // 双语都用同一份（后续如果想分语言可以解析 ## zh / ## en 段）
    changelog = {'zh': manifest.notes, 'en': manifest.notes};
    hasUpdate = isNewerVersion(latest, current);

    final belowMin =
        manifest.minVersion != null &&
        isNewerVersion(manifest.minVersion!, current);
    forceUpdate = hasUpdate && (manifest.forceAll || belowMin);
    isBlocked = forceUpdate;

    debugPrint(
      'UpdateService: Current=$current, Latest=$latest, '
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
