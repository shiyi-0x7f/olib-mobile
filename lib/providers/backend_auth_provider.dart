import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/backend_response.dart';
import '../services/backend_api.dart';
import '../services/hive_service.dart';

// ---------- Hive Keys ----------
const _kJwt = 'backend_jwt';
const _kUserId = 'backend_user_id';
const _kUnionid = 'backend_unionid';
/// 最近一次授权成功的时间戳（ms since epoch），供 UI 区分「首次授权 / 重新授权」文案。
const _kLastAuthorizedAt = 'backend_last_authorized_at';

// 已废弃的 wxauth 时代 key，_init 时顺带清掉。
const _kLegacyRole = 'backend_role';
const _kLegacyDeviceId = 'backend_device_id';

// ---------- State ----------

enum BackendAuthStatus { unknown, unauthorized, authorized }

class BackendAuthState {
  final BackendAuthStatus status;

  /// SCC 签发的 client JWT（HS256，claim 含 sub/type:client/openid/unionid）。
  final String? jwt;
  final int? userId;
  final String? unionid;
  final DateTime? expiresAt;
  final String? qrUrl;
  final String? sceneId;
  final int? qrExpireSeconds;
  final bool isPolling;
  final String? error;

  const BackendAuthState({
    this.status = BackendAuthStatus.unknown,
    this.jwt,
    this.userId,
    this.unionid,
    this.expiresAt,
    this.qrUrl,
    this.sceneId,
    this.qrExpireSeconds,
    this.isPolling = false,
    this.error,
  });

  /// 已授权且 token 未过期。expiresAt 在读取时计算，
  /// 保证长时间挂后台后入口处 ref.read 拿到的是实时结论。
  bool get isAuthorized =>
      status == BackendAuthStatus.authorized &&
      jwt != null &&
      (expiresAt == null || DateTime.now().isBefore(expiresAt!));

  BackendAuthState copyWith({
    BackendAuthStatus? status,
    String? jwt,
    int? userId,
    String? unionid,
    DateTime? expiresAt,
    String? qrUrl,
    String? sceneId,
    int? qrExpireSeconds,
    bool? isPolling,
    String? error,
  }) {
    return BackendAuthState(
      status: status ?? this.status,
      jwt: jwt ?? this.jwt,
      userId: userId ?? this.userId,
      unionid: unionid ?? this.unionid,
      expiresAt: expiresAt ?? this.expiresAt,
      qrUrl: qrUrl ?? this.qrUrl,
      sceneId: sceneId ?? this.sceneId,
      qrExpireSeconds: qrExpireSeconds ?? this.qrExpireSeconds,
      isPolling: isPolling ?? this.isPolling,
      error: error ?? this.error,
    );
  }
}

// ---------- JWT 工具 ----------

/// 解 JWT payload（不验签——验签是服务端的事，客户端只读 exp/type 做本地判定）。
Map<String, dynamic>? decodeJwtPayload(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decoded) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// 是否为未过期的 SCC client token。
/// 存量 wxauth 时代的 JWT 没有 `type: client` claim，会在这里被判无效
/// →_init 清除并要求重新扫码（迁移期的重登引导）。
bool _isValidSccToken(Map<String, dynamic>? payload) {
  if (payload == null) return false;
  if (payload['type'] != 'client') return false;
  final exp = payload['exp'];
  if (exp is! int) return false;
  final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  // 留 60s 余量，避免边缘时刻带着将过期的 token 去请求
  return DateTime.now().isBefore(expiry.subtract(const Duration(seconds: 60)));
}

DateTime? _tokenExpiry(Map<String, dynamic> payload) {
  final exp = payload['exp'];
  if (exp is! int) return null;
  return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
}

// ---------- Notifier ----------

class BackendAuthNotifier extends StateNotifier<BackendAuthState> {
  final BackendApi _api;
  Timer? _pollTimer;

  BackendAuthNotifier(this._api) : super(const BackendAuthState()) {
    _init();
  }

  /// 初始化：从 Hive 恢复 SCC token，本地校验 exp/type 即可（离线可用）。
  /// 无效（含存量 wxauth JWT）→ 清除，等用户下次进入功能时扫码重登。
  Future<void> _init() async {
    final box = HiveService.authBox;
    // 清理 wxauth 时代遗留 key
    await box.delete(_kLegacyRole);
    await box.delete(_kLegacyDeviceId);

    final jwt = box.get(_kJwt) as String?;
    if (jwt == null) {
      state = const BackendAuthState(status: BackendAuthStatus.unauthorized);
      return;
    }

    final payload = decodeJwtPayload(jwt);
    if (!_isValidSccToken(payload)) {
      debugPrint('[BackendAuth] 本地 token 无效/过期（或为存量 wxauth token），已清除');
      await box.delete(_kJwt);
      state = const BackendAuthState(status: BackendAuthStatus.unauthorized);
      return;
    }

    state = BackendAuthState(
      status: BackendAuthStatus.authorized,
      jwt: jwt,
      userId: box.get(_kUserId) as int?,
      unionid: box.get(_kUnionid) as String?,
      expiresAt: _tokenExpiry(payload!),
    );
  }

  /// 建码：向 SCC 请求公众号临时二维码。
  Future<void> fetchQrCode() async {
    try {
      final response = await _api.getQrCode();
      debugPrint('[BackendAuth] SCC 建码 OK: scene=${response.sceneId}');
      state = state.copyWith(
        qrUrl: response.qrUrl,
        sceneId: response.sceneId,
        qrExpireSeconds: response.expireSeconds,
        error: null,
      );
    } catch (e) {
      debugPrint('[BackendAuth] SCC 建码失败: $e');
      state = state.copyWith(error: '获取二维码失败: $e');
    }
  }

  /// 开始轮询扫码状态（SCC 建议 2s 一次）。
  void startPolling() {
    if (state.isPolling || state.sceneId == null) return;
    state = state.copyWith(isPolling: true);

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _checkStatus();
    });

    // 二维码有效期兜底：超时自动停止
    final timeout = Duration(seconds: state.qrExpireSeconds ?? 300);
    Future.delayed(timeout, () {
      if (mounted && state.isPolling && !state.isAuthorized) {
        stopPolling();
        state = state.copyWith(error: '二维码已过期，请刷新重试');
      }
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (mounted) {
      state = state.copyWith(isPolling: false);
    }
  }

  Future<void> _checkStatus() async {
    final sceneId = state.sceneId;
    if (sceneId == null) return;
    try {
      final response = await _api.checkStatus(sceneId);

      if (response.isConfirmed) {
        debugPrint('[BackendAuth] 扫码确认, user_id=${response.userId}');
        await _saveAuth(response);
        stopPolling();
      } else if (response.isExpired) {
        debugPrint('[BackendAuth] 二维码已过期');
        stopPolling();
        if (mounted) {
          state = state.copyWith(error: '二维码已过期，请刷新重试');
        }
      }
      // waiting → 继续轮询
    } catch (e) {
      // 网络抖动不中断轮询，等下一轮
      debugPrint('[BackendAuth] 轮询失败（继续）: $e');
    }
  }

  Future<void> _saveAuth(AuthStatusResponse response) async {
    final jwt = response.token!;
    final box = HiveService.authBox;
    await box.put(_kJwt, jwt);
    if (response.userId != null) await box.put(_kUserId, response.userId);
    if (response.unionid != null) await box.put(_kUnionid, response.unionid);
    await box.put(_kLastAuthorizedAt, DateTime.now().millisecondsSinceEpoch);

    if (mounted) {
      final payload = decodeJwtPayload(jwt);
      state = BackendAuthState(
        status: BackendAuthStatus.authorized,
        jwt: jwt,
        userId: response.userId,
        unionid: response.unionid,
        expiresAt: payload == null ? null : _tokenExpiry(payload),
      );
    }
  }

  /// 返回上次授权成功的时间；从未授权或 Hive 没记录返回 null。
  DateTime? lastAuthorizedAt() {
    final ms = HiveService.authBox.get(_kLastAuthorizedAt) as int?;
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// 登出 — 清除所有认证数据
  Future<void> logout() async {
    stopPolling();
    final box = HiveService.authBox;
    await box.delete(_kJwt);
    await box.delete(_kUserId);
    await box.delete(_kUnionid);
    await box.delete(_kLastAuthorizedAt);
    state = const BackendAuthState(status: BackendAuthStatus.unauthorized);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

// ---------- Providers ----------

final backendApiProvider = Provider<BackendApi>((ref) => BackendApi());

final backendAuthProvider =
    StateNotifierProvider<BackendAuthNotifier, BackendAuthState>((ref) {
  final api = ref.read(backendApiProvider);
  return BackendAuthNotifier(api);
});
