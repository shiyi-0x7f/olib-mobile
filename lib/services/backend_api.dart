import 'package:dio/dio.dart';
import '../config/env.dart';
import '../models/backend_response.dart';

/// SCC（统一身份基座）公众号扫码登录客户端。
///
/// olib 不再自建登录：客户端在 SCC 完成微信扫码登录拿 client JWT，
/// olib-server（olibai）只离线验签该 token。SCC 接口直返业务 JSON，
/// 失败为非 2xx + `{"detail": "..."}`（FastAPI 风格）。
class BackendApi {
  late final Dio _dio;

  BackendApi({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? Env.sccUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  /// 建码：生成公众号临时二维码（带 scene，未关注用户扫码即关注）。
  Future<QrCodeResponse> getQrCode() async {
    final response = await _dio.get(
      '/api/v1/client/auth/wechat-qr',
      queryParameters: {'app_id': Env.sccAppId},
    );
    return QrCodeResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// 轮询扫码状态：waiting / expired / confirmed（confirmed 时下发 token）。
  Future<AuthStatusResponse> checkStatus(String sceneId) async {
    final response =
        await _dio.get('/api/v1/client/auth/wechat-qr/status/$sceneId');
    return AuthStatusResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
