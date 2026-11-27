/// AI 寻书内置服务商预设（OpenAI 兼容接口），与 OlibTauri `src/api/aiProviders.ts` 保持一致。
///
/// - baseUrl：已对照各家官方文档核实（2026-11）。模型名变动频繁，不在此写死，由设置页调 `/models` 拉取。
/// - signupUrl：注册 / 开通入口。**带推广邀请码的链接只需替换此字段**，其余代码不用动。
/// - 顺序即设置页展示顺序，首项为默认选中；其余服务商走「自定义」。
library;

class AiProvider {
  final String id;
  final String name;
  final String baseUrl;

  /// 注册 / 开通入口（可替换为推广邀请链接）
  final String signupUrl;

  const AiProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.signupUrl,
  });
}

const List<AiProvider> aiProviders = [
  AiProvider(
    id: 'siliconflow',
    name: '硅基流动',
    baseUrl: 'https://api.siliconflow.cn/v1',
    // 推广邀请链接
    signupUrl: 'https://cloud.siliconflow.cn/i/6GFVeIOr',
  ),
  AiProvider(
    id: 'bailian',
    name: '阿里百炼',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    // 阿里云云大使推广链接
    signupUrl:
        'https://www.aliyun.com/minisite/goods?clubTaskBiz=subTask..13026435..10292..&userCode=uyzbu3m2',
  ),
  AiProvider(
    id: 'zhipu',
    name: '智谱',
    // 按量计费的通用接口；勿用 GLM Coding Plan 套餐 Key（条款禁止在第三方应用中调用）
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    // 智谱开放平台邀请链接（被邀请人注册获赠 Tokens 礼包）
    signupUrl:
        'https://www.bigmodel.cn/invite?icode=cvnvIg56YkndmijcWvnVI3HEaazDlIZGj9HxftzTbt4%3D',
  ),
  AiProvider(
    id: 'deepseek',
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com',
    signupUrl: 'https://platform.deepseek.com/',
  ),
  AiProvider(
    id: 'openai',
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    signupUrl: 'https://platform.openai.com/',
  ),
];

const String customProviderId = 'custom';

AiProvider? findAiProvider(String id) {
  for (final p in aiProviders) {
    if (p.id == id) return p;
  }
  return null;
}
