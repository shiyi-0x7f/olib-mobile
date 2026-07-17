import 'package:dio/dio.dart';
import 'weread_errors.dart';

/// 微信读书网关 HTTP 客户端
///
/// 对应 OpenWeRead TypeScript SDK 的 client.ts + constants.ts。
/// 所有请求通过统一网关 POST，业务参数平铺在 body 顶层。
class WereadClient {
  static const String gatewayUrl =
      'https://i.weread.qq.com/api/agent/gateway';
  static const String skillVersion = '1.0.3';
  static const Duration defaultTimeout = Duration(seconds: 30);

  final Dio _dio;
  final String apiKey;

  WereadClient({
    required this.apiKey,
    String? baseUrl,
    Duration? timeout,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? gatewayUrl,
              connectTimeout: timeout ?? defaultTimeout,
              receiveTimeout: timeout ?? defaultTimeout,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
            )) {
    if (apiKey.isEmpty) throw const WereadAuthError();
    // Debug logging — 方便排查参数格式问题
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (o) => print('[WeRead] $o'),
    ));
  }

  /// 调用微信读书网关接口
  ///
  /// [apiName] 接口名，如 '/store/search'
  /// [params]  业务参数，平铺在 body 顶层（不要包在 params/data 里）
  Future<Map<String, dynamic>> call(
    String apiName, {
    Map<String, dynamic>? params,
    CancelToken? cancelToken,
  }) async {
    final body = <String, dynamic>{
      'api_name': apiName,
      'skill_version': skillVersion,
      ...?params,
    };

    Response<dynamic> response;
    try {
      response = await _dio.post(
        '',
        data: body,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      if (e.response != null) {
        final text = e.response?.data?.toString() ?? '';
        throw WereadHttpError(e.response!.statusCode ?? 0, text);
      }
      rethrow;
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const WereadError('响应格式异常', errcode: -1);
    }

    final errcode = data['errcode'] as int? ?? 0;
    if (errcode != 0) {
      throw WereadError(
        data['errmsg'] as String? ?? 'errcode=$errcode',
        errcode: errcode,
        upgradeInfo: data['upgrade_info'] as Map<String, dynamic>?,
        raw: data,
      );
    }

    return data;
  }

  /// 查询网关上所有可用接口及参数定义
  Future<Map<String, dynamic>> listApis({CancelToken? cancelToken}) {
    return call('/_list', cancelToken: cancelToken);
  }

  /// 释放 Dio 资源
  void close() {
    _dio.close();
  }
}
