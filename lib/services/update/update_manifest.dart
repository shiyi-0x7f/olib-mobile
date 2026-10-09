/// 解析 GitHub Release 正文里的「更新清单」隐藏块（与桌面端 OlibTauri 同格式）。
///
/// 发布时在 Release 正文末尾写一段 HTML 注释（GitHub 页面上不可见）：
///
/// ```text
/// <!-- olib-update
/// min_version: 1.4.0
/// 百度网盘: https://pan.baidu.com/s/xxx?pwd=xxxx
/// 夸克网盘: https://pan.quark.cn/s/xxx?pwd=xxxx
/// -->
/// ```
///
/// - `min_version`：低于此版本的客户端强制更新（可省略 = 不强制）
/// - 其余 `名称: 链接` 行：更新对话框里的下载渠道（仅接受 http/https）
/// - 正文任意位置的 `[FORCE]` / `[FORCE_UPDATE]`：旧版强制更新标记，仍兼容
///
/// 格式说明见 `dev_docs/update-manifest.md`。
library;

class UpdateLink {
  final String name;
  final String url;

  const UpdateLink(this.name, this.url);
}

class UpdateManifest {
  final String? minVersion;
  final List<UpdateLink> links;

  /// 正文含 `[FORCE]` 标记：比最新版低的客户端一律强制更新
  final bool forceAll;

  /// 去掉清单块与强制标记后的正文，用作更新说明
  final String notes;

  const UpdateManifest({
    this.minVersion,
    this.links = const [],
    this.forceAll = false,
    this.notes = '',
  });

  static const _blockStart = '<!-- olib-update';
  static const _blockEnd = '-->';
  static const _maxLinks = 8;
  static const _maxNameChars = 20;
  static final _forceRe = RegExp(r'\[FORCE(_UPDATE)?\]', caseSensitive: false);

  factory UpdateManifest.parse(String body) {
    String? minVersion;
    final links = <UpdateLink>[];
    var notes = body;

    final start = body.indexOf(_blockStart);
    if (start >= 0) {
      final contentStart = start + _blockStart.length;
      final endIdx = body.indexOf(_blockEnd, contentStart);
      final contentEnd = endIdx >= 0 ? endIdx : body.length;
      final blockEnd = endIdx >= 0 ? endIdx + _blockEnd.length : body.length;

      for (final line in body.substring(contentStart, contentEnd).split('\n')) {
        final kv = _splitKeyValue(line);
        if (kv == null) continue;
        final (key, value) = kv;
        if (key.toLowerCase() == 'min_version') {
          final v = value.startsWith('v') ? value.substring(1) : value;
          if (v.isNotEmpty) minVersion = v;
        } else if (_isHttpUrl(value) &&
            key.isNotEmpty &&
            key.runes.length <= _maxNameChars &&
            links.length < _maxLinks) {
          links.add(UpdateLink(key, value));
        }
      }
      notes = body.substring(0, start) + body.substring(blockEnd);
    }

    return UpdateManifest(
      minVersion: minVersion,
      links: links,
      forceAll: _forceRe.hasMatch(body),
      notes: notes.replaceAll(_forceRe, '').trim(),
    );
  }

  /// 在第一个半角或全角冒号处切分（链接里的 `https:` 在其后，不受影响）
  static (String, String)? _splitKeyValue(String line) {
    final trimmed = line.trim();
    final idx = trimmed.indexOf(RegExp('[:：]'));
    if (idx < 0) return null;
    return (
      trimmed.substring(0, idx).trim(),
      trimmed.substring(idx + 1).trim(),
    );
  }

  static bool _isHttpUrl(String s) =>
      (s.startsWith('https://') || s.startsWith('http://')) &&
      !s.contains(RegExp(r'\s'));
}

/// 语义化版本比较：`latest` 是否比 `current` 新（只比较数字段，非数字段按 0）
bool isNewerVersion(String latest, String current) {
  List<int> parse(String s) =>
      s.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final l = parse(latest);
  final c = parse(current);
  final n = l.length > c.length ? l.length : c.length;
  for (var i = 0; i < n; i++) {
    final lv = i < l.length ? l[i] : 0;
    final cv = i < c.length ? c[i] : 0;
    if (lv != cv) return lv > cv;
  }
  return false;
}
