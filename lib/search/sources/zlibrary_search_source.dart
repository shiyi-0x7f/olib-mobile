import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../../constants/search_filters.dart';
import '../../l10n/app_localizations.dart';
import '../../models/display_book.dart';
import '../../providers/zlibrary_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/book_download/book_download_button.dart';
import '../search_source.dart';

/// z站：支持格式 / 语言 / 排序筛选、多版本合并、行内直接下载。
class ZLibrarySearchSource extends SearchSource {
  const ZLibrarySearchSource();

  static const _pageSize = 20;
  static const fFormat = 'format';
  static const fLanguage = 'language';
  static const fOrder = 'order';

  /// 搜索结果里 z站 总是可用（未登录由全局登录流程拦截）。
  static final _ready = Provider<bool>((ref) => true);

  @override
  String get id => 'zlibrary';

  @override
  IconData get icon => Icons.local_library_outlined;

  @override
  String label(AppLocalizations t) => t.get('source_zlibrary');

  @override
  ProviderListenable<bool> get readyProvider => _ready;

  @override
  Widget buildSetup(BuildContext context, WidgetRef ref) =>
      const SizedBox.shrink();

  @override
  bool get mergesEditions => true;

  @override
  List<SearchFilterGroup> filters(AppLocalizations t, String locale) {
    final isZh = locale.startsWith('zh');
    final ext = getExtensionDisplayNames(locale);
    final lang = getLanguageDisplayNames(locale);
    final order = getOrderDisplayNames(locale);
    return [
      SearchFilterGroup(
        id: fFormat,
        title: isZh ? '格式' : 'Format',
        display: SearchFilterDisplay.sheet,
        remember: true,
        options: [
          for (final e in searchExtensions.entries)
            if (e.value != null)
              SearchFilterOption(e.value, ext[e.key] ?? e.key),
        ],
      ),
      SearchFilterGroup(
        id: fLanguage,
        title: isZh ? '语言' : 'Language',
        display: SearchFilterDisplay.sheet,
        remember: true,
        options: [
          for (final e in searchLanguages.entries)
            if (lang.containsKey(e.key))
              SearchFilterOption(e.value, lang[e.key]!),
        ],
      ),
      SearchFilterGroup(
        id: fOrder,
        title: isZh ? '排序' : 'Sort',
        display: SearchFilterDisplay.sheet,
        options: [
          for (final e in searchOrders.entries)
            SearchFilterOption(e.value, order[e.key] ?? e.key),
        ],
      ),
    ];
  }

  @override
  Future<SearchPage> fetch(
    Ref ref,
    String query,
    SearchFilterValues filters,
    Object? cursor,
  ) async {
    final page = cursor as int? ?? 1;
    final languages = filters[fLanguage] == null ? null : [filters[fLanguage]!];
    final extensions = filters[fFormat] == null ? null : [filters[fFormat]!];
    final order = filters[fOrder];

    ApiResponse<List<Book>>? response;
    response ??= await ref
        .read(zlibraryApiProvider)
        .search(
          message: query,
          languages: languages,
          extensions: extensions,
          order: order,
          page: page,
          limit: _pageSize,
        );
    if (!response.success) {
      throw StateError(response.error ?? 'Search failed');
    }
    final rawTotal = response.meta?['total_pages'];
    final totalPages = rawTotal is int ? rawTotal : 1;
    return SearchPage(
      items: (response.data ?? const <Book>[])
          .map((b) => b.toDisplay())
          .toList(),
      nextCursor: page < totalPages ? page + 1 : null,
      currentPage: page,
      totalPages: totalPages,
    );
  }

  @override
  void open(
    BuildContext context,
    WidgetRef ref,
    DisplayBook book,
    SearchFilterValues filters,
  ) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.bookDetail, arguments: book.asZLibBook);
  }

  @override
  List<String> describe(DisplayBook book, AppLocalizations t) => [
    if (book.tag != null) book.tag!,
    if (book.meta != null && book.meta!.isNotEmpty) book.meta!,
    if (book.tagExtra != null) book.tagExtra!,
  ];

  @override
  String editionLabel(DisplayBook book) => [
    book.tag,
    book.meta,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' ');

  @override
  Widget? buildRowAction(
    BuildContext context,
    WidgetRef ref,
    DisplayBook book,
  ) {
    final b = book.asZLibBook;
    return b == null ? null : BookDownloadButton(book: b);
  }

  @override
  Widget? buildPrimaryAction(
    BuildContext context,
    WidgetRef ref,
    DisplayBook book,
  ) {
    final b = book.asZLibBook;
    if (b == null) return null;
    final label = [
      AppLocalizations.of(context).get('download'),
      editionLabel(book),
    ].where((s) => s.isNotEmpty).join(' ');
    return BookDownloadButton(book: b, label: label);
  }
}
