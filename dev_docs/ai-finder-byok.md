# AI 寻书（BYOK）

AI 寻书（阅读锦囊）由用户自带 API Key，本机直连 OpenAI 兼容接口，不再经过 olibai 服务端，也不再需要微信扫码、不受服务端次数限制。微信扫码（`backendAuthProvider` / `QrAuthScreen`）仍用于意见反馈与社群版。

与电脑端 OlibTauri 对齐（其文档：`OlibTauri/dev_docs/ai-finder-byok.md`）：prompt、JSON 提取、结果校验、错误翻译、推理模型参数兼容、服务商预设一致。

## 模块

| 位置 | 职责 |
| --- | --- |
| `lib/services/ai/ai_providers.dart` | 内置服务商预设（地址 + 注册链接），与 `OlibTauri/src/api/aiProviders.ts` 一致 |
| `lib/services/ai/ai_settings.dart` | 配置模型、规范化与校验、Hive `auth` box 持久化（键 `ai_finder_settings`） |
| `lib/services/ai/ai_prompt.dart` | prompt、JSON 提取（兼容代码块 / `<think>`）、结果校验 |
| `lib/services/ai/ai_client.dart` | `POST /chat/completions`、`GET /models`、错误翻译、推理模型参数兼容、解析失败重试 |
| `lib/services/ai_service.dart` | `AiService` 抽象 + `ByokAiService`；未配置抛 `AiNotConfigured` |
| `lib/providers/ai_settings_provider.dart` | 已保存配置；`saveAndTest` / `listModels` |
| `lib/screens/prescriber/ai_config_screen.dart` | 设置页（路由 `/prescriber/ai-config`），保存并测试通过 `pop(true)` |
| `lib/screens/prescriber/widgets/ai_model_picker.dart` | 可搜索的模型选择底部弹层 |

## 流程

- 首页「AI 寻书」直接进寻书页，无需登录；寻书页右上角齿轮进设置。
- 寻书时未配置 → `PrescriberNotifier.diagnose` 抛 `AiNotConfigured`（状态回到 idle）→ 寻书页打开设置页 → 保存并测试通过后自动继续这次寻书。
- `aiServiceProvider` 在每次寻书时才读取最新配置，修改配置不会清掉已有结果。
- 推荐结果的书走**用户自己的 z站 账号**下载（与普通搜索一致）；原 `fromAi` → `/books/download-url` 公共池免费下载链路已删除（BYOK 后 AI 调用不再受后端次数闸门约束）。社群版经 olibai 中介下载的分支保留，`backend_books_api.dart` / `quota_phrases.dart` 现仅社群版使用，已列入 `scripts/publish-exclude.txt`。

## 约定

- 调用参数：temperature 0.8、输出上限 4096 token、只用中文 prompt；推理模型返回 400 指出 `max_tokens` / `temperature` 不支持时，改用 `max_completion_tokens`、不传 temperature 重试一次。
- 超时：对话 90s、模型列表 15s。
- 「测试」只看请求是否成功，不要求返回内容。测试失败时配置仍已保存（便于改一项再试）。
- 推荐数量档位 3 / 5 / 8（存储夹在 1–10）；补充要求 ≤ 300 字，追加在格式要求之后，不开放整段 prompt 覆写。
- Key 只存本机 Hive `auth` box，不写日志；错误信息常驻显示且可复制。
- 服务商注册链接含推广邀请码（与电脑端一致，用户已知情决定保留）；只需替换 `signupUrl` 字段。
- 英文界面同样使用中文 prompt（与电脑端一致），推荐内容为中文。

## 测试

`flutter test test/utils/ai_finder_test.dart`：prompt、JSON 提取、结果校验、配置规范化、错误翻译，以及用假 HTTP 适配器验证推理模型参数降级与格式异常重试。
