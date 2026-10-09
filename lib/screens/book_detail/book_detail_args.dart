import 'package:olib_api_plugin/olib_api_plugin.dart';

/// 书详情页路由参数。新代码应使用这个；旧代码直接传 [Book] 也兼容。
///
/// [fromAi]: 进入路径是否来自 AI 寻书结果。
/// - true → 下载走 backend `/books/download-url`（消耗免费下载配额）
/// - false → 下载走用户自己的 z站 账号（不消耗后端配额）
class BookDetailArgs {
  final Book book;
  final bool fromAi;

  const BookDetailArgs({
    required this.book,
    this.fromAi = false,
  });
}
