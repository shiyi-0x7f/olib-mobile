import '../models/display_book.dart';

/// 同一本书的多个上传（不同格式 / 版本）。[primary] 为结果里最先出现的那条。
class EditionGroup {
  final List<DisplayBook> editions;

  const EditionGroup(this.editions);

  DisplayBook get primary => editions.first;
  bool get hasVariants => editions.length > 1;
}

/// 把书名 + 作者归一化后相同的结果合并成一组，保持原结果顺序（按每组首次出现）。
///
/// 只作用于已加载的结果；翻页后新到的同书版本会并入已有组。
List<EditionGroup> groupEditions(List<DisplayBook> books) {
  final order = <String>[];
  final groups = <String, List<DisplayBook>>{};
  for (final b in books) {
    final key = editionKey(b);
    final list = groups[key];
    if (list == null) {
      groups[key] = [b];
      order.add(key);
    } else {
      list.add(b);
    }
  }
  return [for (final k in order) EditionGroup(groups[k]!)];
}

/// 归一化键：小写、去掉空白与常见标点，书名与作者各自归一后拼接。
String editionKey(DisplayBook b) =>
    '${_normalize(b.title)}|${_normalize(b.author ?? '')}';

final _noise = RegExp(r'[\s\p{P}\p{S}]+', unicode: true);

String _normalize(String s) => s.toLowerCase().replaceAll(_noise, '');
