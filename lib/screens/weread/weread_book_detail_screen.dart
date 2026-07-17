import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/weread_provider.dart';
import '../../models/display_book.dart';
import '../../widgets/loading_widget.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/weread/weread_models.dart';
import '../book_detail/widgets/book_hero_section.dart';
import 'widgets/weread_info_section.dart';

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
  String? _error;

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
      String shelfBookId, dynamic api) async {
    if (!shelfBookId.startsWith('CB_')) return null;
    try {
      final notebooks = await api.notebooks(count: 200);
      for (final nb in notebooks.books) {
        // 匹配封面 URL 中的原始 bookId 或直接匹配
        if (nb.bookId == shelfBookId) return shelfBookId;
        if (nb.book.cover != null &&
            nb.book.cover!.contains(shelfBookId)) {
          return nb.bookId;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadBookDetail() async {
    final bookId = ModalRoute.of(context)!.settings.arguments as String;
    final api = ref.read(wereadApiProvider);
    if (api == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load book info first (required)
      final bookInfo = await api.bookInfo(bookId);

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
          api.chapters(bookId),
          api.bestBookmarks(bookId).catchError((_) =>
              const BestBookmarksResponse(synckey: 0, totalCount: 0, items: [])),
          api.reviewList(bookId: bookId, count: 10).catchError((_) =>
              const ReviewListResponse(synckey: 0, reviewsCnt: 0, reviews: [])),
        ]);
        chapters = results[0] as ChapterInfoResponse;
        bestBookmarks = results[1] as BestBookmarksResponse;
        reviews = results[2] as ReviewListResponse;
      } catch (_) {}

      // Group 2: Personal notes (use resolved noteBookId for uploaded books)
      try {
        final noteResults = await Future.wait([
          api.bookmarks(noteBookId).catchError((_) =>
              const BookmarkListResponse(updated: [])),
          api.mineReviews(noteBookId).catchError((_) =>
              const MineReviewListResponse(
                  totalCount: 0, hasMore: 0, synckey: 0, reviews: [])),
        ]);
        myBookmarks = noteResults[0] as BookmarkListResponse;
        myReviews = noteResults[1] as MineReviewListResponse;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _bookInfo = bookInfo;
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              Text(_error ?? t.get('error'),
                  style: TextStyle(color: AppColors.error)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadBookDetail,
                child: Text(t.get('recheck')),
              ),
            ],
          ),
        ),
      );
    }

    final displayBook = _bookInfo!.toDisplay();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero Section (复用 ZLib 的毛玻璃封面) ──
          BookHeroSection(
            book: displayBook,
            isDark: isDark,
            isFavorited: false,
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
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 48)),
        ],
      ),
    );
  }
}
