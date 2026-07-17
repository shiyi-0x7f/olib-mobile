/// 微信读书 API 错误体系
///
/// 对应 OpenWeRead TypeScript SDK 的 errors.ts
library;

/// 业务错误 — 网关返回 errcode != 0
class WereadError implements Exception {
  final String message;
  final int errcode;
  final Map<String, dynamic>? upgradeInfo;
  final Map<String, dynamic>? raw;

  const WereadError(
    this.message, {
    required this.errcode,
    this.upgradeInfo,
    this.raw,
  });

  /// 是否需要升级 skill 版本
  bool get needsUpgrade => upgradeInfo != null;

  /// 升级提示文本
  String? get upgradeMessage => upgradeInfo?['message'] as String?;

  @override
  String toString() => 'WereadError($errcode): $message';
}

/// 鉴权错误 — API Key 缺失或无效
class WereadAuthError extends WereadError {
  const WereadAuthError([
    super.message = '未设置微信读书 API Key，请在设置中配置',
  ]) : super(errcode: -1);

  @override
  String toString() => 'WereadAuthError: $message';
}

/// HTTP 层错误 — 非 2xx 响应
class WereadHttpError extends WereadError {
  final int statusCode;

  WereadHttpError(this.statusCode, String body)
      : super(
          'HTTP $statusCode: ${body.length > 200 ? body.substring(0, 200) : body}',
          errcode: statusCode,
          raw: {'body': body},
        );

  @override
  String toString() => 'WereadHttpError($statusCode): $message';
}
