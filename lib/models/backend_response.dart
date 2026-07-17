/// SCC（统一身份基座）公众号扫码登录的响应模型。
///
/// 契约见 dev_docs/refs/software_control_center.md：
/// - 建码 `GET /api/v1/client/auth/wechat-qr?app_id=`
/// - 轮询 `GET /api/v1/client/auth/wechat-qr/status/{scene_id}`
library;

/// 建码响应 — 公众号临时二维码（未关注用户扫码即关注）。
class QrCodeResponse {
  final String sceneId;
  final String qrUrl;
  final int expireSeconds;

  const QrCodeResponse({
    required this.sceneId,
    required this.qrUrl,
    required this.expireSeconds,
  });

  factory QrCodeResponse.fromJson(Map<String, dynamic> json) {
    return QrCodeResponse(
      sceneId: json['scene_id'] as String? ?? '',
      qrUrl: json['qrcode_url'] as String? ?? '',
      expireSeconds: json['expire_seconds'] as int? ?? 300,
    );
  }
}

/// 轮询响应 — status: waiting / expired / confirmed。
/// confirmed 时附带 SCC 签发的 client JWT 与用户信息。
class AuthStatusResponse {
  final String? status;
  final String? token;
  final int? userId;
  final String? nickname;
  final String? unionid;

  const AuthStatusResponse({
    this.status,
    this.token,
    this.userId,
    this.nickname,
    this.unionid,
  });

  bool get isConfirmed => status == 'confirmed' && token != null;
  bool get isExpired => status == 'expired';

  factory AuthStatusResponse.fromJson(Map<String, dynamic> json) {
    return AuthStatusResponse(
      status: json['status'] as String?,
      token: json['token'] as String?,
      userId: json['user_id'] as int?,
      nickname: json['nickname'] as String?,
      unionid: json['unionid'] as String?,
    );
  }
}
