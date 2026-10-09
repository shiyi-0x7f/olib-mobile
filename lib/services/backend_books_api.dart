import 'package:dio/dio.dart';
import '../config/env.dart';

/// 出错码 — 跟后端 app/deps/quota.py 保持同名
class QuotaErrorCode {
  static const downloadExceeded = 'QUOTA_EXCEEDED_DOWNLOAD';
}

/// 配额耗尽异常 — 上层据此挑随机文学化文案展示，避免出现"免费/配额"商业词。
class FreeDownloadQuotaExceeded implements Exception {
  const FreeDownloadQuotaExceeded();
  @override
  String toString() => 'FreeDownloadQuotaExceeded';
}

/// 后端下载中介 — 仅给 AI 寻书结果用（ReadingTip.fromAi == true）。
/// 普通搜索/详情的下载仍由前端直连用户自己的 z站 账号。
class BackendBooksApi {
  late final Dio _dio;

  BackendBooksApi({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? Env.backendUrl, // olibai.11xy.cn（鉴权已收口 SCC token）
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  /// 拿一本 AI 推荐书的下载 URL。
  /// - [olibToken] 主 app 已授权用户的 JWT (backend olib audience)
  /// - 返回：真实的签名下载 URL 字符串
  ///
  /// 抛出：
  /// - [FreeDownloadQuotaExceeded] 当日配额耗尽（后端 429 + detail=QUOTA_EXCEEDED_DOWNLOAD）
  /// - 其他 DioException 走原样
  Future<String> getAiBookDownloadUrl({
    required String olibToken,
    required String bookId,
    required String hashId,
  }) async {
    try {
      final response = await _dio.post(
        '/books/download-url',
        data: {'bookid': bookId, 'hashid': hashId},
        options: Options(headers: {'Authorization': 'Bearer $olibToken'}),
      );
      final body = response.data as Map<String, dynamic>;
      if (body['success'] != true || body['data'] == null) {
        throw Exception(body['error'] ?? 'backend download-url failed');
      }
      final data = body['data'] as Map<String, dynamic>;
      final durl = data['durl'] as String?;
      if (durl == null || durl.isEmpty) {
        throw Exception('backend returned empty durl');
      }
      return durl;
    } on DioException catch (e) {
      // 后端返 429 + detail=QUOTA_EXCEEDED_DOWNLOAD → 配额耗尽
      if (e.response?.statusCode == 429 &&
          e.response?.data is Map &&
          (e.response!.data as Map)['detail'] ==
              QuotaErrorCode.downloadExceeded) {
        throw const FreeDownloadQuotaExceeded();
      }
      rethrow;
    }
  }
}
