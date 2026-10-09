/// 环境配置 — 后端 API 基地址
///
/// 开发时使用本地端口，发布时使用生产 URL。
/// 通过 --dart-define=BACKEND_URL=xxx 可覆盖默认值。
class Env {
  Env._();

  /// 后端 API 基地址（AI 智阅锦囊等）
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://olibai.11xy.cn',
  );

  /// 统一身份基座 SCC（微信公众号扫码登录，签发 client JWT）
  /// 与桌面端 OlibTauri 按 unionid 收敛为同一真人（配额/社群身份跨端一致）。
  static const String sccUrl = String.fromEnvironment(
    'SCC_URL',
    defaultValue: 'https://scc.11xy.cn',
  );

  /// 本应用在 SCC 后台注册的数字 app_id（Olib Mobile 独立应用）
  static const int sccAppId = int.fromEnvironment('SCC_APP_ID', defaultValue: 9);

  /// 生产环境后端 URL（供参考 / CI 使用）
  static const String prodBackendUrl = 'https://bookbook.space';

  /// 当前是否为生产模式
  static bool get isProduction => backendUrl == prodBackendUrl;
}

