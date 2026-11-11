import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'search_source.dart';
import 'sources/weread_search_source.dart';
import 'sources/zlibrary_search_source.dart';

/// 已注册的搜索来源（顺序即标签顺序，第一个为默认来源）。
/// 新增来源：在 `sources/` 实现 [SearchSource]，然后在这里加一行。
final searchSourcesProvider = Provider<List<SearchSource>>(
  (ref) => const [ZLibrarySearchSource(), WereadSearchSource()],
);

SearchSource findSearchSource(List<SearchSource> sources, String? id) =>
    sources.firstWhere((s) => s.id == id, orElse: () => sources.first);
