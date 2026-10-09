import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/books_provider.dart';
import '../../providers/weread_provider.dart';
import '../../widgets/book_card.dart';
import '../../widgets/book_list_tile.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/update_dialog.dart';
import '../../models/display_book.dart';
import '../../routes/app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../constants/search_filters.dart';
import '../../theme/app_colors.dart';
import '../../services/update_service.dart';
import '../../services/hive_service.dart';
import '../../services/weread/weread_models.dart';
import '../weread/weread_mobile_hub_screen.dart';

const _searchSourceKey = 'default_search_source';
const _recentSearchesKey = 'recent_search_keywords';
const _recentSearchesLimit = 12;

class SearchScreen extends ConsumerStatefulWidget {
  final BookSource? initialSource;

  const SearchScreen({super.key, this.initialSource});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  bool _showFilters = false;
  String _selectedLanguage = 'all';
  String _selectedOrder = 'default';
  String _selectedExtension = 'all';
  bool _isListView = false;
  bool _isQueryEmpty = true;
  List<String> _recentSearches = [];
  late BookSource _selectedSource;
  int _wereadScope = 10;

  @override
  void initState() {
    super.initState();
    final savedSource = HiveService.settingsBox.get(_searchSourceKey);
    _selectedSource =
        widget.initialSource ??
        (savedSource == BookSource.weread.name
            ? BookSource.weread
            : BookSource.zlibrary);
    final savedSearches = HiveService.settingsBox.get(_recentSearchesKey);
    if (savedSearches is List) {
      final seen = <String>{};
      _recentSearches = savedSearches
          .whereType<String>()
          .map((keyword) => keyword.trim())
          .where(
            (keyword) => keyword.isNotEmpty && seen.add(keyword.toLowerCase()),
          )
          .take(_recentSearchesLimit)
          .toList();
    }
    _searchController.addListener(_onQueryChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final isEmpty = _searchController.text.trim().isEmpty;
    if (isEmpty != _isQueryEmpty) {
      setState(() => _isQueryEmpty = isEmpty);
    }
  }

  Future<void> _saveRecentSearches(List<String> searches) async {
    setState(() => _recentSearches = searches);
    try {
      await HiveService.settingsBox.put(_recentSearchesKey, searches);
    } catch (error) {
      debugPrint('Failed to save recent searches: ${error.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).get('search_history_save_failed'),
            ),
          ),
        );
      }
    }
  }

  void _rememberSearch(String query) {
    final normalized = query.toLowerCase();
    final searches = [
      query,
      ..._recentSearches.where((item) => item.toLowerCase() != normalized),
    ].take(_recentSearchesLimit).toList();
    unawaited(_saveRecentSearches(searches));
  }

  void _searchAgain(String keyword) {
    _searchController.text = keyword;
    _searchController.selection = TextSelection.collapsed(
      offset: keyword.length,
    );
    FocusScope.of(context).unfocus();
    _performSearch();
  }

  Widget _buildRecentSearches(AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Icon(Icons.history_rounded, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.get('search_history_title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => unawaited(_saveRecentSearches([])),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(l10n.get('search_history_clear')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final keyword in _recentSearches)
              InputChip(
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(keyword, overflow: TextOverflow.ellipsis),
                ),
                onPressed: () => _searchAgain(keyword),
                onDeleted: () => unawaited(
                  _saveRecentSearches(
                    _recentSearches.where((item) => item != keyword).toList(),
                  ),
                ),
                deleteButtonTooltipMessage: l10n.get('search_history_remove'),
                backgroundColor: colors.surfaceContainerLow,
                side: BorderSide(color: colors.outlineVariant),
              ),
          ],
        ),
      ],
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_selectedSource == BookSource.weread) {
        ref.read(wereadSearchProvider.notifier).loadMore();
      } else {
        ref.read(searchProvider.notifier).loadMore();
      }
    }
  }

  Future<void> _selectSource(BookSource source) async {
    if (_selectedSource == source) return;
    setState(() {
      _selectedSource = source;
      _showFilters = false;
    });
    if (_searchController.text.trim().isNotEmpty) _runSearch();
    await HiveService.settingsBox.put(_searchSourceKey, source.name);
  }

  void _selectWereadScope(int scope) {
    if (_wereadScope == scope) return;
    setState(() => _wereadScope = scope);
    if (_searchController.text.trim().isNotEmpty) _runSearch();
  }

  Future<void> _openWereadContent(SearchResultBook result) async {
    final link = result.bookInfo.deepLink;
    final uri = link == null ? null : Uri.tryParse(link);
    if (uri == null ||
        !{'https', 'http', 'weread', 'weixin'}.contains(uri.scheme)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).get('weread_content_no_link'),
          ),
        ),
      );
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('No app can open WeRead search link');
      }
    } catch (error) {
      debugPrint('Failed to open WeRead search result: ${error.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).get('weread_content_open_failed'),
            ),
          ),
        );
      }
    }
  }

  Widget _wereadContentTile(SearchResultBook result, AppLocalizations t) {
    final info = result.bookInfo;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: cs.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openWereadContent(result),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _wereadScope == 2
                    ? Icons.account_circle_outlined
                    : Icons.article_outlined,
                color: cs.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title.isEmpty
                          ? t.get('weread_untitled_content')
                          : info.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((info.author ?? '').isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        info.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if ((info.intro ?? '').isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        info.intro!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _wereadPriceLabel(WereadBookInfo book, AppLocalizations l10n) {
    if (book.price == null) return null;
    return book.price! > 0
        ? '💰 ${l10n.get('search_paid')}'
        : l10n.get('search_free');
  }

  void _openBook(DisplayBook book) {
    Navigator.of(context).pushNamed(
      book.isWeread ? AppRoutes.wereadBookDetail : AppRoutes.bookDetail,
      arguments: book.isWeread ? book.asWereadBook : book.asZLibBook,
    );
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    if (_runSearch()) _rememberSearch(query);
  }

  bool _runSearch() {
    if (UpdateService.isBlocked) {
      showUpdateDialog(context);
      return false;
    }

    final query = _searchController.text.trim();
    if (_selectedSource == BookSource.weread) {
      if (ref.read(isWereadConnectedProvider)) {
        ref
            .read(wereadSearchProvider.notifier)
            .search(query, scope: _wereadScope);
        return true;
      }
      return false;
    }

    ref
        .read(searchProvider.notifier)
        .search(
          SearchParams(
            query: query,
            languages: searchLanguages[_selectedLanguage] != null
                ? [searchLanguages[_selectedLanguage]!]
                : null,
            extensions: searchExtensions[_selectedExtension] != null
                ? [searchExtensions[_selectedExtension]!]
                : null,
            order: searchOrders[_selectedOrder],
          ),
        );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final languageNames = getLanguageDisplayNames(locale);
    final orderNames = getOrderDisplayNames(locale);
    final extensionNames = getExtensionDisplayNames(locale);
    final searchState = ref.watch(searchProvider);
    final wereadState = ref.watch(wereadSearchProvider);
    final isWeread = _selectedSource == BookSource.weread;
    final isConfigured = ref.watch(isWereadConnectedProvider);
    final isWereadContent = isWeread && _wereadScope != 10;
    final books = isWeread && !isWereadContent
        ? wereadState.results
              .map(
                (result) => result.toDisplay(
                  priceLabel: _wereadPriceLabel(result.bookInfo, l10n),
                  showReadingCount: false,
                ),
              )
              .toList()
        : isWereadContent
        ? <DisplayBook>[]
        : searchState.books.map((book) => book.toDisplay()).toList();
    final resultCount = isWereadContent
        ? wereadState.results.length
        : books.length;
    final hasSearched = isWeread
        ? wereadState.hasSearched
        : searchState.hasSearched;
    final isLoading = isWeread ? wereadState.isLoading : searchState.isLoading;
    final isLoadingMore = isWeread
        ? wereadState.isLoadingMore
        : searchState.isLoadingMore;
    final error = isWeread ? wereadState.error : searchState.error;

    return Scaffold(
      appBar: GradientAppBar(title: l10n.get('search_books')),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.get(
                  isWereadContent
                      ? 'weread_search_content_hint'
                      : 'search_for_books',
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isWeread)
                      IconButton(
                        icon: Icon(
                          Icons.tune,
                          color: _showFilters ? AppColors.primary : null,
                        ),
                        onPressed: () {
                          setState(() {
                            _showFilters = !_showFilters;
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(searchProvider.notifier).reset();
                        ref.read(wereadSearchProvider.notifier).reset();
                      },
                    ),
                  ],
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _performSearch(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(l10n.get('search_source')),
                const SizedBox(width: 12),
                ChoiceChip(
                  avatar: const Icon(Icons.local_library_outlined, size: 18),
                  label: Text(l10n.get('source_zlibrary')),
                  selected: !isWeread,
                  onSelected: (_) => _selectSource(BookSource.zlibrary),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.menu_book_rounded, size: 18),
                  label: Text(l10n.get('source_weread')),
                  selected: isWeread,
                  onSelected: (_) => _selectSource(BookSource.weread),
                ),
              ],
            ),
          ),

          if (isWeread)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final (scope, label, icon) in [
                    (10, 'weread_scope_books', Icons.menu_book_outlined),
                    (2, 'weread_scope_accounts', Icons.account_circle_outlined),
                    (4, 'weread_scope_articles', Icons.article_outlined),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(icon, size: 17),
                        label: Text(l10n.get(label)),
                        selected: _wereadScope == scope,
                        onSelected: (_) => _selectWereadScope(scope),
                      ),
                    ),
                ],
              ),
            ),

          // Filter Panel
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildFilterPanel(
              languageNames,
              orderNames,
              extensionNames,
            ),
            crossFadeState: _showFilters && !isWeread
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),

          // Search Results
          Expanded(
            child: _isQueryEmpty && _recentSearches.isNotEmpty
                ? _buildRecentSearches(l10n)
                : isWeread && !isConfigured
                ? EmptyState(
                    icon: Icons.qr_code_rounded,
                    title: l10n.get('weread_not_configured_title'),
                    message: l10n.get('weread_not_configured_msg'),
                    action: FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const WereadMobileHubScreen(),
                        ),
                      ),
                      child: Text(l10n.get('weread_go_settings')),
                    ),
                  )
                : _isQueryEmpty || !hasSearched
                ? EmptyState(
                    icon: Icons.search,
                    title: l10n.get('start_searching'),
                    message: l10n.get('enter_search_hint'),
                  )
                : isLoading
                ? LoadingWidget(message: l10n.get('searching_books'))
                : error != null && resultCount == 0
                ? EmptyState(
                    icon: Icons.error_outline,
                    title: l10n.get('search_failed'),
                    message: error,
                    action: FilledButton(
                      onPressed: _performSearch,
                      child: Text(l10n.get('search_retry')),
                    ),
                  )
                : resultCount == 0
                ? EmptyState(
                    icon: Icons.search_off,
                    title: l10n.get('no_results'),
                    message: l10n.get('search_no_results_switch'),
                    action: FilledButton.icon(
                      onPressed: () => _selectSource(
                        isWeread ? BookSource.zlibrary : BookSource.weread,
                      ),
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(
                        '${l10n.get('search_try_source')} ${l10n.get(isWeread ? 'source_zlibrary' : 'source_weread')}',
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    l10n
                                        .get(
                                          isWereadContent
                                              ? 'weread_search_results_count'
                                              : 'search_results_count',
                                        )
                                        .replaceAll('{count}', '$resultCount'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            if (!isWeread) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  l10n
                                      .get('search_page_progress')
                                      .replaceAll(
                                        '{current}',
                                        '${searchState.currentPage}',
                                      )
                                      .replaceAll(
                                        '{total}',
                                        '${searchState.totalPages}',
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                            if (!isWereadContent)
                              IconButton(
                                icon: Icon(
                                  _isListView
                                      ? Icons.grid_view_rounded
                                      : Icons.view_list_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 22,
                                ),
                                tooltip: _isListView
                                    ? l10n.get('grid_view')
                                    : l10n.get('list_view'),
                                onPressed: () {
                                  setState(() {
                                    _isListView = !_isListView;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(l10n.get('search_more_failed')),
                              ),
                              TextButton(
                                onPressed: isWeread
                                    ? () => ref
                                          .read(wereadSearchProvider.notifier)
                                          .loadMore()
                                    : () => ref
                                          .read(searchProvider.notifier)
                                          .loadMore(),
                                child: Text(l10n.get('search_retry')),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: isWereadContent
                            ? ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                itemCount:
                                    resultCount + (isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) =>
                                    index >= resultCount
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    : _wereadContentTile(
                                        wereadState.results[index],
                                        l10n,
                                      ),
                              )
                            : _isListView
                            ? ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                itemCount:
                                    books.length + (isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= books.length) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  final book = books[index];
                                  return BookListTile(
                                    book: book,
                                    showCover: true,
                                    onTap: () => _openBook(book),
                                  );
                                },
                              )
                            : GridView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 220,
                                      childAspectRatio: 0.60,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                itemCount:
                                    books.length + (isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= books.length) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }

                                  final book = books[index];
                                  return BookCard(
                                    book: book,
                                    searchResult: true,
                                    onTap: () => _openBook(book),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(
    Map<String, String> languageNames,
    Map<String, String> orderNames,
    Map<String, String> extensionNames,
  ) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).languageCode;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDropdown2(
                  hint: l10n.get('language'),
                  value: _selectedLanguage,
                  items: languageNames.entries
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(
                            e.value,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedLanguage = value);
                    }
                  },
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown2(
                  hint: locale.startsWith('zh') ? '排序' : 'Sort',
                  value: _selectedOrder,
                  items: orderNames.entries
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(
                            e.value,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedOrder = value);
                    }
                  },
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: extensionNames.entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: _selectedExtension == entry.key,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: _selectedExtension == entry.key
                              ? AppColors.primary
                              : null,
                          fontWeight: _selectedExtension == entry.key
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedExtension = entry.key);
                          }
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown2({
    required String hint,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        isExpanded: true,
        hint: Text(
          hint,
          style: TextStyle(fontSize: 14, color: Theme.of(context).hintColor),
        ),
        items: items,
        value: value,
        onChanged: onChanged,
        buttonStyleData: ButtonStyleData(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
            color: isDark ? Colors.grey[850] : Colors.white,
          ),
        ),
        iconStyleData: IconStyleData(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          iconSize: 20,
          iconEnabledColor: AppColors.primary,
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isDark ? Colors.grey[900] : Colors.white,
          ),
          scrollbarTheme: ScrollbarThemeData(
            radius: const Radius.circular(40),
            thickness: WidgetStateProperty.all(6),
            thumbVisibility: WidgetStateProperty.all(true),
          ),
        ),
        menuItemStyleData: const MenuItemStyleData(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }
}
