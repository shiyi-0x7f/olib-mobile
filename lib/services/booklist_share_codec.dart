import 'dart:convert';
import 'dart:io' show gzip;

import 'package:olib_api_plugin/olib_api_plugin.dart';

class BooklistShareData {
  final List<BooklistEntry> entries;
  final String? name;
  final DateTime? exportedAt;

  const BooklistShareData({
    required this.entries,
    this.name,
    this.exportedAt,
  });

  bool get hasMetadata => entries.any((e) => e.title != null);
  int get length => entries.length;
}

class BooklistEntry {
  final String id;
  final String? title;
  final String? author;
  final String? hash;

  const BooklistEntry({
    required this.id,
    this.title,
    this.author,
    this.hash,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        if (title != null) 't': title,
        if (author != null) 'a': author,
        if (hash != null) 'h': hash,
      };

  factory BooklistEntry.fromJson(Map<String, dynamic> j) => BooklistEntry(
        id: j['id'].toString(),
        title: j['t'] as String?,
        author: j['a'] as String?,
        hash: j['h'] as String?,
      );

  factory BooklistEntry.fromBook(Book b) => BooklistEntry(
        id: b.id.toString(),
        title: b.title,
        author: b.author,
        hash: b.hash,
      );
}

/// 统一的书单编解码。
///
/// 三种载体：
/// - 紧凑 URI:       olib://booklist?ids=123,456,789  （二维码首选）
/// - 完整 URI:       `olib://booklist?d=<base64url(gzip(json))>`  （口令/带元数据二维码）
/// - JSON 文件 (.json):  {"v":1,"name":...,"exportedAt":...,"books":[...]}
///
/// 兼容旧格式 `olib_share:123,456`。
class BooklistShareCodec {
  static const String scheme = 'olib';
  static const String host = 'booklist';
  static const int formatVersion = 1;

  /// 二维码可承载的近似字符上限（QR v40 + 中等纠错，留余量）
  static const int qrSafeChars = 1800;

  /// 把书单编成紧凑 URI（仅 ID）
  static String encodeIdsUri(Iterable<String> ids) {
    final cleaned = ids.where((e) => e.trim().isNotEmpty).join(',');
    return '$scheme://$host?ids=$cleaned';
  }

  /// 把书单编成完整 URI（含元数据）
  static String encodeFullUri(BooklistShareData data) {
    final payload = <String, dynamic>{
      'v': formatVersion,
      if (data.name != null) 'n': data.name,
      if (data.exportedAt != null) 'e': data.exportedAt!.toIso8601String(),
      'b': data.entries.map((e) => e.toJson()).toList(),
    };
    final raw = utf8.encode(jsonEncode(payload));
    final compressed = gzip.encode(raw);
    final b64 = base64UrlEncode(compressed);
    return '$scheme://$host?d=$b64';
  }

  /// 为二维码挑选合适的编码：先试完整版，超长则降级到纯 ID。
  static String encodeForQr(BooklistShareData data) {
    final full = encodeFullUri(data);
    if (full.length <= qrSafeChars) return full;
    return encodeIdsUri(data.entries.map((e) => e.id));
  }

  /// 把书单序列化为 JSON 文件内容（导出/备份）
  static String encodeJsonFile(BooklistShareData data) {
    return const JsonEncoder.withIndent('  ').convert({
      'v': formatVersion,
      if (data.name != null) 'name': data.name,
      'exportedAt': (data.exportedAt ?? DateTime.now()).toIso8601String(),
      'books': data.entries
          .map((e) => {
                'id': e.id,
                if (e.title != null) 'title': e.title,
                if (e.author != null) 'author': e.author,
                if (e.hash != null) 'hash': e.hash,
              })
          .toList(),
    });
  }

  /// 万能解析：URI / 旧 olib_share / JSON 文本 都能塞进来
  static BooklistShareData? tryDecode(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // 1) JSON 文件
    if (trimmed.startsWith('{')) {
      try {
        final m = jsonDecode(trimmed) as Map<String, dynamic>;
        return _fromJsonMap(m);
      } catch (_) {}
    }

    // 2) 旧协议 olib_share:id1,id2
    if (trimmed.startsWith('olib_share:')) {
      final body = trimmed.substring('olib_share:'.length);
      final ids = body
          .split(',')
          .map((e) => e.split(':').first.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (ids.isEmpty) return null;
      return BooklistShareData(
        entries: ids.map((id) => BooklistEntry(id: id)).toList(),
      );
    }

    // 3) URI
    Uri? uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      return null;
    }
    if (uri.scheme != scheme || uri.host != host) return null;

    // 3a) 完整版 d=
    final d = uri.queryParameters['d'];
    if (d != null && d.isNotEmpty) {
      try {
        final bytes = base64Url.decode(_padBase64(d));
        final json = utf8.decode(gzip.decode(bytes));
        final m = jsonDecode(json) as Map<String, dynamic>;
        return _fromJsonMap(m, compact: true);
      } catch (_) {
        return null;
      }
    }

    // 3b) 紧凑版 ids=
    final idsParam = uri.queryParameters['ids'];
    if (idsParam != null && idsParam.isNotEmpty) {
      final ids = idsParam
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (ids.isEmpty) return null;
      return BooklistShareData(
        entries: ids.map((id) => BooklistEntry(id: id)).toList(),
        name: uri.queryParameters['n'],
      );
    }

    return null;
  }

  static BooklistShareData _fromJsonMap(Map<String, dynamic> m,
      {bool compact = false}) {
    final booksKey = compact ? 'b' : 'books';
    final nameKey = compact ? 'n' : 'name';
    final dateKey = compact ? 'e' : 'exportedAt';

    final rawBooks = (m[booksKey] ?? m['books'] ?? m['b']) as List?;
    if (rawBooks == null) {
      return const BooklistShareData(entries: []);
    }
    final entries = rawBooks
        .whereType<Map>()
        .map((e) => BooklistEntry.fromJson({
              'id': e['id'],
              't': e['t'] ?? e['title'],
              'a': e['a'] ?? e['author'],
              'h': e['h'] ?? e['hash'],
            }))
        .where((e) => e.id.isNotEmpty)
        .toList();

    DateTime? exportedAt;
    final eRaw = m[dateKey] ?? m['exportedAt'] ?? m['e'];
    if (eRaw is String) {
      exportedAt = DateTime.tryParse(eRaw);
    }

    return BooklistShareData(
      entries: entries,
      name: (m[nameKey] ?? m['name'] ?? m['n']) as String?,
      exportedAt: exportedAt,
    );
  }

  static String _padBase64(String s) {
    final pad = (4 - s.length % 4) % 4;
    return s + '=' * pad;
  }
}
