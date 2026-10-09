import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../services/weread/weread_models.dart';

/// 数据源标识
enum BookSource { zlibrary, weread }

/// 统一书籍展示模型
///
/// 解耦 UI 组件（BookCard / BookListTile / BookHeroSection）与具体数据源。
/// 通过 [Book.toDisplay] 和 [WereadBookInfo.toDisplay] extension 方法创建。
class DisplayBook {
  final String id;
  final String title;
  final String? author;
  final String? cover;

  /// 卡片左上标签（z站: 格式 "EPUB"；WeRead: 分类 "科幻小说"）
  final String? tag;

  /// 卡片顶部辅助标签（z站: 年份；微信读书非搜索结果: 评分）
  final String? tagExtra;

  /// 评分/兴趣分（z站: interestScore；WeRead: ratingScore）
  final String? score;

  /// 卡片底部右侧辅助文本（各数据源含义不同：z站=文件大小；WeRead=在读人数）
  final String? meta;

  /// 详情页简介
  final String? description;

  /// 出版社
  final String? publisher;

  /// 数据来源
  final BookSource source;

  /// 原始对象引用 — 用于路由传参等类型特定操作
  final dynamic original;

  const DisplayBook({
    required this.id,
    required this.title,
    this.author,
    this.cover,
    this.tag,
    this.tagExtra,
    this.score,
    this.meta,
    this.description,
    this.publisher,
    required this.source,
    this.original,
  });

  /// 是否来自 z站
  bool get isZLibrary => source == BookSource.zlibrary;

  /// 是否来自微信读书
  bool get isWeread => source == BookSource.weread;

  /// 获取原始 z站 Book 对象（仅当 source == zlibrary 时有效）
  Book? get asZLibBook => isZLibrary ? original as Book? : null;

  /// 获取原始 WeRead BookInfo 对象（仅当 source == weread 时有效）
  WereadBookInfo? get asWereadBook =>
      isWeread ? original as WereadBookInfo? : null;
}

// ═══════════════════════════════════════════════════════════════════
// Extension 适配器
// ═══════════════════════════════════════════════════════════════════

/// z站 Book → DisplayBook
extension BookToDisplay on Book {
  DisplayBook toDisplay() => DisplayBook(
    id: id.toString(),
    title: title,
    author: author,
    cover: cover,
    tag: extension != null && extension!.isNotEmpty
        ? extension!.toUpperCase()
        : null,
    tagExtra: (year != null && year != 0) ? '$year' : null,
    score: interestScore,
    meta: filesizeString,
    description: description,
    publisher: publisher,
    source: BookSource.zlibrary,
    original: this,
  );
}

/// WeRead BookInfo → DisplayBook
extension WereadBookInfoToDisplay on WereadBookInfo {
  DisplayBook toDisplay({int? readingCount}) => DisplayBook(
    id: bookId,
    title: title,
    author: author,
    cover: cover,
    tag: category,
    tagExtra: ratingScore != null
        ? '⭐${ratingScore!.toStringAsFixed(1)}'
        : null,
    score: ratingScore?.toStringAsFixed(1),
    meta: readingCount != null ? '$readingCount人在读' : null,
    description: intro,
    publisher: publisher,
    source: BookSource.weread,
    original: this,
  );
}

/// WeRead ShelfBook → DisplayBook
extension ShelfBookToDisplay on ShelfBook {
  DisplayBook toDisplay() => DisplayBook(
    id: bookId,
    title: title,
    author: author,
    cover: cover,
    tag: category,
    tagExtra: isFinished ? '✅ 已读完' : null,
    source: BookSource.weread,
    original: this,
  );
}

/// WeRead SearchResultBook → DisplayBook
extension WereadSearchResultToDisplay on SearchResultBook {
  DisplayBook toDisplay({String? priceLabel, bool showReadingCount = true}) =>
      DisplayBook(
        id: bookInfo.bookId,
        title: bookInfo.title,
        author: bookInfo.author,
        cover: _wereadSearchCover(bookInfo.cover),
        tag: bookInfo.category,
        // Search results render the rating once: on the cover or in the list row.
        score: bookInfo.ratingScore?.toStringAsFixed(1),
        meta:
            priceLabel ??
            (showReadingCount && readingCount != null
                ? '$readingCount人在读'
                : null),
        description: bookInfo.intro,
        publisher: bookInfo.publisher,
        source: BookSource.weread,
        original: bookInfo,
      );
}

/// 搜索接口的 s_ 封面是缩略图；仅替换已知的微信读书封面 CDN 路径。
String? _wereadSearchCover(String? cover) {
  if (cover == null || cover.isEmpty) return cover;
  final uri = Uri.tryParse(cover);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'cdn.weread.qq.com' ||
      !uri.path.startsWith('/weread/cover/')) {
    return cover;
  }

  final segments = uri.pathSegments.toList();
  final filename = segments.last;
  if (!filename.startsWith('s_')) return cover;
  segments[segments.length - 1] = 't6_${filename.substring(2)}';
  return uri.replace(pathSegments: segments).toString();
}

/// WeRead RecommendBook → DisplayBook
extension RecommendBookToDisplay on RecommendBook {
  DisplayBook toDisplay() => DisplayBook(
    id: bookId,
    title: title,
    author: author,
    cover: cover,
    tag: category,
    tagExtra: ratingScore != null
        ? '⭐${ratingScore!.toStringAsFixed(1)}'
        : null,
    score: ratingScore?.toStringAsFixed(1),
    meta: readingCount != null ? '$readingCount人在读' : null,
    description: intro,
    publisher: publisher,
    source: BookSource.weread,
    original: this,
  );
}
