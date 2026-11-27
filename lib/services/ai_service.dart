import 'package:dio/dio.dart';

import '../models/prescription.dart';
import 'ai/ai_client.dart';
import 'ai/ai_settings.dart';

/// 尚未配置 AI 服务（地址 / Key / 模型不完整），界面据此引导去设置页
class AiNotConfigured implements Exception {
  const AiNotConfigured();
  @override
  String toString() => 'AiNotConfigured';
}

/// AI 服务抽象接口
abstract class AiService {
  /// 生成阅读锦囊
  ///
  /// [input] - 预设主题 ID 或自由描述文本
  /// [inputType] - "theme" / "free" / "auto"（默认 "auto"）
  /// [cancelToken] - 用于取消请求
  Future<ReadingBag> diagnose({
    required String input,
    String inputType = 'auto',
    CancelToken? cancelToken,
  });
}

/// BYOK：用用户自带的 Key 从本机直连 OpenAI 兼容接口
class ByokAiService implements AiService {
  /// 每次寻书时读取最新配置（改配置不必重建服务与寻书状态）
  final AiSettings? Function() _settings;
  final AiClient _client;

  ByokAiService(this._settings, {AiClient? client})
    : _client = client ?? AiClient();

  @override
  Future<ReadingBag> diagnose({
    required String input,
    String inputType = 'auto',
    CancelToken? cancelToken,
  }) async {
    final settings = _settings();
    if (settings == null || !settings.isComplete) {
      throw const AiNotConfigured();
    }
    return _client.findBooks(
      settings,
      input,
      inputType,
      cancelToken: cancelToken,
    );
  }
}
