import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/display_book.dart';
import '../../models/unified_shelf_item.dart';
import '../../providers/shelf_provider.dart';
import '../../providers/weread_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/hive_service.dart';
import '../../services/weread/weread_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_app_bar.dart';
import '../favorites/favorites_screen.dart';
import '../search/search_screen.dart';
import 'widgets/weread_book_cover.dart';
import 'weread_reading_report_screen.dart';
import 'weread_mobile_hub_screen.dart';

const _readingGoalKey = 'weread_daily_goal_minutes';

/// 微信读书首页：回到正在读的书、回顾自己的划线、发现下一本书。
class WereadHomeScreen extends ConsumerStatefulWidget {
  const WereadHomeScreen({super.key});

  @override
  ConsumerState<WereadHomeScreen> createState() => _WereadHomeScreenState();
}

class _WereadHomeScreenState extends ConsumerState<WereadHomeScreen> {
  int _goalMinutes = 20;
  int _highlightIndex = 0;
  int _recommendPage = 0;

  @override
  void initState() {
    super.initState();
    final saved = HiveService.settingsBox.get(_readingGoalKey);
    if (saved is int && [10, 20, 30].contains(saved)) _goalMinutes = saved;
  }

  Future<void> _refresh() async {
    ref.invalidate(wereadShelfProvider);
    ref.invalidate(wereadWeeklyStatsProvider);
    ref.invalidate(wereadStatsProvider);
    ref.invalidate(wereadRecentNotebooksProvider);
    ref.invalidate(wereadHomeHighlightProvider);
    await ref.read(wereadRecommendProvider.notifier).refresh();
  }

  void _openBook(String bookId) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.wereadBookDetail, arguments: bookId);
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SearchScreen(initialSource: BookSource.weread),
      ),
    );
  }

  Future<void> _openShelf() async {
    final previous = ref.read(shelfFilterProvider);
    ref.read(shelfFilterProvider.notifier).state = ShelfSource.weread;
    try {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()));
    } finally {
      if (mounted && ref.read(shelfFilterProvider) == ShelfSource.weread) {
        ref.read(shelfFilterProvider.notifier).state = previous;
      }
    }
  }

  Future<void> _resumeReading(ShelfBook book) async {
    final link = book.deepLink;
    final uri = link == null ? null : Uri.tryParse(link);
    if (uri == null || !uri.hasScheme || kIsWeb) {
      _openBook(book.bookId);
      return;
    }
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
      debugPrint('Failed to resume WeRead book: ${error.runtimeType}');
    }
    if (mounted) _openBook(book.bookId);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final connection = ref.watch(wereadConnectionProvider);
    if (connection.isLoading) {
      return Scaffold(
        appBar: GradientAppBar(title: t.get('weread')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (connection.valueOrNull != true) {
      return Scaffold(
        appBar: GradientAppBar(title: t.get('weread')),
        body: EmptyState(
          icon: Icons.qr_code_rounded,
          title: t.get('weread_not_configured_title'),
          message: t.get('weread_not_configured_msg'),
          action: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const WereadMobileHubScreen(),
              ),
            ),
            icon: const Icon(Icons.qr_code_rounded, size: 18),
            label: Text(t.get('weread_go_settings')),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: GradientAppBar(
        title: t.get('weread'),
        actions: [
          IconButton(
            tooltip: t.get('weread_search_books'),
            onPressed: _openSearch,
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
          children: [
            _intro(t),
            const SizedBox(height: 22),
            _continueReading(t),
            const SizedBox(height: 22),
            _readingRhythm(t),
            const SizedBox(height: 24),
            _actionCard(
              t.get('weread_report_title'),
              t.get('weread_report_home_hint'),
              Icons.auto_awesome_rounded,
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WereadReadingReportScreen(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _actionCard(
              t.get('weread_import_title'),
              t.get('weread_import_home_hint'),
              Icons.cloud_upload_outlined,
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WereadMobileHubScreen(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _highlightReview(t),
            const SizedBox(height: 24),
            _recommendations(t),
            const SizedBox(height: 24),
            _shelfPreview(t),
            const SizedBox(height: 24),
            _notebookPreview(t),
          ],
        ),
      ),
    );
  }

  Widget _intro(AppLocalizations t) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.get('weread_home_headline'),
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          t.get('weread_home_subtitle'),
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _continueReading(AppLocalizations t) {
    final shelf = ref.watch(wereadShelfProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(t.get('weread_continue_reading'), Icons.auto_stories_rounded),
        const SizedBox(height: 10),
        shelf.when(
          data: (data) {
            final recent =
                (data?.books ?? <ShelfBook>[])
                    .where(
                      (book) =>
                          !book.isSecret &&
                          !book.isFinished &&
                          (book.readUpdateTime ?? 0) > 0,
                    )
                    .toList()
                  ..sort(
                    (a, b) => (b.readUpdateTime ?? 0).compareTo(
                      a.readUpdateTime ?? 0,
                    ),
                  );
            if (recent.isEmpty) {
              return _actionCard(
                t.get('weread_start_reading'),
                t.get('weread_start_reading_hint'),
                Icons.library_books_outlined,
                _openShelf,
              );
            }
            final book = recent.first;
            final cs = Theme.of(context).colorScheme;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    Color.lerp(AppColors.primary, Colors.black, 0.22)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    WereadBookCover(
                      imageUrl: book.cover,
                      title: book.title,
                      width: 84,
                      height: 118,
                      radius: 8,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.get('weread_pick_up_where_left_off'),
                            style: const TextStyle(
                              color: Color(0xFFDCEDE2),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if ((book.author ?? '').isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              book.author!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFDCEDE2),
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 13),
                          FilledButton.tonalIcon(
                            onPressed: () => _resumeReading(book),
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 17,
                            ),
                            label: Text(t.get('weread_resume')),
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.surface,
                              foregroundColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => _loadingCard(),
          error: (_, __) => _retryCard(
            t.get('weread_shelf_load_failed'),
            () => ref.invalidate(wereadShelfProvider),
          ),
        ),
      ],
    );
  }

  Widget _readingRhythm(AppLocalizations t) {
    final weekly = ref.watch(wereadWeeklyStatsProvider);
    final lifetime = ref.watch(wereadStatsProvider).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          t.get('weread_reading_rhythm'),
          Icons.stacked_bar_chart_rounded,
        ),
        const SizedBox(height: 10),
        weekly.when(
          data: (stats) {
            if (stats == null) {
              return _retryCard(
                t.get('weread_stats_unavailable'),
                () => ref.invalidate(wereadWeeklyStatsProvider),
              );
            }
            final now = DateTime.now();
            final start = DateTime.fromMillisecondsSinceEpoch(
              stats.baseTime * 1000,
            );
            final times = stats.readTimes ?? const <String, int>{};
            final buckets = <DateTime, int>{};
            for (final entry in times.entries) {
              final seconds = int.tryParse(entry.key);
              if (seconds == null) continue;
              final day = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
              buckets[DateTime(day.year, day.month, day.day)] = entry.value;
            }
            final days = List.generate(7, (index) {
              final day = start.add(Duration(days: index));
              return DateTime(day.year, day.month, day.day);
            });
            final today = DateTime(now.year, now.month, now.day);
            final todaySeconds = buckets[today] ?? 0;
            final goalSeconds = _goalMinutes * 60;
            final progress = (todaySeconds / goalSeconds)
                .clamp(0.0, 1.0)
                .toDouble();
            final cs = Theme.of(context).colorScheme;
            final maxSeconds = [
              goalSeconds,
              ...days.map((day) => buckets[day] ?? 0),
            ].reduce((a, b) => a > b ? a : b);
            return _surfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.get('weread_today_progress'),
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${todaySeconds ~/ 60} / $_goalMinutes ${t.get('weread_minutes')}',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<int>(
                        tooltip: t.get('weread_set_goal'),
                        initialValue: _goalMinutes,
                        onSelected: (value) async {
                          final previous = _goalMinutes;
                          setState(() => _goalMinutes = value);
                          try {
                            await HiveService.settingsBox.put(
                              _readingGoalKey,
                              value,
                            );
                          } catch (error) {
                            debugPrint(
                              'Failed to save WeRead reading goal: ${error.runtimeType}',
                            );
                            if (mounted) {
                              setState(() => _goalMinutes = previous);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    t.get('weread_goal_save_failed'),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        itemBuilder: (_) => [10, 20, 30]
                            .map(
                              (value) => PopupMenuItem(
                                value: value,
                                child: Text(
                                  '$value ${t.get('weread_minutes')}',
                                ),
                              ),
                            )
                            .toList(),
                        child: Chip(
                          label: Text(
                            '${t.get('weread_daily_goal')} $_goalMinutes',
                          ),
                          avatar: const Icon(Icons.tune_rounded, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(7),
                    color: AppColors.primary,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t.get('weread_this_week'),
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 76,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (index) {
                        final day = days[index];
                        final seconds = buckets[day] ?? 0;
                        final isToday = day == today;
                        final label = t
                            .get('weread_weekdays')
                            .split(',')[index];
                        return Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: 16,
                                height:
                                    42 *
                                    (seconds / maxSeconds)
                                        .clamp(0.06, 1.0)
                                        .toDouble(),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? AppColors.primary
                                      : AppColors.primary.withValues(
                                          alpha: 0.28,
                                        ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isToday
                                      ? AppColors.primary
                                      : cs.onSurfaceVariant,
                                  fontWeight: isToday
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${t.get('weread_this_week_total')} ${_duration(stats.totalReadTime, t)}'
                    '${lifetime == null ? '' : '  ·  ${t.get('weread_read_days')} ${lifetime.readDays ?? 0}'}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            );
          },
          loading: _loadingCard,
          error: (_, __) => _retryCard(
            t.get('weread_stats_unavailable'),
            () => ref.invalidate(wereadWeeklyStatsProvider),
          ),
        ),
      ],
    );
  }

  Widget _highlightReview(AppLocalizations t) {
    final highlight = ref.watch(wereadHomeHighlightProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(t.get('weread_rediscover'), Icons.format_quote_rounded),
        const SizedBox(height: 10),
        highlight.when(
          data: (data) {
            if (data == null || data.bookmarks.isEmpty) {
              return _actionCard(
                t.get('weread_no_highlights'),
                t.get('weread_no_highlights_hint'),
                Icons.edit_note_rounded,
                _openShelf,
              );
            }
            final bookmark =
                data.bookmarks[_highlightIndex % data.bookmarks.length];
            final cs = Theme.of(context).colorScheme;
            return _surfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    color: AppColors.accent,
                    size: 27,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bookmark.markText.trim(),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.55,
                      color: cs.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '— ${data.notebook.book.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _openBook(data.notebook.bookId),
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        label: Text(t.get('weread_open_notes')),
                      ),
                      const Spacer(),
                      if (data.bookmarks.length > 1)
                        IconButton(
                          tooltip: t.get('weread_another_highlight'),
                          onPressed: () => setState(() => _highlightIndex++),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: _loadingCard,
          error: (_, __) => _retryCard(
            t.get('weread_notes_load_failed'),
            () => ref.invalidate(wereadHomeHighlightProvider),
          ),
        ),
      ],
    );
  }

  Widget _recommendations(AppLocalizations t) {
    final recommended = ref.watch(wereadRecommendProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          t.get('weread_recommend'),
          Icons.explore_rounded,
          trailing: TextButton.icon(
            onPressed: recommended.valueOrNull == null
                ? null
                : () => setState(() => _recommendPage++),
            icon: const Icon(Icons.autorenew_rounded, size: 17),
            label: Text(t.get('weread_change_batch')),
          ),
        ),
        const SizedBox(height: 10),
        recommended.when(
          data: (books) {
            if (books.isEmpty) {
              return _actionCard(
                t.get('weread_no_recommendations'),
                t.get('weread_find_book_hint'),
                Icons.search_rounded,
                _openSearch,
              );
            }
            final start = (_recommendPage * 4) % books.length;
            final visible = List.generate(
              books.length < 4 ? books.length : 4,
              (index) => books[(start + index) % books.length],
            );
            return SizedBox(
              height: 226,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final book = visible[index];
                  final cs = Theme.of(context).colorScheme;
                  return SizedBox(
                    width: 132,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openBook(book.bookId),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WereadBookCover(
                            imageUrl: book.cover,
                            title: book.title,
                            author: book.author,
                            width: 104,
                            height: 142,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if ((book.reason ?? '').isNotEmpty)
                            Text(
                              book.reason!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            )
                          else if ((book.author ?? '').isNotEmpty)
                            Text(
                              book.author!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: _loadingCard,
          error: (_, __) => _retryCard(
            t.get('weread_recommend_load_failed'),
            () => ref.read(wereadRecommendProvider.notifier).refresh(),
          ),
        ),
      ],
    );
  }

  Widget _shelfPreview(AppLocalizations t) {
    final shelf = ref.watch(wereadShelfProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          t.get('weread_my_shelf'),
          Icons.collections_bookmark_rounded,
          trailing: TextButton(
            onPressed: _openShelf,
            child: Text(t.get('weread_view_all')),
          ),
        ),
        const SizedBox(height: 9),
        shelf.when(
          data: (data) {
            final books =
                (data?.books ?? <ShelfBook>[])
                    .where((book) => !book.isSecret)
                    .toList()
                  ..sort(
                    (a, b) => (b.readUpdateTime ?? b.updateTime ?? 0).compareTo(
                      a.readUpdateTime ?? a.updateTime ?? 0,
                    ),
                  );
            if (books.isEmpty) {
              return _actionCard(
                t.get('weread_shelf_empty'),
                t.get('weread_find_book_hint'),
                Icons.search_rounded,
                _openSearch,
              );
            }
            final cs = Theme.of(context).colorScheme;
            return SizedBox(
              height: 178,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: books.length > 8 ? 8 : books.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final book = books[index];
                  return SizedBox(
                    width: 100,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _openBook(book.bookId),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WereadBookCover(
                            imageUrl: book.cover,
                            title: book.title,
                            width: 90,
                            height: 126,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: _loadingCard,
          error: (_, __) => _retryCard(
            t.get('weread_shelf_load_failed'),
            () => ref.invalidate(wereadShelfProvider),
          ),
        ),
      ],
    );
  }

  Widget _notebookPreview(AppLocalizations t) {
    final notebooks = ref.watch(wereadRecentNotebooksProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          t.get('weread_notes'),
          Icons.edit_note_rounded,
          trailing: TextButton(
            onPressed: _showAllNotebooks,
            child: Text(t.get('weread_view_all')),
          ),
        ),
        const SizedBox(height: 9),
        notebooks.when(
          data: (data) {
            if (data == null || data.books.isEmpty) {
              return _surfaceCard(child: Text(t.get('weread_notes_empty')));
            }
            return Column(
              children: data.books
                  .take(3)
                  .map((book) => _notebookTile(book, t))
                  .toList(),
            );
          },
          loading: _loadingCard,
          error: (_, __) => _retryCard(
            t.get('weread_notes_load_failed'),
            () => ref.invalidate(wereadRecentNotebooksProvider),
          ),
        ),
      ],
    );
  }

  void _showAllNotebooks() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        maxChildSize: 0.94,
        builder: (context, controller) => Consumer(
          builder: (context, sheetRef, _) {
            final t = AppLocalizations.of(context);
            final notebooks = sheetRef.watch(wereadNotebooksProvider);
            return notebooks.when(
              data: (data) => ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Text(
                    t.get('weread_notes'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (data == null || data.books.isEmpty)
                    Text(t.get('weread_notes_empty')),
                  ...?data?.books.map(
                    (book) =>
                        _notebookTile(book, t, sheetContext: sheetContext),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: FilledButton(
                  onPressed: () => sheetRef.invalidate(wereadNotebooksProvider),
                  child: Text(t.get('weread_retry')),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _notebookTile(
    NotebookBook notebook,
    AppLocalizations t, {
    BuildContext? sheetContext,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (sheetContext != null) Navigator.of(sheetContext).pop();
            _openBook(notebook.bookId);
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                WereadBookCover(
                  imageUrl: notebook.book.cover,
                  title: notebook.book.title,
                  width: 42,
                  height: 58,
                  radius: 5,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notebook.book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${notebook.noteCount} ${t.get('weread_highlights')} · '
                        '${notebook.reviewCount} ${t.get('weread_thoughts')} · '
                        '${notebook.bookmarkCount} ${t.get('weread_bookmarks')}',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(String title, IconData icon, {Widget? trailing}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _surfaceCard({required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }

  Widget _loadingCard() => _surfaceCard(
    child: const SizedBox(
      height: 75,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    ),
  );

  Widget _retryCard(String message, VoidCallback retry) => _surfaceCard(
    child: Row(
      children: [
        Expanded(child: Text(message)),
        TextButton(
          onPressed: retry,
          child: Text(AppLocalizations.of(context).get('weread_retry')),
        ),
      ],
    ),
  );

  Widget _actionCard(
    String title,
    String description,
    IconData icon,
    VoidCallback action,
  ) {
    final cs = Theme.of(context).colorScheme;
    return _surfaceCard(
      child: InkWell(
        onTap: action,
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 30),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  String _duration(int seconds, AppLocalizations t) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours ${t.get('weread_hours')} $minutes ${t.get('weread_minutes')}';
    }
    return '$minutes ${t.get('weread_minutes')}';
  }
}
