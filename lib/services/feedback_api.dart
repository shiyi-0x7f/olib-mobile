import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/env.dart';
import '../models/feedback.dart';

/// SCC 反馈接口失败（携带 HTTP 状态码，供 UI 区分 401/409/429 等）。
class FeedbackApiException implements Exception {
  final int? statusCode;
  final String message;

  const FeedbackApiException(this.statusCode, this.message);

  @override
  String toString() =>
      statusCode == null ? message : 'HTTP $statusCode: $message';
}

/// SCC 统一反馈客户端（`/api/v1/client/feedback*`，需 client JWT）。
///
/// app_id 由 SCC 从 token 推导，客户端不传。失败为非 2xx + `{"detail": ...}`。
class FeedbackApi {
  late final Dio _dio;

  FeedbackApi({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? Env.sccUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  /// 提交反馈。同一 `client_ref` 重复提交返回已有记录（幂等）。
  /// 返回 `{id, status, created_at}`。
  Future<Map<String, dynamic>> submit({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    try {
      final resp = await _dio.post(
        '/api/v1/client/feedback',
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _toException(e, 'POST /client/feedback', body);
    }
  }

  /// 我的反馈列表（含处理状态与修复版本）。
  Future<List<MyFeedbackItem>> listMine({
    required String token,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final resp = await _dio.get(
        '/api/v1/client/feedback/mine',
        queryParameters: {'page': page, 'page_size': pageSize},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final items = (resp.data as Map<String, dynamic>)['items'] as List;
      return items
          .map((e) => MyFeedbackItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _toException(e, 'GET /client/feedback/mine', null);
    }
  }

  FeedbackApiException _toException(
    DioException e,
    String label,
    Map<String, dynamic>? body,
  ) {
    final status = e.response?.statusCode;
    final detail = _readDetail(e.response?.data);
    // dev 模式输出完整报文便于排查；token 不入日志。
    debugPrint(
      '[FeedbackApi] $label 失败: status=$status detail=$detail '
      'body=$body error=${e.message}',
    );
    return FeedbackApiException(status, detail ?? e.message ?? e.type.name);
  }

  /// FastAPI detail 可能是字符串，也可能是 422 的校验错误列表。
  static String? _readDetail(Object? data) {
    if (data is! Map) return null;
    final detail = data['detail'];
    if (detail is String) return detail;
    if (detail is List) {
      return detail
          .map(
            (d) =>
                d is Map ? '${(d['loc'] as List?)?.last}: ${d['msg']}' : '$d',
          )
          .join('; ');
    }
    return null;
  }
}
