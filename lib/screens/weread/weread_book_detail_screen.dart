import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../../providers/weread_provider.dart';
import '../../models/display_book.dart';
import '../../routes/app_routes.dart';
import '../../widgets/loading_widget.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/weread/weread_models.dart';
import '../../services/weread/weread_api.dart';
import '../book_detail/widgets/book_hero_section.dart';
import 'widgets/weread_info_section.dart';
import 'weread_ask_book_screen.dart';
import 'weread_mobile_hub_screen.dart';

/// 微信读书书籍详情页
class WereadBookDetailScreen extends ConsumerStatefulWidget {
  const WereadBookDetailScreen({super.key});

  @override
  ConsumerState<WereadBookDetailScreen> createState() =>
      _WereadBookDetailScreenState();
}

class _WereadBookDetailScreenState
    extends ConsumerState<WereadBookDetailScreen> {
  WereadBookInfo? _bookInfo;
  ChapterInfoResponse? _chapters;
  BestBookmarksResponse? _bestBookmarks;
  ReviewListResponse? _reviews;
  BookmarkListResponse? _myBookmarks;
  MineReviewListResponse? _myReviews;
  bool _isLoading = true;
  bool _isLoadingMoreReviews = false;
  bool _reviewsLoadFailed = false;
  String? _error;
  WereadBookInfo? _searchBookInfo;
  String? _deepLink;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading && _bookInfo == null) {
      _loadBookDetail();
    }
  }

  /// 查找上传书籍在笔记本中的实际 bookId
  /// 上传书（CB_ 开头）在书架和笔记本中可能使用不同的 bookId
  Future<String?> _resolveNotebookBookId(
    String shelfBookId,
    dynamic api,
  ) async {
    if (!shelfBookId.startsWith('CB_')) return null;
    try {
      final notebooks = await api.notebooks(count: 200);
      for (final nb in notebooks.books) {
        // 匹配封面 URL 中的原始 bookId 或直接匹配
        if (nb.bookId == shelfBookId) return shelfBookId;
        if (nb.book.cover != null && nb.book.cover!.contains(shelfBookId)) {
          return nb.bookId;
        }
      }
    } catch (error) {
      debugPrint(
        'Failed to resolve WeRead notebook book ID: ${error.runtimeType}',
      );
    }
    return null;
  }

  Future<void> _loadBookDetail() async {
    final argument = ModalRoute.of(context)!.settings.arguments;
    _searchBookInfo = argument is WereadBookInfo ? argument : null;
    final bookId = _searchBookInfo?.bookId ?? argument as String;
    var api = ref.read(wereadApiProvider);
    if (api == null) {
      final mobile = ref.read(wereadMobileClientProvider);
      try {
        if (await mobile.isConnected) api = WereadApi(mobile);
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = error.toString();
        });
        return;
      }
    }
    if (!mounted) return;
    if (api == null) {
      setState(() {
        _isLoading = false;
        _error = AppLocalizations.of(context).get('weread_not_configured_msg');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _reviewsLoadFailed = false;
    });

    try {
      // Load book info first (required)
      final bookInfo = await api.bookInfo(bookId);
      final deepLink = bookInfo.deepLink ?? _searchBookInfo?.deepLink;

      // For uploaded books (CB_ prefix), resolve the notebook bookId
      // because shelf and notebook may use different IDs
      String noteBookId = bookId;
      if (bookId.startsWith('CB_')) {
        final resolved = await _resolveNotebookBookId(bookId, api);
        if (resolved != null) noteBookId = resolved;
      }

      // Load optional data concurrently
      // Split into two groups: book-level data uses bookId,
      // personal notes use noteBookId (may differ for uploaded books)
      ChapterInfoResponse? chapters;
      BestBookmarksResponse? bestBookmarks;
      ReviewListResponse? reviews;
      BookmarkListResponse? myBookmarks;
      MineReviewListResponse? myReviews;

      // Group 1: Book metadata (always use original bookId)
      try {
        final results = await Future.wait([
          api.chapters(bookId).catchError((Object error) {
            debugPrint('Failed to load WeRead chapters: ${error.runtimeType}');
            return ChapterInfoResponse(
              bookId: bookId,
              synckey: 0,
              chapters: [],
            );
          }),
          api.bestBookmarks(bookId).catchError((Object error) {
            debugPrint(
              'Failed to load WeRead highlights: ${error.runtimeType}',
            );
            return const BestBookmarksResponse(
              synckey: 0,
              totalCount: 0,
              items: [],
            );
          }),
          api.reviewList(bookId: bookId, count: 20).catchError((Object error) {
            debugPrint('Failed to load WeRead reviews: ${error.runtimeType}');
            return const ReviewListResponse(
              synckey: 0,
              reviewsCnt: 0,
              reviews: [],
            );
          }),
        ]);
        chapters = results[0] as ChapterInfoResponse;
        bestBookmarks = results[1] as BestBookmarksResponse;
        reviews = results[2] as ReviewListResponse;
      } catch (error) {
        debugPrint('Failed to load WeRead book sections: ${error.runtimeType}');
      }

      // Group 2: Personal notes (use resolved noteBookId for uploaded books)
      try {
        final noteResults = await Future.wait([
          api.bookmarks(noteBookId).catchError((Object error) {
            debugPrint('Failed to load WeRead bookmarks: ${error.runtimeType}');
            return const BookmarkListResponse(updated: []);
          }),
          api.mineReviews(noteBookId).catchError((Object error) {
            debugPrint(
              'Failed to load WeRead personal reviews: ${error.runtimeType}',
            );
            return const MineReviewListResponse(
              totalCount: 0,
              hasMore: 0,
              synckey: 0,
              reviews: [],
            );
          }),
        ]);
        myBookmarks = noteResults[0] as BookmarkListResponse;
        myReviews = noteResults[1] as MineReviewListResponse;
      } catch (error) {
        debugPrint(
          'Failed to load WeRead personal notes: ${error.runtimeType}',
        );
      }

      if (mounted) {
        setState(() {
          _bookInfo = bookInfo;
          _deepLink = deepLink;
          _chapters = chapters;
          _bestBookmarks = bestBookmarks;
          _reviews = reviews;
          _myBookmarks = myBookmarks;
          _myReviews = myReviews;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadMoreReviews() async {
    final current = _reviews;
    final book = _bookInfo;
    final api = ref.read(wereadApiProvider);
    if (current == null ||
        book == null ||
        api == null ||
        !current.hasMore ||
        current.reviews.isEmpty ||
        _isLoadingMoreReviews) {
      return;
    }

    setState(() {
      _isLoadingMoreReviews = true;
      _reviewsLoadFailed = false;
    });
    try {
      final next = await api.reviewList(
        bookId: book.bookId,
        count: 20,
        maxIdx: current.reviews.length,
      );
      if (!mounted) return;
      final seen = current.reviews
          .map(
            (item) => item.review.reviewId.isNotEmpty
                ? item.review.reviewId
                : 'idx:${item.idx}',
          )
          .toSet();
      final newReviews = next.reviews.where((item) {
        final key = item.review.reviewId.isNotEmpty
            ? item.review.reviewId
            : 'idx:${item.idx}';
        return seen.add(key);
      }).toList();
      setState(() {
        _reviews = ReviewListResponse(
          synckey: next.synckey,
          reviewsCnt: next.reviewsCnt == 0
              ? current.reviewsCnt
              : next.reviewsCnt,
          reviewsHasMore: newReviews.isEmpty ? 0 : next.reviewsHasMore,
          reviews: [...current.reviews, ...newReviews],
        );
      });
    } catch (error) {
      debugPrint('Failed to load more WeRead reviews: ${error.runtimeType}');
      if (mounted) setState(() => _reviewsLoadFailed = true);
    } finally {
      if (mounted) setState(() => _isLoadingMoreReviews = false);
    }
  }

  Future<void> _openInWeread() async {
    final book = _bookInfo;
    if (book == null) return;
    final link = _deepLink;
    if (link != null && link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri != null && uri.hasScheme) {
        if (await _launchWereadLink(uri)) return;
      }
    }

    await Clipboard.setData(ClipboardData(text: book.title));
    final openedApp = await _launchWereadHome();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(
            context,
          ).get(openedApp ? 'weread_search_copied' : 'weread_open_failed'),
        ),
      ),
    );
  }

  Future<bool> _launchWereadLink(Uri uri) async {
    if (kIsWeb) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: uri.toString(),
          package: 'com.tencent.weread',
        ).launch();
        return true;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      }
    } catch (error) {
      debugPrint('Failed to open WeRead deep link: ${error.runtimeType}');
    }
    return false;
  }

  Future<bool> _launchWereadHome() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      const intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.LAUNCHER',
        package: 'com.tencent.weread',
      );
      if (await intent.canResolveActivity() != true) return false;
      await intent.launch();
      return true;
    } catch (error) {
      debugPrint('Failed to launch WeRead app: ${error.runtimeType}');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final needsConfiguration = ref.watch(wereadApiProvider) == null;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: LoadingWidget(message: t.get('loading')),
      );
    }

    if (_error != null || _bookInfo == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                _error ?? t.get('error'),
                style: TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: needsConfiguration
                    ? () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const WereadMobileHubScreen(),
                          ),
                        );
                        if (mounted && ref.read(isWereadConnectedProvider)) {
                          _loadBookDetail();
                        }
                      }
                    : _loadBookDetail,
                child: Text(
                  t.get(needsConfiguration ? 'weread_go_settings' : 'recheck'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayBook = _bookInfo!.toDisplay();

    return Scaffold(
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _openInWeread,
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(
            t.get(
              _deepLink == null ? 'weread_search_in_app' : 'weread_open_in_app',
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // ── 共用封面与滚动导航 ──
          BookHeroSection(book: displayBook, isFavorited: false),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WereadAskBookScreen(
                      bookId: _bookInfo!.bookId,
                      title: _bookInfo!.title,
                    ),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(t.get('weread_ask_title')),
              ),
            ),
          ),

          // ── WeRead 专用信息区 ──
          WereadInfoSection(
            bookInfo: _bookInfo!,
            chapters: _chapters,
            bestBookmarks: _bestBookmarks,
            reviews: _reviews,
            myBookmarks: _myBookmarks,
            myReviews: _myReviews,
            isDark: isDark,
            onLoadMoreReviews: _loadMoreReviews,
            isLoadingMoreReviews: _isLoadingMoreReviews,
            reviewsLoadFailed: _reviewsLoadFailed,
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 48)),
        ],
      ),
    );
  }
}
