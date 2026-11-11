import 'package:dio/dio.dart';
import '../models/prescription.dart';
import '../config/env.dart';

// ── 配额异常 — provider 据此挑文学化文案展示 ────────────────────────

/// 后端返回 QUOTA_EXCEEDED_AI_USER：当日单用户 AI 调用次数耗尽。
class AiUserQuotaExceeded implements Exception {
  const AiUserQuotaExceeded();
  @override
  String toString() => 'AiUserQuotaExceeded';
}

/// 后端返回 QUOTA_EXCEEDED_AI_GLOBAL：全站当日 AI 预算熔断。
class AiGlobalQuotaExceeded implements Exception {
  const AiGlobalQuotaExceeded();
  @override
  String toString() => 'AiGlobalQuotaExceeded';
}

/// AI 服务抽象接口
abstract class AiService {
  /// 生成阅读锦囊
  ///
  /// [input] - 预设主题 ID 或自由描述文本
  /// [inputType] - "theme" / "free" / "auto"（默认 "auto"）
  /// [language] - "zh" / "en"（默认 "zh"）
  /// [cancelToken] - 用于取消请求
  Future<ReadingBag> diagnose({
    required String input,
    String inputType = 'auto',
    String language = 'zh',
    CancelToken? cancelToken,
  });
}

/// 远程 AI 服务 — 调用后端 POST /api/prescribe
class RemoteAiService implements AiService {
  late final Dio _dio;

  RemoteAiService({String? baseUrl, required String token}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? Env.backendUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 45), // AI 生成较慢
      headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ));
  }

  @override
  Future<ReadingBag> diagnose({
    required String input,
    String inputType = 'auto',
    String language = 'zh',
    CancelToken? cancelToken,
  }) async {
    DioException? lastError;
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _dio.post(
          '/api/prescribe',
          data: {
            'input': input,
            'input_type': inputType,
            'language': language,
          },
          cancelToken: cancelToken,
        );

        final body = response.data;
        if (body is! Map<String, dynamic>) {
          throw Exception('服务器返回数据格式异常');
        }

        if (body['success'] == true) {
          final data = body['data'];
          if (data is! Map<String, dynamic>) {
            throw Exception('服务器返回的锦囊数据为空');
          }
          final bag = ReadingBag.fromJson(data);
          if (bag.tips.isEmpty) {
            throw Exception('AI 这次没有给出推荐，请换个描述再试');
          }
          return bag;
        }

        final error = body['error'] as String? ?? body['message'] as String? ?? '未知错误';
        // 业务错误不重试
        throw Exception(error);
      } on DioException catch (e) {
        lastError = e;
        if (CancelToken.isCancel(e)) rethrow;
        // 仅对超时/连接错误重试
        final retryable = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError;
        if (!retryable || attempt == 1) {
          throw _toUserMessage(e);
        }
        // 短暂等待后重试
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
    throw _toUserMessage(lastError!);
  }

  Exception _toUserMessage(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      final code = e.response?.statusCode;
      // 优先识别后端定义的 quota 错误码 → 返专用异常类型让 provider 切文学化文案
      if (code == 429 && data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail == 'QUOTA_EXCEEDED_AI_USER') return const AiUserQuotaExceeded();
        if (detail == 'QUOTA_EXCEEDED_AI_GLOBAL') return const AiGlobalQuotaExceeded();
      }
      if (data is Map<String, dynamic>) {
        final error = data['error'] ?? data['detail'] ?? data['message'];
        if (error is String) return Exception('$error${code != null ? " ($code)" : ""}');
      }
      if (code == 401 || code == 403) return Exception('授权失效，请重新扫码登录');
      if (code == 429) return Exception('请求太频繁，请稍后再试');
      if (code != null && code >= 500) return Exception('服务器暂时不可用，请稍后再试');
      return Exception('请求失败 ($code)');
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return Exception('连接超时，请检查网络后重试');
      case DioExceptionType.receiveTimeout:
        return Exception('AI 响应超时，请稍后再试');
      case DioExceptionType.connectionError:
        return Exception('无法连接服务器，请检查网络');
      default:
        return Exception('网络请求失败，请重试');
    }
  }
}
