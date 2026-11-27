import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai/ai_client.dart';
import '../services/ai/ai_settings.dart';

final aiSettingsStoreProvider = Provider<AiSettingsStore>(
  (ref) => AiSettingsStore(),
);

final aiClientProvider = Provider<AiClient>((ref) => AiClient());

/// 已保存的 AI 寻书配置；未保存为 null
final aiSettingsProvider =
    StateNotifierProvider<AiSettingsNotifier, AiSettings?>((ref) {
      return AiSettingsNotifier(
        ref.watch(aiSettingsStoreProvider),
        ref.watch(aiClientProvider),
      );
    });

class AiSettingsNotifier extends StateNotifier<AiSettings?> {
  final AiSettingsStore _store;
  final AiClient _client;

  AiSettingsNotifier(this._store, this._client) : super(_store.load());

  /// 规范化、校验、保存，再发一条极短请求验证可用。
  /// [apiKey] 为空表示沿用已保存的 Key。校验或测试失败抛 [AiServiceException]；
  /// 测试失败时配置仍已保存（与电脑端一致，方便用户改一项再试）。
  Future<void> saveAndTest(AiSettings input) async {
    final key = input.apiKey.trim().isEmpty
        ? (state?.apiKey ?? '')
        : input.apiKey;
    final settings = AiSettings(
      provider: input.provider,
      baseUrl: input.baseUrl,
      model: input.model,
      apiKey: key,
      tipCount: input.tipCount,
      extraPrompt: input.extraPrompt,
    ).normalized();
    final error = settings.validate();
    if (error != null) throw AiServiceException(error);
    await _store.save(settings);
    state = settings;
    await _client.test(settings);
  }

  /// [apiKey] 为空时用已保存的 Key（编辑地址但未改 Key 的情况）
  Future<List<String>> listModels(String baseUrl, String apiKey) async {
    final key = apiKey.trim().isNotEmpty ? apiKey.trim() : state?.apiKey ?? '';
    if (key.isEmpty) throw const AiServiceException('请先填写 API Key');
    return _client.listModels(baseUrl, key);
  }
}
