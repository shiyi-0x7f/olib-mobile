# 检查更新（强制更新 + 下载渠道）

> 1.6.0 起改查 MindSet（www.11xy.cn），国内可直连，与电脑端 OlibTauri `src-tauri/src/update_check.rs` 一致。
> 实现：`lib/services/update/mindset_update.dart`（解析）、`lib/services/update_service.dart`（检查 + 缓存）、
> `lib/widgets/update_dialog.dart`（对话框）。

## 接口

| 请求 | 用途 |
| --- | --- |
| `GET https://www.11xy.cn/api/projects/olib-mobile/update-check?current=x.y.z` | `{ latest_version, min_version, has_update, force, releases[], page_url }`。版本比较与强制更新（后台 `min_version` / 勾选强制更新的版本）**由服务端判定**，客户端照单展示 |
| `GET https://www.11xy.cn/api/projects/olib-mobile/sources` | 下载渠道。只取 `locked != true` 的百度 / 夸克 / 迅雷网盘链接，按此顺序排列；会员 / 对象存储渠道不显示 |

- `releases[]` 是比当前版本新的各版本（新→旧）；多个版本时说明按 `v版本` 分段合并，只有一个时不加标题。
- 对话框按钮：网盘直链 → 「官网下载」（`page_url`，缺失时用项目页）→ 「GitHub」（Releases 最新页）。
- 强制更新时：对话框不可关闭，搜索与下载被拦截（`UpdateService.isBlocked`）。
- 更新说明在显示前会去掉常见 Markdown 标记（`markdownToPlainText`）。
- 渠道接口失败只记日志，不影响查更新。

## 缓存与检查频率

- 首页每 24h 请求一次（登录页、设置页「检查更新」每次都请求）。
- 请求成功后把两个接口的原始响应与**当时的版本号**写入 Hive `settings` box（`update_cached_mindset` / `update_cached_sources` / `update_cached_for_version`）；
  跳过请求或请求失败时用缓存重新计算，**强制更新在重启后依然生效**。服务端结论相对请求时的版本，App 升级后缓存自动作废。
- 从未成功请求过（无可用缓存）且检测失败 → 放行。

## 发版时怎么写

1. CI 构建完成后，PanSync 把 APK 上传到网盘（见 [refs/pansync.md](refs/pansync.md)），同步到 MindSet 项目 `olib-mobile` 的下载渠道。
2. 在 MindSet 后台发版记录里填版本号与更新说明（面向用户）；**只在必要时**设置 `min_version` 或勾选强制更新。

## 兼容旧客户端（≤1.5.x，仍查 GitHub Release 正文）

旧客户端请求 `api.github.com/repos/shiyi-0x7f/olib-mobile/releases/latest`，解析正文末尾隐藏清单块：

```text
<!-- olib-update
min_version: 1.4.0
百度网盘: https://pan.baidu.com/s/xxxx?pwd=xxxx
-->
```

只要还有旧客户端在用，发版时 GitHub Release 正文仍需维护：纯文本 notes + 清单块（网盘链接、必要时 `min_version`）。≤1.3.0 只认正文中的 `[FORCE]`，单独放在最后一行。
