import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/feedback.dart';

/// 采集反馈所需的平台 / 设备型号 / 系统版本（无需系统权限弹窗）。
///
/// 口径按 SCC client_integration_guide 3.13 的各端采集参考。
class DeviceDiagnosticsService {
  const DeviceDiagnosticsService();

  Future<DeviceDiagnostics> collect() async {
    final appVersion = (await PackageInfo.fromPlatform()).version;
    final platform = _sccPlatform();
    String? model;
    String? os;
    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        final info = await plugin.webBrowserInfo;
        model = info.browserName.name;
        os = info.platform;
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final info = await plugin.androidInfo;
            model = '${info.manufacturer} ${info.model}';
            os = 'Android ${info.version.release}';
          case TargetPlatform.iOS:
            final info = await plugin.iosInfo;
            model = info.utsname.machine;
            os = 'iOS ${info.systemVersion}';
          case TargetPlatform.windows:
            final info = await plugin.windowsInfo;
            // productName 在 Win11 上常仍报 "Windows 10"，按 build 号判定大版本。
            final major = info.buildNumber >= 22000 ? '11' : '10';
            os = 'Windows $major ${info.displayVersion}'.trim();
          case TargetPlatform.macOS:
            final info = await plugin.macOsInfo;
            model = info.model;
            os =
                'macOS ${info.majorVersion}.${info.minorVersion}.${info.patchVersion}';
          default:
            break;
        }
      }
    } catch (e, st) {
      // 设备信息拿不到不影响提交，只是不附带。
      debugPrint('[DeviceDiagnostics] 采集失败: $e\n$st');
    }
    return DeviceDiagnostics(
      platform: platform,
      deviceModel: _clip(model, 100),
      osVersion: _clip(os, 50),
      appVersion: appVersion,
    );
  }

  /// 映射到 SCC platform 枚举（ios/android/windows/macos/web/miniprogram）；Linux 等不支持返回 null。
  static String? _sccPlatform() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.windows => 'windows',
      TargetPlatform.macOS => 'macos',
      _ => null,
    };
  }

  static String? _clip(String? s, int max) {
    if (s == null) return null;
    final t = s.trim();
    if (t.isEmpty) return null;
    return t.length <= max ? t : t.substring(0, max);
  }
}
