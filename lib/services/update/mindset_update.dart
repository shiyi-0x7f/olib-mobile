/// MindSet（www.11xy.cn）查更新与下载渠道接口的解析，与 OlibTauri `src-tauri/src/update_check.rs` 一致。
///
/// - `GET /api/projects/olib-mobile/update-check?current=x.y.z` →
///   `{ latest_version, min_version, has_update, force, releases[], page_url }`：
///   版本比较与强制更新判定（后台 `min_version` / 勾选强制更新的版本）均由服务端完成。
/// - `GET /api/projects/olib-mobile/sources` → 下载渠道列表；只取公开网盘链接。
library;

/// 更新对话框里的一个下载按钮
class UpdateLink {
  final String name;
  final String url;

  const UpdateLink(this.name, this.url);
}

/// 项目页（下载入口）：接口未返回 page_url 时兜底
const String mindsetProjectPageUrl = 'https://www.11xy.cn/projects/olib-mobile';

class MindsetUpdate {
  final bool hasUpdate;
  final bool force;
  final String latestVersion;

  /// 比当前版本新的各版本更新说明（新→旧）
  final String notes;
  final String pageUrl;

  const MindsetUpdate({
    required this.hasUpdate,
    required this.force,
    required this.latestVersion,
    required this.notes,
    required this.pageUrl,
  });

  /// [current]：请求时上报的当前版本，接口未返回 latest_version 时用它
  factory MindsetUpdate.fromJson(Map<String, dynamic> json, String current) {
    final pageUrl = json['page_url'];
    final latest = json['latest_version'];
    final releases = json['releases'];
    return MindsetUpdate(
      hasUpdate: json['has_update'] == true,
      force: json['force'] == true,
      latestVersion: latest is String && latest.isNotEmpty ? latest : current,
      notes: mergeNotes(releases is List ? releases : const []),
      pageUrl: pageUrl is String && pageUrl.startsWith('http')
          ? pageUrl
          : mindsetProjectPageUrl,
    );
  }
}

/// 多个版本的更新说明合并展示：只有一个版本时不加标题
String mergeNotes(List<dynamic> releases) {
  final withNotes = [
    for (final r in releases)
      if (r is Map &&
          r['notes'] is String &&
          (r['notes'] as String).trim().isNotEmpty)
        (version: '${r['version']}', notes: (r['notes'] as String).trim()),
  ];
  if (withNotes.isEmpty) return '';
  if (withNotes.length == 1) return withNotes.single.notes;
  return withNotes.map((r) => 'v${r.version}\n${r.notes}').join('\n\n');
}

const Map<String, String> _panNames = {
  'baidu_pan': '百度网盘',
  'quark_pan': '夸克网盘',
  'xunlei_pan': '迅雷网盘',
};

/// 只保留公开可用的网盘链接（分享链接已含 ?pwd=），按百度 / 夸克 / 迅雷排序
List<UpdateLink> parseSourceLinks(List<dynamic> sources) {
  final order = _panNames.keys.toList();
  final picked = <(int, UpdateLink)>[];
  for (final s in sources) {
    if (s is! Map || s['locked'] == true) continue;
    final type = s['source_type'];
    final name = _panNames[type];
    final url = s['url'];
    if (name == null || url is! String || !url.startsWith('http')) continue;
    picked.add((order.indexOf(type as String), UpdateLink(name, url)));
  }
  picked.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final p in picked) p.$2];
}
