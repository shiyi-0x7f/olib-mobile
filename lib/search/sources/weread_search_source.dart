import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../models/display_book.dart';
import '../../providers/weread_provider.dart';
import '../../routes/app_routes.dart';
import '../../screens/weread/weread_mobile_hub_screen.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_state.dart';
import '../search_source.dart';

/// 微信读书：需先扫码连接；按范围搜书籍 / 公众号 / 文章，后两者为纯文本结果、点开跳 App。
class WereadSearchSource extends SearchSource {
  const WereadSearchSource();

  static const fScope = 'scope';
  static const _scopeBooks = '10';
  static const _scopeAccounts = '2';

  @override
  String get id => 'weread';

  @override
  IconData get icon => Icons.menu_book_rounded;

  @override
  String label(AppLocalizations t) => t.get('source_weread');

  @override
  ProviderListenable<bool> get readyProvider => isWereadConnectedProvider;

  @override
  Widget buildSetup(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.qr_code_rounded,
      title: t.get('weread_not_configured_title'),
      message: t.get('weread_not_configured_msg'),
      action: FilledButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const WereadMobileHubScreen(),
          ),
        ),
        child: Text(t.get('weread_go_settings')),
      ),
    );
  }

  @override
  List<SearchFilterGroup> filters(AppLocalizations t, String locale) => [
    SearchFilterGroup(
      id: fScope,
      title: locale.startsWith('zh') ? '范围' : 'Scope',
      required: true,
      defaultValue: _scopeBooks,
      options: [
        SearchFilterOption(_scopeBooks, t.get('weread_scope_books')),
        SearchFilterOption(_scopeAccounts, t.get('weread_scope_accounts')),
        SearchFilterOption('4', t.get('weread_scope_articles')),
      ],
    ),
  ];

  bool _isBooks(SearchFilterValues f) =>
      (f[fScope] ?? _scopeBooks) == _scopeBooks;

  @override
  String hint(AppLocalizations t, SearchFilterValues filters) => t.get(
    _isBooks(filters) ? 'search_for_books' : 'weread_search_content_hint',
  );

  @override
  SearchResultLayout layoutFor(SearchFilterValues filters) =>
      _isBooks(filters) ? SearchResultLayout.books : SearchResultLayout.text;

  @override
  Future<SearchPage> fetch(
    Ref ref,
    String query,
    SearchFilterValues filters,
    Object? cursor,
  ) async {
    final api = ref.read(wereadApiProvider);
    if (api == null) throw StateError('Connect WeRead first');
    final response = await api.search(
      keyword: query,
      scope: int.parse(filters[fScope] ?? _scopeBooks),
      maxIdx: cursor as int?,
    );
    final results = response.results.expand((g) => g.books).toList();
    return SearchPage(
      items: [for (final r in results) r.toDisplay(showReadingCount: false)],
      // 按最后一条的 searchIdx 翻页
      nextCursor: response.hasMoreResults && results.isNotEmpty
          ? results.last.searchIdx
          : null,
    );
  }

  @override
  void open(
    BuildContext context,
    WidgetRef ref,
    DisplayBook book,
    SearchFilterValues filters,
  ) {
    final info = book.asWereadBook;
    if (info == null) return;
    if (_isBooks(filters)) {
      Navigator.of(
        context,
      ).pushNamed(AppRoutes.wereadBookDetail, arguments: info);
    } else {
      // 公众号 / 文章：用 deepLink 跳微信读书 App
      _openContent(context, info.deepLink);
    }
  }

  static Future<void> _openContent(BuildContext context, String? link) async {
    final t = AppLocalizations.of(context);
    final uri = link == null ? null : Uri.tryParse(link);
    if (uri == null ||
        !{'https', 'http', 'weread', 'weixin'}.contains(uri.scheme)) {
      AppToast.show(t.get('weread_content_no_link'));
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('No app can open WeRead search link');
      }
    } catch (error) {
      debugPrint('Failed to open WeRead search result: ${error.runtimeType}');
      AppToast.error(t.get('weread_content_open_failed'));
    }
  }

  /// 分类 · 评分 · 免费/付费（价格只标状态，不展示金额；缺失时不标）。
  @override
  List<String> describe(DisplayBook book, AppLocalizations t) {
    final price = book.asWereadBook?.price;
    return [
      if (book.tag != null && book.tag!.isNotEmpty) book.tag!,
      if (book.score != null) '★ ${book.score}',
      if (price != null) t.get(price > 0 ? 'search_paid' : 'search_free'),
    ];
  }
}
