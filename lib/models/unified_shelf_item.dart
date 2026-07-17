import '../models/display_book.dart';

/// 书架来源
enum ShelfSource { library, weread }

/// 统一书架条目 — 合并 z站收藏和微信读书书架
class UnifiedShelfItem {
  final ShelfSource source;
  final DisplayBook displayBook;
  final String rawBookId;
  final int? lastReadTime;
  final bool isPurchased;

  const UnifiedShelfItem({
    required this.source,
    required this.displayBook,
    required this.rawBookId,
    this.lastReadTime,
    this.isPurchased = false,
  });
}
