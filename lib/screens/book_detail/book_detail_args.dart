import 'package:olib_api_plugin/olib_api_plugin.dart';

/// 书详情页路由参数。新代码应使用这个；旧代码直接传 [Book] 也兼容。
class BookDetailArgs {
  final Book book;

  /// 来源书卡的封面 Hero tag（见 bookCoverHeroTag）；null = 无共享元素过渡
  final Object? heroTag;

  const BookDetailArgs({required this.book, this.heroTag});
}
