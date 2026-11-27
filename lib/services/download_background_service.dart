import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/download_provider.dart';
import '../utils/download_speed.dart';

/// Android 后台下载：有任务进行中时启动前台服务并在通知栏显示进度，
/// 应用切到后台也不会被系统冻结；全部结束后自动收起通知。
/// 其他平台为空操作。
class DownloadBackgroundService {
  DownloadBackgroundService(this._translate);

  static const _channel = MethodChannel('olib/download_service');

  /// 通知栏刷新最小间隔，避免进度回调过密触发系统通知限流。
  static const _minInterval = Duration(seconds: 1);

  final String Function(String key) _translate;

  bool _active = false;
  bool _permissionAsked = false;
  int _lastCount = 0;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _supported => !kIsWeb && Platform.isAndroid;

  /// 下载列表变化时调用。
  void sync(List<DownloadTask> tasks) {
    if (!_supported) return;
    final running = tasks
        .where(
          (t) =>
              t.status == DownloadStatus.downloading ||
              t.status == DownloadStatus.pending,
        )
        .toList();

    if (running.isEmpty) {
      if (_active) stop();
      return;
    }

    final now = DateTime.now();
    if (_active &&
        running.length == _lastCount &&
        now.difference(_lastSent) < _minInterval) {
      return;
    }
    _active = true;
    _lastCount = running.length;
    _lastSent = now;
    _ensureNotificationPermission();
    _invoke('update', _buildPayload(running));
  }

  void stop() {
    if (!_supported) return;
    _active = false;
    _lastCount = 0;
    _invoke('stop');
  }

  Map<String, Object> _buildPayload(List<DownloadTask> running) {
    final title = running.length == 1
        ? running.first.book.title
        : _translate(
            'download_notification_multi',
          ).replaceAll('{count}', '${running.length}');

    // 多本时汇总字节；任一本总大小未知则进度不确定
    final received = running.fold<int>(0, (s, t) => s + t.receivedBytes);
    final speed = running.fold<int>(0, (s, t) => s + t.speed);
    final allKnown = running.every((t) => t.totalBytes != null);
    final total = allKnown
        ? running.fold<int>(0, (s, t) => s + t.totalBytes!)
        : 0;
    final progress = total > 0 ? (received * 100 ~/ total) : -1;

    final parts = <String>[
      if (progress >= 0) '$progress%',
      if (speed > 0) formatSpeed(speed),
    ];

    return {
      'title': title,
      'text': parts.isEmpty ? _translate('downloading') : parts.join(' · '),
      'progress': progress,
      'channelName': _translate('download_notification_channel'),
    };
  }

  /// Android 13+ 需运行时授权才显示通知；拒绝也不影响后台下载本身。
  void _ensureNotificationPermission() {
    if (_permissionAsked) return;
    _permissionAsked = true;
    Permission.notification.request().catchError((Object e) {
      debugPrint('Notification permission request failed: $e');
      return PermissionStatus.denied;
    });
  }

  void _invoke(String method, [Map<String, Object>? args]) {
    _channel.invokeMethod<void>(method, args).catchError((Object e) {
      debugPrint('Download service $method failed: $e');
    });
  }
}
