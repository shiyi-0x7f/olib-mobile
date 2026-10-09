# 更新清单（强制更新 + 下载渠道）

> 2026-10-09 引入，1.4.0 起生效，格式与桌面端 OlibTauri 一致。
> 实现：`lib/services/update/update_manifest.dart`（解析）、`lib/services/update_service.dart`（检查 + 缓存）、
> `lib/widgets/update_dialog.dart`（对话框）。

客户端请求公开仓库最新 Release（`api.github.com/repos/shiyi-0x7f/olib-mobile/releases/latest`），
解析 Release 正文末尾的**隐藏注释**（GitHub 页面上不可见）：

```text
<!-- olib-update
min_version: 1.4.0
百度网盘: https://pan.baidu.com/s/xxxx?pwd=xxxx
夸克网盘: https://pan.quark.cn/s/xxxx?pwd=xxxx
迅雷网盘: https://pan.xunlei.com/s/xxxx?pwd=xxxx
-->
```

| 行                   | 含义                                                                                     |
| -------------------- | ---------------------------------------------------------------------------------------- |
| `min_version: x.y.z` | 当前版本**低于**它 → 强制更新。省略 = 不强制                                             |
| `名称: 链接`         | 对话框里的下载渠道，按书写顺序排列，第一个为主按钮。仅 http/https，名称 ≤ 20 字，最多 8 个 |
| `[FORCE]`            | 旧标记（≤1.3.0 客户端只认它）：比最新版低的客户端一律强制。新发版优先用 `min_version`    |

- 对话框总会追加「官网下载」（11xy.cn `olib-mobile` 项目页）和「GitHub」（Release 页）两个兜底渠道。
- 强制更新时：对话框不可关闭，搜索与下载被拦截（`UpdateService.isBlocked`）。

## 缓存与检查频率

- 首页每 24h 请求一次（登录页、设置页「检查更新」每次都请求）。
- 每次请求成功后把 tag / 正文 / Release 链接写入 Hive `settings` box（`update_cached_*`）；
  跳过请求或请求失败时用缓存重新计算，**强制更新在重启后依然生效**。
- 从未成功请求过（无缓存）且检测失败 → 放行。

## 兼容旧客户端

≤1.3.0 只认正文中的 `[FORCE]`，且会把整段正文（含注释块）原样显示在对话框里。
需要强制旧客户端时，把 `[FORCE]` 写进注释块内（GitHub 页面看不到），并接受旧客户端会看到清单原文。

## 发版时怎么写

1. CI 构建完成后，PanSync 把 APK 上传到网盘（见 [refs/pansync.md](refs/pansync.md)），拿到分享链接。
2. 写好 notes（面向用户），末尾追加清单块，`gh release edit vX.Y.Z -R shiyi-0x7f/olib-mobile --notes-file <文件>`。
3. **只在必要时设置 `min_version`**（旧版接口失效、安全问题等），平时只写网盘链接。
