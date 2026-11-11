import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/display_book.dart';

/// 搜索来源扩展点。
///
/// 搜索页不认识任何具体来源，只按来源声明的能力渲染：来源标签、筛选项、结果样式、
/// 行尾操作与「最佳匹配」主按钮都由来源自己提供。
/// 新增来源 = 在 `sources/` 新建一个实现 + 在 `search_sources_registry.dart` 注册一行。
abstract class SearchSource {
  const SearchSource();

  /// 稳定标识，会持久化（Hive `default_search_source`）。上线后不要改。
  String get id;

  IconData get icon;

  String label(AppLocalizations t);

  /// 来源是否可直接搜索（如需先登录/连接）。在 build 中 watch。
  ProviderListenable<bool> get readyProvider;

  /// 未就绪时结果区展示的引导（如「扫码连接」）。
  Widget buildSetup(BuildContext context, WidgetRef ref);

  /// 该来源支持的筛选组；值为空表示「全部」。
  List<SearchFilterGroup> filters(AppLocalizations t, String locale);

  String hint(AppLocalizations t, SearchFilterValues filters) =>
      t.get('search_for_books');

  /// 当前筛选下结果的展示样式（如微信读书「文章」用纯文本样式）。
  SearchResultLayout layoutFor(SearchFilterValues filters) =>
      SearchResultLayout.books;

  /// 是否把同书名同作者的多个上传合并为一行（多版本）。
  bool get mergesEditions => false;

  /// 取一页结果。[cursor] 为上一页返回的 [SearchPage.nextCursor]，首页为 null。
  Future<SearchPage> fetch(
    Ref ref,
    String query,
    SearchFilterValues filters,
    Object? cursor,
  );

  /// 点击结果（[filters] 为产生该结果时的筛选，如用于区分书籍 / 文章）。
  void open(
    BuildContext context,
    WidgetRef ref,
    DisplayBook book,
    SearchFilterValues filters,
  );

  /// 结果行的辅助信息（格式 · 大小 · 年份 / 分类 · 价格等）。
  List<String> describe(DisplayBook book, AppLocalizations t);

  /// 结果行尾操作（如下载按钮）；null 时显示箭头。
  Widget? buildRowAction(
    BuildContext context,
    WidgetRef ref,
    DisplayBook book,
  ) => null;

  /// 「最佳匹配」卡片主按钮；null 时只显示「详情」。
  Widget? buildPrimaryAction(
    BuildContext context,
    WidgetRef ref,
    DisplayBook book,
  ) => null;

  /// 版本标签文案（仅 [mergesEditions] 为 true 时使用），如 `EPUB 2.1 MB`。
  String editionLabel(DisplayBook book) => book.tag ?? book.title;
}

enum SearchResultLayout { books, text }

/// 筛选组的展示方式：选项少平铺成标签（点一下生效）；选项多收进底部面板。
enum SearchFilterDisplay { inline, sheet }

typedef SearchFilterValues = Map<String, String?>;

class SearchFilterOption {
  /// 传给来源的值；null 表示「全部 / 不限」。
  final String? value;
  final String label;

  const SearchFilterOption(this.value, this.label);
}

class SearchFilterGroup {
  final String id;
  final String title;
  final List<SearchFilterOption> options;
  final SearchFilterDisplay display;

  /// 为 true 时必须选中一项（如微信读书的书籍/公众号/文章），不可取消。
  final bool required;

  /// 未选择时的值；required 组必须给出。
  final String? defaultValue;

  /// 是否把选择记到本地，下次搜索默认带上（如常用格式）。
  final bool remember;

  const SearchFilterGroup({
    required this.id,
    required this.title,
    required this.options,
    this.display = SearchFilterDisplay.inline,
    this.required = false,
    this.defaultValue,
    this.remember = false,
  });

  String labelOf(String? value) {
    for (final o in options) {
      if (o.value == value) return o.label;
    }
    return options.first.label;
  }
}

class SearchPage {
  final List<DisplayBook> items;

  /// 下一页游标；null 表示没有更多。
  final Object? nextCursor;

  /// 有总页数概念的来源填写，用于显示「第 x/y 页」。
  final int? currentPage;
  final int? totalPages;

  const SearchPage({
    required this.items,
    this.nextCursor,
    this.currentPage,
    this.totalPages,
  });
}
