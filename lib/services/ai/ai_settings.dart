/// AI 寻书 BYOK 配置与本地持久化（Hive `auth` box）。
///
/// 与 OlibTauri `src-tauri/src/ai_finder/mod.rs` 的规则一致：地址规范化、推荐数量夹在 1–10、
/// 补充要求 ≤ 300 字。API Key 只存本机，不写日志。
library;

import '../hive_service.dart';
import 'ai_providers.dart';

/// 默认推荐数量（与原服务端一致）
const int defaultTipCount = 3;

/// 推荐数量上限：书太多时单次回复过长、易被截断导致 JSON 不完整
const int maxTipCount = 10;

/// 设置页可选档位
const List<int> tipCountOptions = [3, 5, 8];

/// 用户补充要求的长度上限（字符）
const int maxExtraPromptChars = 300;

class AiSettings {
  /// 预设 id（siliconflow / … / custom），仅用于回显
  final String provider;
  final String baseUrl;
  final String model;
  final String apiKey;

  /// 每次推荐几本书
  final int tipCount;

  /// 追加到内置 prompt 后的用户偏好（空 = 无）
  final String extraPrompt;

  const AiSettings({
    required this.provider,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    this.tipCount = defaultTipCount,
    this.extraPrompt = '',
  });

  /// 未保存过配置时设置页的初始值：首个预设
  factory AiSettings.initial() => AiSettings(
    provider: aiProviders.first.id,
    baseUrl: aiProviders.first.baseUrl,
    model: '',
    apiKey: '',
  );

  bool get hasKey => apiKey.isNotEmpty;

  /// 规范化：去空白、地址去结尾 `/`、数量夹在范围内
  AiSettings normalized() => AiSettings(
    provider: provider.trim(),
    baseUrl: normalizeBaseUrl(baseUrl),
    model: model.trim(),
    apiKey: apiKey.trim(),
    tipCount: tipCount.clamp(1, maxTipCount),
    extraPrompt: extraPrompt.trim(),
  );

  /// 返回第一条不满足的规则；全部满足返回 null
  String? validate() {
    if (!(baseUrl.startsWith('https://') || baseUrl.startsWith('http://'))) {
      return '接口地址需以 http:// 或 https:// 开头';
    }
    if (apiKey.isEmpty) return '请填写 API Key';
    if (model.isEmpty) return '请选择或填写模型';
    if (extraPrompt.runes.length > maxExtraPromptChars) {
      return '补充要求最多 $maxExtraPromptChars 字';
    }
    return null;
  }

  bool get isComplete => validate() == null;

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'base_url': baseUrl,
    'model': model,
    'api_key': apiKey,
    'tip_count': tipCount,
    'extra_prompt': extraPrompt,
  };

  static AiSettings? fromJson(Object? raw) {
    if (raw is! Map) return null;
    String str(String k) => raw[k]?.toString() ?? '';
    final count = raw['tip_count'];
    return AiSettings(
      provider: str('provider'),
      baseUrl: str('base_url'),
      model: str('model'),
      apiKey: str('api_key'),
      tipCount: count is int ? count : defaultTipCount,
      extraPrompt: str('extra_prompt'),
    );
  }
}

/// 去掉首尾空白与结尾 `/`，便于拼接 `/chat/completions`
String normalizeBaseUrl(String url) =>
    url.trim().replaceFirst(RegExp(r'/+$'), '');

/// Hive 读写；单条记录存为 Map
class AiSettingsStore {
  static const _key = 'ai_finder_settings';

  AiSettings? load() => AiSettings.fromJson(HiveService.authBox.get(_key));

  Future<void> save(AiSettings settings) =>
      HiveService.authBox.put(_key, settings.toJson());
}
