import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../../models/unified_shelf_item.dart';
import '../../providers/books_provider.dart';
import '../../providers/shelf_provider.dart';
import '../../providers/weread_provider.dart';
import '../../screens/book_detail/book_detail_screen.dart';
import '../../services/booklist_share_codec.dart';
import '../../services/share_intent_handler.dart';
import '../../theme/app_colors.dart';
import '../../routes/app_routes.dart';
import 'widgets/shelf_filter_bar.dart';
import 'widgets/shelf_book_item.dart';
import 'widgets/shelf_import_handler.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with ShelfImportHandler {
  bool _isListView = false;
  bool _isSelectMode = false;
  Set<int> _selectedBookIds = {};

  @override
  Widget build(BuildContext context) {
    final shelfAsync = ref.watch(unifiedShelfProvider);
    final l = AppLocalizations.of(context);

    // 书单导入监听
    ref.listen<BooklistShareData?>(pendingBooklistImportProvider,
        (prev, next) {
      if (next == null) return;
      ref.read(pendingBooklistImportProvider.notifier).state = null;
      runImport(l, next);
    });

    return Scaffold(
      body: shelfAsync.when(
        data: (items) => _buildBody(l, items),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('$err')),
      ),
      bottomNavigationBar: _isSelectMode && _selectedBookIds.isNotEmpty
          ? _buildBottomBar(l)
          : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Body
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildBody(AppLocalizations l, List<UnifiedShelfItem> items) {
    final filter = ref.watch(shelfFilterProvider);
    final wereadItems =
        items.where((i) => i.source == ShelfSource.weread).toList();
    final libraryItems =
        items.where((i) => i.source == ShelfSource.library).toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(savedBooksProvider);
        ref.invalidate(wereadShelfProvider);
      },
      child: CustomScrollView(
        slivers: [
          // ── AppBar ──
          _buildAppBar(l, items),

          // ── Filter + View Toggle ──
          ShelfFilterBar(
            wereadCount: wereadItems.length,
            libraryCount: libraryItems.length,
            isListView: _isListView,
            onViewChanged: (v) => setState(() => _isListView = v),
          ),

          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(l),
            )
          else ...[
            // ── WeRead Group ──
            if (filter == null || filter == ShelfSource.weread)
              if (wereadItems.isNotEmpty) ...[
                _groupHeader(l.get('shelf_source_weread'),
                    Icons.menu_book_rounded, wereadItems.length),
                _bookSliver(wereadItems),
              ],

            // ── Library Group ──
            if (filter == null || filter == ShelfSource.library)
              if (libraryItems.isNotEmpty) ...[
                _groupHeader(l.get('shelf_source_library'),
                    Icons.local_library_rounded, libraryItems.length),
                _bookSliver(libraryItems),
              ],

            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // AppBar — 简洁版，不显示大标题
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildAppBar(AppLocalizations l, List<UnifiedShelfItem> items) {
    if (_isSelectMode) {
      return SliverAppBar(
        pinned: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectMode,
        ),
        title: Text(
          '${_selectedBookIds.length} selected',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final allLibIds = items
                  .where((i) => i.source == ShelfSource.library)
                  .map((i) => int.tryParse(i.rawBookId))
                  .whereType<int>()
                  .toSet();
              setState(() {
                if (_selectedBookIds.length == allLibIds.length) {
                  _selectedBookIds.clear();
                } else {
                  _selectedBookIds = Set.from(allLibIds);
                }
              });
            },
            child: Text(l.get('select_all')),
          ),
        ],
      );
    }

    return SliverAppBar(
      pinned: true,
      floating: true,
      actions: [
        PopupMenuButton<ImportSource>(
          tooltip: l.get('import_booklist'),
          icon: const Icon(Icons.file_download_outlined),
          onSelected: (src) => handleImport(l, src),
          itemBuilder: (_) => [
            _importMenuItem(ImportSource.scan, Icons.qr_code_scanner_rounded,
                l.get('import_from_scan')),
            _importMenuItem(ImportSource.paste,
                Icons.content_paste_rounded, l.get('import_from_paste')),
            _importMenuItem(ImportSource.file,
                Icons.insert_drive_file_outlined, l.get('import_from_file')),
            _importMenuItem(ImportSource.lan, Icons.computer_outlined,
                l.get('import_from_computer')),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  PopupMenuItem<ImportSource> _importMenuItem(
      ImportSource value, IconData icon, String text) {
    return PopupMenuItem(
      value: value,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(text),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Group Header
  // ═══════════════════════════════════════════════════════════════════

  Widget _groupHeader(String title, IconData icon, int count) {
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Book Sliver (Grid / List)
  // ═══════════════════════════════════════════════════════════════════

  Widget _bookSliver(List<UnifiedShelfItem> items) {
    if (_isListView) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _listItemFor(items[i]),
          childCount: items.length,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.58,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => _gridItemFor(items[i]),
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _gridItemFor(UnifiedShelfItem item) {
    final bookId = _zlibId(item);
    return ShelfGridItem(
      item: item,
      isSelectMode: _isSelectMode,
      isSelected: bookId != null && _selectedBookIds.contains(bookId),
      onTap: () => _onItemTap(item),
      onLongPress: bookId != null ? () => _enterSelectMode(bookId) : null,
    );
  }

  Widget _listItemFor(UnifiedShelfItem item) {
    final bookId = _zlibId(item);
    return ShelfListItem(
      item: item,
      isSelectMode: _isSelectMode,
      isSelected: bookId != null && _selectedBookIds.contains(bookId),
      onTap: () => _onItemTap(item),
      onLongPress: bookId != null ? () => _enterSelectMode(bookId) : null,
      onToggleSelect: bookId != null ? () => _toggleSelect(bookId) : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Bottom Bar (select mode)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildBottomBar(AppLocalizations l) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => confirmBatchRemove(
                l, _selectedBookIds, _exitSelectMode,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: Text(l.get('batch_remove')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[400],
                side: BorderSide(color: Colors.red[300]!),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => showSharePreview(l, _selectedBookIds),
              icon: const Icon(Icons.share_rounded, size: 20),
              label: Text(l.get('share_booklist')),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Empty State
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildEmptyState(AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.library_books_outlined,
                size: 56, color: AppColors.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text(
            l.get('shelf_empty'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            l.get('shelf_empty_message'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════

  int? _zlibId(UnifiedShelfItem item) =>
      item.source == ShelfSource.library
          ? int.tryParse(item.rawBookId)
          : null;

  void _onItemTap(UnifiedShelfItem item) {
    final bookId = _zlibId(item);
    if (_isSelectMode && bookId != null) {
      _toggleSelect(bookId);
      return;
    }

    if (item.source == ShelfSource.weread) {
      Navigator.of(context).pushNamed(
        AppRoutes.wereadBookDetail,
        arguments: item.rawBookId,
      );
    } else {
      final original = item.displayBook.original;
      if (original is Book) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const BookDetailScreen(),
            settings: RouteSettings(arguments: original),
          ),
        );
      }
    }
  }

  void _toggleSelect(int bookId) {
    setState(() {
      if (_selectedBookIds.contains(bookId)) {
        _selectedBookIds.remove(bookId);
      } else {
        _selectedBookIds.add(bookId);
      }
    });
  }

  void _enterSelectMode(int bookId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectMode = true;
      _selectedBookIds.add(bookId);
    });
  }

  void _exitSelectMode() {
    if (mounted) {
      setState(() {
        _isSelectMode = false;
        _selectedBookIds.clear();
      });
    }
  }
}
