/// OpenAI 兼容接口调用：`POST {base}/chat/completions`、`GET {base}/models`。
/// 与 OlibTauri `src-tauri/src/ai_finder/client.rs` 保持一致。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/prescription.dart';
import 'ai_prompt.dart';
import 'ai_settings.dart';

/// 推理模型较慢，给足时间
const Duration _chatTimeout = Duration(seconds: 90);
const Duration _modelsTimeout = Duration(seconds: 15);

/// 模型偶发不按格式输出时的重试次数（与原服务端一致）
const int _parseAttempts = 2;

/// 输出上限：最多 10 本书 + 推理模型的思考开销；按实际生成计费，上限高不多花钱
const int _maxOutputTokens = 4096;

/// AI 服务返回的、可直接展示给用户的错误
class AiServiceException implements Exception {
  final String message;
  const AiServiceException(this.message);
  @override
  String toString() => message;
}

class AiClient {
  final Dio _dio;

  /// [dio] 仅供测试注入
  AiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              // 状态码由本类自行判断，以便读取服务商的错误体
              validateStatus: (_) => true,
              responseType: ResponseType.plain,
            ),
          );

  /// 发一条极短的请求，验证地址、Key、模型三者可用。
  /// 只看请求是否成功：推理模型在极小额度下可能把 token 全用于思考而返回空内容。
  Future<void> test(AiSettings s) async {
    _ensureValid(s);
    await _chat(s, '回复 OK', 16);
  }

  /// 列出服务商可用模型；部分服务商不提供此接口，调用方需允许手填
  Future<List<String>> listModels(String baseUrl, String apiKey) async {
    final Response<String> resp;
    try {
      resp = await _dio.get<String>(
        '${normalizeBaseUrl(baseUrl)}/models',
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
          receiveTimeout: _modelsTimeout,
        ),
      );
    } on DioException catch (e) {
      throw AiServiceException('连接 AI 服务失败: ${_transportError(e)}');
    }
    final body = resp.data ?? '';
    final status = resp.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw AiServiceException(apiErrorMessage(status, body));
    }
    final Object? v;
    try {
      v = jsonDecode(body);
    } on FormatException catch (e) {
      throw AiServiceException('模型列表解析失败: ${e.message}');
    }
    final data = v is Map ? v['data'] : null;
    final models = <String>[
      if (data is List)
        for (final m in data)
          if (m is Map && m['id'] is String) m['id'] as String,
    ]..sort();
    return models;
  }

  /// 生成阅读锦囊；模型输出格式偶发偏差时重试
  Future<ReadingBag> findBooks(
    AiSettings s,
    String input,
    String inputType, {
    CancelToken? cancelToken,
  }) async {
    _ensureValid(s);
    final prompt = buildPrompt(input, inputType, s.tipCount, s.extraPrompt);
    var lastError = '';
    for (var attempt = 1; attempt <= _parseAttempts; attempt++) {
      final resp = await _chat(
        s,
        prompt,
        _maxOutputTokens,
        cancelToken: cancelToken,
      );
      try {
        final text = messageContent(resp);
        return validateReadingBag(extractJson(text), s.tipCount);
      } on AiFormatException catch (e) {
        debugPrint('[AiFinder] 结果解析失败（第 $attempt 次）: $e');
        lastError = e.message;
      }
    }
    throw AiServiceException('AI 返回格式异常，请重试或换个模型（$lastError）');
  }

  void _ensureValid(AiSettings s) {
    final error = s.validate();
    if (error != null) throw AiServiceException(error);
  }

  /// 返回解析后的响应体；参数不兼容时自动换推理模型参数重试一次
  Future<Object?> _chat(
    AiSettings s,
    String content,
    int maxTokens, {
    CancelToken? cancelToken,
  }) async {
    var reasoningCompat = false;
    while (true) {
      final Response<String> resp;
      try {
        resp = await _dio.post<String>(
          '${s.baseUrl}/chat/completions',
          data: jsonEncode(chatBody(s, content, maxTokens, reasoningCompat)),
          cancelToken: cancelToken,
          options: Options(
            headers: {
              'Authorization': 'Bearer ${s.apiKey}',
              'Content-Type': 'application/json',
            },
            sendTimeout: _chatTimeout,
            receiveTimeout: _chatTimeout,
          ),
        );
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow;
        throw AiServiceException('连接 AI 服务失败: ${_transportError(e)}');
      }
      final status = resp.statusCode ?? 0;
      final body = resp.data ?? '';
      if (status >= 200 && status < 300) {
        try {
          return jsonDecode(body);
        } on FormatException catch (e) {
          throw AiServiceException('AI 响应解析失败: ${e.message}');
        }
      }
      if (!reasoningCompat && needsReasoningCompat(status, body)) {
        debugPrint(
          '[AiFinder] 模型 ${s.model} 不支持 max_tokens/temperature，改用推理模型参数重试',
        );
        reasoningCompat = true;
        continue;
      }
      throw AiServiceException(apiErrorMessage(status, body));
    }
  }

  String _transportError(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout => '连接超时，请检查网络或接口地址',
    DioExceptionType.receiveTimeout => '等待回复超时，可换个更快的模型再试',
    _ => e.message ?? e.error?.toString() ?? e.type.name,
  };
}

/// 请求体。[reasoningCompat] 用于推理模型（如 OpenAI o 系列）：它们拒绝 `max_tokens` 与非默认 temperature，
/// 需改用 `max_completion_tokens`、不传 temperature。
@visibleForTesting
Map<String, dynamic> chatBody(
  AiSettings s,
  String content,
  int maxTokens,
  bool reasoningCompat,
) => {
  'model': s.model,
  'messages': [
    {'role': 'user', 'content': content},
  ],
  if (reasoningCompat)
    'max_completion_tokens': maxTokens
  else ...{
    'temperature': 0.8,
    'max_tokens': maxTokens,
  },
};

/// 400 报错是否指向 `max_tokens` / `temperature` 参数不被支持（推理模型）
@visibleForTesting
bool needsReasoningCompat(int status, String body) =>
    status == 400 &&
    (body.contains('max_completion_tokens') ||
        (body.contains('temperature') &&
            body.toLowerCase().contains('unsupported')));

/// 取 `choices[0].message.content`，空内容视为格式异常（触发重试）
@visibleForTesting
String messageContent(Object? v) {
  if (v is Map) {
    final choices = v['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      final message = first is Map ? first['message'] : null;
      final content = message is Map ? message['content'] : null;
      if (content is String && content.trim().isNotEmpty) return content;
    }
  }
  throw const AiFormatException('AI 响应中没有内容');
}

/// 把服务商的错误响应翻成可读文案，并附上原始错误信息便于排查
@visibleForTesting
String apiErrorMessage(int status, String body) {
  String? detail;
  try {
    final v = jsonDecode(body);
    if (v is Map) {
      final err = v['error'];
      final candidates = [
        err is Map ? err['message'] : null,
        v['message'],
        err,
      ];
      detail = candidates.whereType<String>().firstOrNull;
    }
  } on FormatException {
    // 非 JSON 错误体，下面直接截取原文
  }
  detail ??= String.fromCharCodes(body.runes.take(200));
  final summary = switch (status) {
    401 || 403 => 'API Key 无效或无权限',
    402 => '账户余额不足',
    404 => '接口地址或模型不存在',
    429 => '请求太频繁或额度已用尽',
    _ => 'AI 服务返回错误',
  };
  return '$summary（HTTP $status）：$detail';
}
