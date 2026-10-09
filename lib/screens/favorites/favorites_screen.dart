import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/unified_shelf_item.dart';
import '../../providers/books_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/shelf_categories_provider.dart';
import '../../providers/shelf_provider.dart';
import '../../providers/weread_provider.dart';
import '../../routes/app_routes.dart';
import '../../screens/book_detail/book_detail_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/weread/weread_mobile_hub_screen.dart';
import '../../services/booklist_share_codec.dart';
import '../../services/share_intent_handler.dart';
import 'widgets/shelf_book_item.dart';
import 'widgets/shelf_filter_bar.dart';
import 'widgets/shelf_import_handler.dart';

enum _ShelfSort { defaultOrder, title, author }

class _CategoryCommand {
  const _CategoryCommand(this.action, [this.category]);

  final String action;
  final ShelfCategory? category;
}

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with ShelfImportHandler {
  static const _uncategorized = '__uncategorized__';

  final _searchController = TextEditingController();
  bool _isListView = false;
  bool _isSelectMode = false;
  final Set<int> _selectedBookIds = {};
  String? _selectedCategoryId;
  _ShelfSort _sort = _ShelfSort.defaultOrder;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final shelf = ref.watch(unifiedShelfProvider);
    final library = ref.watch(savedBooksProvider);
    final weread = ref.watch(wereadShelfProvider);
    final categories = ref.watch(shelfCategoriesProvider);
    final source = ref.watch(shelfFilterProvider);
    final downloads = ref.watch(downloadProvider);
    final hasSourceError = _sourceError(source, library, weread);

    ref.listen<BooklistShareData?>(pendingBooklistImportProvider, (prev, next) {
      if (next == null) return;
      ref.read(pendingBooklistImportProvider.notifier).state = null;
      runImport(l, next);
    });

    final allItems = shelf.valueOrNull ?? <UnifiedShelfItem>[];
    final visible = _filteredItems(allItems, source, categories);
    final selectedVisible = visible
        .where((item) => item.source == ShelfSource.library)
        .map((item) => int.tryParse(item.rawBookId))
        .whereType<int>()
        .toSet();

    return Scaffold(
      body: shelf is AsyncLoading && allItems.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  ref.read(savedBooksProvider.notifier).loadSavedBooks(),
                  ref.refresh(wereadShelfProvider.future),
                ]);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _appBar(l, selectedVisible),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Column(
                        children: [
                          if (!_isSelectMode) _searchBar(l),
                          ShelfFilterBar(
                            wereadCount: allItems
                                .where(
                                  (item) => item.source == ShelfSource.weread,
                                )
                                .length,
                            libraryCount: allItems
                                .where(
                                  (item) => item.source == ShelfSource.library,
                                )
                                .length,
                            source: source,
                            onSourceChanged: _changeSource,
                            isListView: _isListView,
                            onViewChanged: (value) =>
                                setState(() => _isListView = value),
                          ),
                          _categoryBar(l, allItems, source, categories),
                          _sortBar(l, visible.length),
                          if (hasSourceError) _errorBanner(l, source),
                        ],
                      ),
                    ),
                  ),
                  if (visible.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyState(l, source, hasSourceError),
                    )
                  else ...[
                    if (source == null || source == ShelfSource.weread)
                      _sourceGroup(
                        l,
                        ShelfSource.weread,
                        visible,
                        categories,
                        downloads,
                        showHeader: source == null,
                      ),
                    if (source == null || source == ShelfSource.library)
                      _sourceGroup(
                        l,
                        ShelfSource.library,
                        visible,
                        categories,
                        downloads,
                        showHeader: source == null,
                      ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 28)),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _isSelectMode && _selectedBookIds.isNotEmpty
          ? _bottomBar(l, visible)
          : null,
    );
  }

  List<UnifiedShelfItem> _filteredItems(
    List<UnifiedShelfItem> all,
    ShelfSource? source,
    ShelfCategoriesState categories,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final result = all.where((item) {
      if (source != null && item.source != source) return false;
      final assigned = categories.categoryFor(item);
      if (_selectedCategoryId == _uncategorized && assigned != null) {
        return false;
      }
      if (_selectedCategoryId != null &&
          _selectedCategoryId != _uncategorized &&
          assigned != _selectedCategoryId) {
        return false;
      }
      if (query.isEmpty) return true;
      return item.displayBook.title.toLowerCase().contains(query) ||
          (item.displayBook.author?.toLowerCase().contains(query) ?? false);
    }).toList();
    if (_sort != _ShelfSort.defaultOrder) {
      result.sort((a, b) {
        final left = _sort == _ShelfSort.title
            ? a.displayBook.title
            : a.displayBook.author ?? '';
        final right = _sort == _ShelfSort.title
            ? b.displayBook.title
            : b.displayBook.author ?? '';
        return left.toLowerCase().compareTo(right.toLowerCase());
      });
    }
    return result;
  }

  bool _sourceError(
    ShelfSource? source,
    AsyncValue<dynamic> library,
    AsyncValue<dynamic> weread,
  ) {
    return (source != ShelfSource.weread && library.hasError) ||
        (source != ShelfSource.library && weread.hasError);
  }

  Widget _appBar(AppLocalizations l, Set<int> visibleIds) {
    if (_isSelectMode) {
      return SliverAppBar(
        pinned: true,
        leading: IconButton(
          tooltip: l.get('cancel'),
          icon: const Icon(Icons.close),
          onPressed: _exitSelectMode,
        ),
        title: Text('${_selectedBookIds.length} ${l.get('shelf_selected')}'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              if (visibleIds.isNotEmpty &&
                  _selectedBookIds.containsAll(visibleIds)) {
                _selectedBookIds.removeAll(visibleIds);
              } else {
                _selectedBookIds.addAll(visibleIds);
              }
            }),
            child: Text(l.get('select_all')),
          ),
        ],
      );
    }
    return SliverAppBar(
      pinned: true,
      floating: true,
      title: Text(l.get('shelf_title')),
      actions: [
        IconButton(
          tooltip: l.get('shelf_manage_categories'),
          icon: const Icon(Icons.label_outline_rounded),
          onPressed: _manageCategories,
        ),
        PopupMenuButton<ImportSource>(
          tooltip: l.get('import_booklist'),
          icon: const Icon(Icons.file_download_outlined),
          onSelected: (source) => handleImport(l, source),
          itemBuilder: (_) => [
            _importItem(
              ImportSource.scan,
              Icons.qr_code_scanner_rounded,
              l.get('import_from_scan'),
            ),
            _importItem(
              ImportSource.paste,
              Icons.content_paste_rounded,
              l.get('import_from_paste'),
            ),
            _importItem(
              ImportSource.file,
              Icons.insert_drive_file_outlined,
              l.get('import_from_file'),
            ),
            _importItem(
              ImportSource.lan,
              Icons.computer_outlined,
              l.get('import_from_computer'),
            ),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<ImportSource> _importItem(
    ImportSource source,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: source,
      child: Row(
        children: [Icon(icon), const SizedBox(width: 12), Text(label)],
      ),
    );
  }

  // 与首页搜索框一致：胶囊形 + 柔和投影，填充色/圆角沿用全局 inputDecorationTheme。
  Widget _searchBar(AppLocalizations l) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.2
                  : 0.06,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) {
          _exitSelectMode();
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: l.get('shelf_search_hint'),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: l.get('clear'),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
      ),
    ),
  );

  Widget _categoryBar(
    AppLocalizations l,
    List<UnifiedShelfItem> all,
    ShelfSource? source,
    ShelfCategoriesState state,
  ) {
    final scoped = all.where((item) => source == null || item.source == source);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          _categoryChip(l.get('shelf_all_categories'), null, scoped.length),
          _categoryChip(
            l.get('shelf_uncategorized'),
            _uncategorized,
            scoped.where((item) => state.categoryFor(item) == null).length,
          ),
          for (final category in state.categories)
            _categoryChip(
              category.name,
              category.id,
              state.countFor(category.id, scoped),
            ),
          IconButton(
            tooltip: l.get('shelf_new_category'),
            visualDensity: VisualDensity.compact,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            onPressed: _createCategory,
            icon: const Icon(Icons.add_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String name, String? id, int count) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Center(
      child: ShelfChip(
        label: '$name $count',
        selected: _selectedCategoryId == id,
        dense: true,
        onSelected: () {
          _exitSelectMode();
          setState(() => _selectedCategoryId = id);
        },
      ),
    ),
  );

  Widget _sortBar(AppLocalizations l, int count) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 0, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${l.get('shelf_count').replaceAll('{count}', '$count')} · ${l.get('shelf_long_press_hint')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        PopupMenuButton<_ShelfSort>(
          tooltip: l.get('shelf_sort'),
          onSelected: (value) => setState(() => _sort = value),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _ShelfSort.defaultOrder,
              child: Text(l.get('shelf_sort_default')),
            ),
            PopupMenuItem(
              value: _ShelfSort.title,
              child: Text(l.get('shelf_sort_title')),
            ),
            PopupMenuItem(
              value: _ShelfSort.author,
              child: Text(l.get('shelf_sort_author')),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.swap_vert_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 3),
                Text(
                  l.get('shelf_sort'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _errorBanner(AppLocalizations l, ShelfSource? source) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Card(
      child: ListTile(
        leading: const Icon(Icons.wifi_off_rounded),
        title: Text(l.get('shelf_source_load_failed')),
        trailing: TextButton(
          onPressed: () {
            if (source != ShelfSource.weread) {
              ref.read(savedBooksProvider.notifier).loadSavedBooks();
            }
            if (source != ShelfSource.library) {
              ref.invalidate(wereadShelfProvider);
            }
          },
          child: Text(l.get('retry')),
        ),
      ),
    ),
  );

  static const _gridPadding = 16.0;
  static const _gridSpacing = 14.0;

  Widget _sourceGroup(
    AppLocalizations l,
    ShelfSource source,
    List<UnifiedShelfItem> all,
    ShelfCategoriesState categories,
    List<DownloadTask> downloads, {
    required bool showHeader,
  }) {
    final items = all.where((item) => item.source == source).toList();
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final columns = _shelfColumns;
    final cellWidth =
        (MediaQuery.sizeOf(context).width -
            _gridPadding * 2 -
            _gridSpacing * (columns - 1)) /
        columns;
    return SliverMainAxisGroup(
      slivers: [
        if (showHeader)
          SliverToBoxAdapter(child: _groupHeader(l, source, items.length)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(_gridPadding, 4, _gridPadding, 12),
          sliver: _isListView
              ? SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) =>
                      _listItem(items[index], categories, downloads),
                )
              : SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: _gridSpacing,
                    mainAxisSpacing: 16,
                    mainAxisExtent:
                        cellWidth / ShelfGridItem.coverAspectRatio +
                        ShelfGridItem.captionHeight,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, index) =>
                      _gridItem(items[index], categories, downloads),
                ),
        ),
      ],
    );
  }

  Widget _groupHeader(AppLocalizations l, ShelfSource source, int count) {
    final theme = Theme.of(context);
    final weread = source == ShelfSource.weread;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_gridPadding, 12, _gridPadding, 8),
      child: Row(
        children: [
          Icon(
            weread ? Icons.wechat_rounded : Icons.library_books_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            l.get(weread ? 'shelf_source_weread' : 'shelf_source_library'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  int get _shelfColumns =>
      ((MediaQuery.sizeOf(context).width - _gridPadding * 2) / 115)
          .floor()
          .clamp(3, 8);

  String? _categoryName(
    UnifiedShelfItem item,
    ShelfCategoriesState categories,
  ) {
    final id = categories.categoryFor(item);
    if (id == null) return null;
    for (final category in categories.categories) {
      if (category.id == id) return category.name;
    }
    return null;
  }

  DownloadTask? _localDownload(
    UnifiedShelfItem item,
    List<DownloadTask> downloads,
  ) {
    if (item.source != ShelfSource.library) return null;
    for (final task in downloads) {
      if (task.id == item.rawBookId &&
          task.status == DownloadStatus.completed &&
          task.filePath != null) {
        return task;
      }
    }
    return null;
  }

  Widget _gridItem(
    UnifiedShelfItem item,
    ShelfCategoriesState categories,
    List<DownloadTask> downloads,
  ) {
    final id = _libraryId(item);
    final local = _localDownload(item, downloads);
    return ShelfGridItem(
      item: item,
      isSelectMode: _isSelectMode,
      isSelected: id != null && _selectedBookIds.contains(id),
      categoryName: _categoryName(item, categories),
      isDownloaded: local != null,
      onTap: () => _onItemTap(item),
      onLongPress: id == null
          ? () => _showSingleBookActions(item, local)
          : () => _enterSelectMode(id),
    );
  }

  Widget _listItem(
    UnifiedShelfItem item,
    ShelfCategoriesState categories,
    List<DownloadTask> downloads,
  ) {
    final id = _libraryId(item);
    final local = _localDownload(item, downloads);
    return ShelfListItem(
      item: item,
      isSelectMode: _isSelectMode,
      isSelected: id != null && _selectedBookIds.contains(id),
      categoryName: _categoryName(item, categories),
      isDownloaded: local != null,
      onTap: () => _onItemTap(item),
      onLongPress: id == null
          ? () => _showSingleBookActions(item, local)
          : () => _enterSelectMode(id),
    );
  }

  Widget _emptyState(
    AppLocalizations l,
    ShelfSource? source,
    bool hasSourceError,
  ) {
    final searched = _searchController.text.trim().isNotEmpty;
    final filtered = searched || _selectedCategoryId != null;
    final title = hasSourceError
        ? l.get('shelf_source_load_failed')
        : filtered
        ? l.get('shelf_no_matches')
        : source == ShelfSource.weread
        ? l.get('weread_shelf_empty')
        : l.get('shelf_empty');
    final message = hasSourceError
        ? l.get('shelf_retry_hint')
        : filtered
        ? l.get('shelf_try_other_filter')
        : source == ShelfSource.weread
        ? l.get('shelf_weread_empty_hint')
        : l.get('shelf_empty_message');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filtered ? Icons.search_off_rounded : Icons.auto_stories_outlined,
              size: 54,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 7),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: hasSourceError
                  ? () {
                      if (source != ShelfSource.weread) {
                        ref.read(savedBooksProvider.notifier).loadSavedBooks();
                      }
                      if (source != ShelfSource.library) {
                        ref.invalidate(wereadShelfProvider);
                      }
                    }
                  : filtered
                  ? () => setState(() {
                      _searchController.clear();
                      _selectedCategoryId = null;
                    })
                  : source == ShelfSource.weread
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const WereadMobileHubScreen(),
                      ),
                    )
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SearchScreen(),
                      ),
                    ),
              child: Text(
                hasSourceError
                    ? l.get('retry')
                    : filtered
                    ? l.get('shelf_clear_filters')
                    : source == ShelfSource.weread
                    ? l.get('shelf_open_weread')
                    : l.get('shelf_find_books'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(AppLocalizations l, List<UnifiedShelfItem> visible) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                _selectionAction(
                  icon: Icons.label_outline_rounded,
                  label: l.get('shelf_add_to_category'),
                  onPressed: () => _showCategoryPicker(
                    visible
                        .where(
                          (item) =>
                              item.source == ShelfSource.library &&
                              _selectedBookIds.contains(
                                int.tryParse(item.rawBookId),
                              ),
                        )
                        .toList(),
                  ),
                ),
                _selectionAction(
                  icon: Icons.delete_outline_rounded,
                  label: l.get('batch_remove'),
                  onPressed: () =>
                      confirmBatchRemove(l, _selectedBookIds, _exitSelectMode),
                ),
                _selectionAction(
                  icon: Icons.share_rounded,
                  label: l.get('share_booklist'),
                  onPressed: () => showSharePreview(l, _selectedBookIds),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _selectionAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => Expanded(
    child: TextButton(
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 21),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );

  int? _libraryId(UnifiedShelfItem item) =>
      item.source == ShelfSource.library ? int.tryParse(item.rawBookId) : null;

  void _onItemTap(UnifiedShelfItem item) {
    final id = _libraryId(item);
    if (_isSelectMode && id != null) {
      _toggleSelect(id);
      return;
    }
    if (item.source == ShelfSource.weread) {
      Navigator.of(
        context,
      ).pushNamed(AppRoutes.wereadBookDetail, arguments: item.rawBookId);
      return;
    }
    final book = item.displayBook.original;
    if (book is Book) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const BookDetailScreen(),
          settings: RouteSettings(arguments: book),
        ),
      );
    }
  }

  Future<void> _quickAction(UnifiedShelfItem item, DownloadTask? local) async {
    if (local?.filePath != null) {
      try {
        if (!await File(local!.filePath!).exists()) {
          ref.read(downloadProvider.notifier).markMissingFile(local.id);
          if (mounted) {
            _message(AppLocalizations.of(context).get('download_file_missing'));
          }
          return;
        }
        final result = await OpenFilex.open(local.filePath!);
        if (result.type == ResultType.done) return;
        if (mounted) _message(result.message);
      } catch (error) {
        if (mounted) _message(error.toString());
      }
      return;
    }
    final uri = Uri.tryParse(item.deepLink ?? '');
    if (item.source == ShelfSource.weread &&
        uri != null &&
        uri.hasScheme &&
        !kIsWeb) {
      try {
        if (defaultTargetPlatform == TargetPlatform.android) {
          await AndroidIntent(
            action: 'android.intent.action.VIEW',
            data: uri.toString(),
            package: 'com.tencent.weread',
          ).launch();
          return;
        }
        if (defaultTargetPlatform == TargetPlatform.iOS &&
            await launchUrl(
              uri,
              mode: LaunchMode.externalNonBrowserApplication,
            )) {
          return;
        }
      } catch (error) {
        debugPrint('Could not open WeRead: ${error.runtimeType}');
      }
    }
    if (mounted) _onItemTap(item);
  }

  Future<void> _showSingleBookActions(
    UnifiedShelfItem item,
    DownloadTask? local,
  ) async {
    HapticFeedback.mediumImpact();
    final l = AppLocalizations.of(context);
    ModalRoute<dynamic>? sheetRoute;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        sheetRoute = ModalRoute.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  item.displayBook.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: Text(
                  item.source == ShelfSource.weread
                      ? l.get('shelf_continue_reading')
                      : local != null
                      ? l.get('open_file')
                      : l.get('shelf_view_details'),
                ),
                onTap: () => Navigator.pop(sheetContext, 'quick'),
              ),
              ListTile(
                leading: const Icon(Icons.label_outline_rounded),
                title: Text(l.get('shelf_add_to_category')),
                onTap: () => Navigator.pop(sheetContext, 'category'),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(l.get('shelf_view_details')),
                onTap: () => Navigator.pop(sheetContext, 'detail'),
              ),
            ],
          ),
        );
      },
    );
    await sheetRoute?.completed;
    if (!mounted) return;
    if (action == 'quick') {
      await _quickAction(item, local);
    } else if (action == 'category') {
      await _showCategoryPicker([item]);
    } else if (action == 'detail') {
      _onItemTap(item);
    }
  }

  void _changeSource(ShelfSource? value) {
    _exitSelectMode();
    ref.read(shelfFilterProvider.notifier).state = value;
  }

  void _toggleSelect(int id) => setState(() {
    if (!_selectedBookIds.add(id)) _selectedBookIds.remove(id);
  });

  void _enterSelectMode(int id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectMode = true;
      _selectedBookIds.add(id);
    });
  }

  void _exitSelectMode() {
    if (!_isSelectMode && _selectedBookIds.isEmpty) return;
    setState(() {
      _isSelectMode = false;
      _selectedBookIds.clear();
    });
  }

  Future<String?> _categoryNameDialog({String? initial}) async {
    final l = AppLocalizations.of(context);
    var name = initial ?? '';
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<String>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (dialogContext) => AlertDialog(
        title: Text(
          initial == null
              ? l.get('shelf_new_category')
              : l.get('shelf_rename_category'),
        ),
        content: TextFormField(
          initialValue: initial,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: l.get('shelf_category_name')),
          onChanged: (value) => name = value,
          onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, name),
            child: Text(l.get('save')),
          ),
        ],
      ),
    );
    final result = await navigator.push(route);
    await route.completed;
    return result;
  }

  Future<String?> _createCategory() async {
    final name = await _categoryNameDialog();
    if (name == null || !mounted) return null;
    try {
      await ref.read(shelfCategoriesProvider.notifier).create(name);
      final created = ref.read(shelfCategoriesProvider).categories.last;
      return created.id;
    } catch (error) {
      if (mounted) {
        _message(AppLocalizations.of(context).get('shelf_category_invalid'));
      }
      return null;
    }
  }

  Future<void> _showCategoryPicker(List<UnifiedShelfItem> items) async {
    if (items.isEmpty) return;
    final l = AppLocalizations.of(context);
    final categories = ref.read(shelfCategoriesProvider);
    final current = items.length == 1
        ? categories.categoryFor(items.single)
        : null;
    ModalRoute<dynamic>? sheetRoute;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        sheetRoute = ModalRoute.of(sheetContext);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text(l.get('shelf_add_to_category'))),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline_rounded),
                title: Text(l.get('shelf_uncategorized')),
                trailing: current == null ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetContext, _uncategorized),
              ),
              for (final category in categories.categories)
                ListTile(
                  leading: const Icon(Icons.label_outline_rounded),
                  title: Text(category.name),
                  trailing: current == category.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, category.id),
                ),
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: Text(l.get('shelf_new_category')),
                onTap: () => Navigator.pop(sheetContext, '__new__'),
              ),
            ],
          ),
        );
      },
    );
    await sheetRoute?.completed;
    if (chosen == null || !mounted) return;
    final id = chosen == '__new__' ? await _createCategory() : chosen;
    if (id == null || !mounted) return;
    try {
      await ref
          .read(shelfCategoriesProvider.notifier)
          .assign(items, id == _uncategorized ? null : id);
      if (mounted) _message(l.get('shelf_category_saved'));
    } catch (error) {
      if (mounted) _message(l.get('shelf_category_save_failed'));
    }
  }

  Future<void> _manageCategories() async {
    final l = AppLocalizations.of(context);
    final categories = ref.read(shelfCategoriesProvider).categories;
    ModalRoute<dynamic>? sheetRoute;
    final command = await showModalBottomSheet<_CategoryCommand>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        sheetRoute = ModalRoute.of(sheetContext);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text(l.get('shelf_manage_categories'))),
              for (final category in categories)
                ListTile(
                  leading: const Icon(Icons.label_outline_rounded),
                  title: Text(category.name),
                  trailing: PopupMenuButton<String>(
                    tooltip: l.get('more'),
                    onSelected: (value) {
                      Navigator.pop(
                        sheetContext,
                        _CategoryCommand(value, category),
                      );
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(l.get('shelf_rename_category')),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l.get('delete')),
                      ),
                    ],
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: Text(l.get('shelf_new_category')),
                onTap: () => Navigator.pop(
                  sheetContext,
                  const _CategoryCommand('create'),
                ),
              ),
            ],
          ),
        );
      },
    );
    await sheetRoute?.completed;
    if (!mounted || command == null) return;
    if (command.action == 'create') {
      await _createCategory();
    } else if (command.action == 'rename' && command.category != null) {
      await _renameCategory(command.category!);
    } else if (command.action == 'delete' && command.category != null) {
      await _deleteCategory(command.category!);
    }
  }

  Future<void> _renameCategory(ShelfCategory category) async {
    final name = await _categoryNameDialog(initial: category.name);
    if (name == null || !mounted) return;
    try {
      await ref
          .read(shelfCategoriesProvider.notifier)
          .rename(category.id, name);
    } catch (error) {
      if (mounted) {
        _message(AppLocalizations.of(context).get('shelf_category_invalid'));
      }
    }
  }

  Future<void> _deleteCategory(ShelfCategory category) async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<bool>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (dialogContext) => AlertDialog(
        title: Text(l.get('shelf_delete_category')),
        content: Text(l.get('shelf_delete_category_hint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.get('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.get('delete')),
          ),
        ],
      ),
    );
    final confirmed = await navigator.push(route);
    await route.completed;
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(shelfCategoriesProvider.notifier).delete(category.id);
      if (mounted && _selectedCategoryId == category.id) {
        setState(() => _selectedCategoryId = null);
      }
    } catch (error) {
      if (mounted) _message(l.get('shelf_category_save_failed'));
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
