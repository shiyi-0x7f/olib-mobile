import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feedback.dart';
import '../services/device_diagnostics_service.dart';
import '../services/feedback_api.dart';
import '../services/hive_service.dart';
import 'backend_auth_provider.dart';

/// Hive settings：上次「附带设备信息」的选择，作为下次默认值（首次默认不勾选）。
const _kDiagnosticsConsent = 'feedback_diagnostics_consent';

final feedbackApiProvider = Provider<FeedbackApi>((ref) => FeedbackApi());

/// 本机诊断信息（一次采集，表单内展示「将发送的实际值」）。
final deviceDiagnosticsProvider = FutureProvider<DeviceDiagnostics>(
  (ref) => const DeviceDiagnosticsService().collect(),
);

bool readDiagnosticsConsent() =>
    HiveService.settingsBox.get(_kDiagnosticsConsent, defaultValue: false)
        as bool;

Future<void> saveDiagnosticsConsent(bool value) =>
    HiveService.settingsBox.put(_kDiagnosticsConsent, value);

/// 我的反馈列表（需已登录 SCC）；下拉刷新时 invalidate。
final myFeedbackProvider = FutureProvider.autoDispose<List<MyFeedbackItem>>((
  ref,
) async {
  final auth = ref.watch(backendAuthProvider);
  if (!auth.isAuthorized) {
    throw const FeedbackApiException(401, 'not authorized');
  }
  return ref.read(feedbackApiProvider).listMine(token: auth.jwt!);
});

/// 用户填写的反馈内容（不含环境信息）。
class FeedbackDraft {
  final String type;
  final String area;
  final String? severity;
  final String title;
  final String content;
  final String? steps;
  final String? expected;
  final String? actual;
  final bool diagnosticsConsent;

  const FeedbackDraft({
    required this.type,
    required this.area,
    required this.severity,
    required this.title,
    required this.content,
    required this.steps,
    required this.expected,
    required this.actual,
    required this.diagnosticsConsent,
  });
}

/// 一次反馈表单会话的提交器：持有幂等键 `client_ref`，失败重试复用同一个，
/// 成功后换新（同一页面连续提交第二条不会被当成重复）。
class FeedbackSubmitter {
  final FeedbackApi _api;
  String _clientRef = _uuidV4();

  FeedbackSubmitter(this._api);

  Future<int> submit({
    required String token,
    required FeedbackDraft draft,
    required DeviceDiagnostics diagnostics,
  }) async {
    final body = _buildBody(draft, diagnostics);
    Map<String, dynamic> result;
    try {
      result = await _api.submit(token: token, body: body);
    } on FeedbackApiException catch (e) {
      // 409：client_ref 被其他用户占用（如切换账号）→ 换新 UUID 重试一次
      if (e.statusCode != 409) rethrow;
      _clientRef = _uuidV4();
      result = await _api.submit(
        token: token,
        body: {...body, 'client_ref': _clientRef},
      );
    }
    _clientRef = _uuidV4();
    return result['id'] as int;
  }

  Map<String, dynamic> _buildBody(FeedbackDraft d, DeviceDiagnostics diag) {
    String? opt(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    final content = d.content.trim();
    // 标题选填：留空时取描述首行前 30 字
    final title = opt(d.title) ?? _deriveTitle(content);
    final details = {
      if (opt(d.steps) != null) 'steps': opt(d.steps),
      if (opt(d.expected) != null) 'expected': opt(d.expected),
      if (opt(d.actual) != null) 'actual': opt(d.actual),
    };
    return {
      'client_ref': _clientRef,
      'type': d.type,
      'area': d.area,
      if (d.severity != null) 'severity': d.severity,
      'title': title,
      'content': content,
      if (details.isNotEmpty) 'details': details,
      'app_version': diag.appVersion,
      'platform': diag.platform,
      'diagnostics_consent': d.diagnosticsConsent,
      // 未同意时不发送设备信息（服务端也会丢弃，这里不依赖服务端兜底）
      if (d.diagnosticsConsent && diag.deviceModel != null)
        'device_model': diag.deviceModel,
      if (d.diagnosticsConsent && diag.osVersion != null)
        'os_version': diag.osVersion,
    };
  }

  static String _deriveTitle(String content) {
    final firstLine = content.split('\n').first.trim();
    return firstLine.length <= 30
        ? firstLine
        : '${firstLine.substring(0, 30)}…';
  }

  static String _uuidV4() {
    final rnd = Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}
