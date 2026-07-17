import 'package:dio/dio.dart';
import 'weread_client.dart';
import 'weread_models.dart';

/// 微信读书聚合 API
///
/// 对应 OpenWeRead TypeScript SDK 的 sdk.ts + 8 个 API 模块。
/// 将所有模块方法聚合在一个类中，Dart 中比拆 8 个文件更紧凑。
class WereadApi {
  final WereadClient _client;

  WereadApi({required String apiKey, String? baseUrl})
      : _client = WereadClient(apiKey: apiKey, baseUrl: baseUrl);

  /// 获取底层 client（高级用途）
  WereadClient get client => _client;

  /// 释放资源
  void close() => _client.close();

  // ═════════════════════════════════════════════════════════════════
  // Search — 搜索
  // ═════════════════════════════════════════════════════════════════

  /// `/store/search` — 在书城搜索书籍、作者、文章等
  ///
  /// [keyword] 搜索关键词
  /// [scope]   搜索类型: 0=全部, 10=电子书, 16=网文, 14=听书,
  ///           6=作者, 12=全文, 13=书单, 2=公众号, 4=文章
  /// [maxIdx]  翻页偏移，用上一页最后一条的 searchIdx
  /// [count]   每页数量，不传则服务端默认 15
  Future<SearchResponse> search({
    required String keyword,
    int? scope,
    int? maxIdx,
    int? count,
    CancelToken? cancelToken,
  }) async {
    final data = await _client.call(
      '/store/search',
      params: {
        'keyword': keyword,
        if (scope != null) 'scope': scope,
        if (maxIdx != null) 'maxIdx': maxIdx,
        if (count != null) 'count': count,
      },
      cancelToken: cancelToken,
    );
    return SearchResponse.fromJson(data);
  }

  // ═════════════════════════════════════════════════════════════════
  // Book — 书籍详情 / 章节 / 进度
  // ═════════════════════════════════════════════════════════════════

  /// `/book/info` — 书籍基本信息
  Future<WereadBookInfo> bookInfo(
    String bookId, {
    CancelToken? cancelToken,
  }) async {
    final data = await _client.call(
      '/book/info',
      params: {'bookId': bookId},
      cancelToken: cancelToken,
    );
    return WereadBookInfo.fromJson(data);
  }

  /// `/book/chapterinfo` — 章节目录
  Future<ChapterInfoResponse> chapters(
    String bookId, {
    CancelToken? cancelToken,
  }) async {
    final data = await _client.call(
      '/book/chapterinfo',
      params: {'bookId': bookId},
      cancelToken: cancelToken,
    );
    return ChapterInfoResponse.fromJson(data);
  }

  /// `/book/getprogress` — 阅读进度
  Future<BookProgress> progress(
    String bookId, {
    CancelToken? cancelToken,
  }) async {
    final data = await _client.call(
      '/book/getprogress',
      params: {'bookId': bookId},
      cancelToken: cancelToken,
    );
    return BookProgress.fromJson(data);
  }

  // ═════════════════════════════════════════════════════════════════
  // Shelf — 书架
  // ═════════════════════════════════════════════════════════════════

  /// `/shelf/sync` — 同步当前用户书架
  Future<ShelfSyncResponse> shelfSync({CancelToken? cancelToken}) async {
    final data = await _client.call('/shelf/sync', cancelToken: cancelToken);
    return ShelfSyncResponse.fromJson(data);
  }

  // ═════════════════════════════════════════════════════════════════
  // ReadData — 阅读统计
  // ═════════════════════════════════════════════════════════════════

  /// `/readdata/detail` — 阅读统计详情
  ///
  /// [mode] 'weekly' | 'monthly' | 'annually' | 'overall'
  /// [baseTime] 基准时间戳
  Future<ReadDataResponse> readDataDetail({
    String? mode,
    int? baseTime,
    CancelToken? cancelToken,
  }) async {
    final data = await _client.call(
      '/readdata/detail',
      params: {
        if (mode != null) 'mode': mode,
        if (baseTime != null) 'baseTime': baseTime,
      },
      cancelToken: cancelToken,
    );
    return ReadDataResponse.fromJson(data);
  }

  // ═════════════════════════════════════════════════════════════════
  // Notes — 笔记 / 划线
  // ═════════════════════════════════════════════════════════════════

  /// `/user/notebooks` — 所有有笔记的书
  ///
  /// 使用 lastSort 游标分页，不支持 offset/limit
  Future<NotebooksResponse> notebooks({
    int? count,
    int? lastSort,
    CancelToken? cancelToken,
  }) async {
    final data = await _client.call(
      '/user/notebooks',
      params: {
        if (count != null) 'count': count,
        if (lastSort != null) 'lastSort': lastSort,
      },
      cancelToken: cancelToken,
    );
    return NotebooksResponse.fromJson(data);
  }

  /// 遍历拉取所有笔记本概览，自动按 lastSort 翻页
  ///
  /// ```dart
  /// await for (final book in weread.notebooksAll()) { ... }
  /// ```
  Stream<NotebookBook> notebooksAll({int pageSize = 100}) async* {
    int? lastSort;
    while (true) {
      final page = await notebooks(count: pageSize, lastSort: lastSort);
      for (final book in page.books) {
        yield book;
      }
      if (!page.hasMoreResults || page.books.isEmpty) return;
      lastSort = page.books.last.sort;
    }
  }

  /// `/book/bookmarklist` — 单本书的划线内容（已过滤书签）
  Future<BookmarkListResponse> bookmarks(
    String bookId, {
    int? synckey,
    CancelToken? cancelToken,
  }) async {
    final data = await _client.call(
      '/book/bookmarklist',
      params: {
        'bookId': bookId,
        if (synckey != null) 'synckey': synckey,
      },
      cancelToken: cancelToken,
    );
    return BookmarkListResponse.fromJson(data);
  }

  /// `/review/list/mine` — 单本书的个人想法与点评
  Future<MineReviewListResponse> mineReviews(
    String bookId, {
    int? synckey,
    int? count,
    CancelToken? cancelToken,
  }) async {
    final data = await _client.call(
      '/review/list/mine',
      params: {
        'bookid': bookId, // 注意：文档中此处参数名是 bookid（小写 i）
        if (synckey != null) 'synckey': synckey,
        if (count != null) 'count': count,
      },
      cancelToken: cancelToken,
    );
    return MineReviewListResponse.fromJson(data);
  }

  /// `/book/underlines` — 章节划线热度统计（不含文本）
  Future<UnderlinesResponse> underlines(
    String bookId,
    int chapterUid, {
    int? synckey,
    CancelToken? cancelToken,
  }) async {
    final data = await _client.call(
      '/book/underlines',
      params: {
        'bookId': bookId,
        'chapterUid': chapterUid,
        if (synckey != null) 'synckey': synckey,
      },
      cancelToken: cancelToken,
    );
    return UnderlinesResponse.fromJson(data);
  }

  /// `/book/bestbookmarks` — 全书热门划线（含原文与人数，固定前 20 条）
  Future<BestBookmarksResponse> bestBookmarks(
    String bookId, {
    int? chapterUid,
    int? synckey,
    CancelToken? cancelToken,
  }) async {
    final data = await _client.call(
      '/book/bestbookmarks',
      params: {
        'bookId': bookId,
        if (chapterUid != null) 'chapterUid': chapterUid,
        if (synckey != null) 'synckey': synckey,
      },
      cancelToken: cancelToken,
    );
    return BestBookmarksResponse.fromJson(data);
  }

  /// `/book/readreviews` — 划线下的想法/评论
  Future<ReadReviewsResponse> readReviews(
    String bookId,
    int chapterUid,
    List<ReadReviewsRangeParams> reviews, {
    CancelToken? cancelToken,
  }) async {
    final data = await _client.call(
      '/book/readreviews',
      params: {
        'bookId': bookId,
        'chapterUid': chapterUid,
        'reviews': reviews.map((r) => r.toJson()).toList(),
      },
      cancelToken: cancelToken,
    );
    return ReadReviewsResponse.fromJson(data);
  }

  /// `/review/single` — 单条想法详情
  Future<ReviewSingleResponse> reviewSingle(
    String reviewId, {
    int? commentsCount,
    int? commentsDirection,
    int? likesCount,
    int? likesDirection,
    int? synckey,
    CancelToken? cancelToken,
  }) async {
    final data = await _client.call(
      '/review/single',
      params: {
        'reviewId': reviewId,
        if (commentsCount != null) 'commentsCount': commentsCount,
        if (commentsDirection != null)
          'commentsDirection': commentsDirection,
        if (likesCount != null) 'likesCount': likesCount,
        if (likesDirection != null) 'likesDirection': likesDirection,
        if (synckey != null) 'synckey': synckey,
      },
      cancelToken: cancelToken,
    );
    return ReviewSingleResponse.fromJson(data);
  }

  // ═════════════════════════════════════════════════════════════════
  // Review — 公开点评
  // ═════════════════════════════════════════════════════════════════

  /// `/review/list` — 书籍公开点评
  ///
  /// [reviewListType] 0=全部, 1=推荐, 2=最新, 3=好友, 4=好评
  Future<ReviewListResponse> reviewList({
    required String bookId,
    int? reviewListType,
    int? count,
    int? maxIdx,
    int? synckey,
    CancelToken? cancelToken,
  }) async {
    final data = await _client.call(
      '/review/list',
      params: {
        'bookId': bookId,
        if (reviewListType != null) 'reviewListType': reviewListType,
        if (count != null) 'count': count,
        if (maxIdx != null) 'maxIdx': maxIdx,
        if (synckey != null) 'synckey': synckey,
      },
      cancelToken: cancelToken,
    );
    return ReviewListResponse.fromJson(data);
  }

  // ═════════════════════════════════════════════════════════════════
  // Discover — 推荐
  // ═════════════════════════════════════════════════════════════════

  /// `/book/recommend` — 个性化推荐
  Future<RecommendResponse> recommend({
    int? count,
    int? maxIdx,
    CancelToken? cancelToken,
  }) async {
    final data = await _client.call(
      '/book/recommend',
      params: {
        if (count != null) 'count': count,
        if (maxIdx != null) 'maxIdx': maxIdx,
      },
      cancelToken: cancelToken,
    );
    return RecommendResponse.fromJson(data);
  }

  /// `/book/similar` — 相似书推荐
  Future<SimilarResponse> similar({
    required String bookId,
    int? count,
    int? maxIdx,
    String? sessionId,
    CancelToken? cancelToken,
  }) async {
    final data = await _client.call(
      '/book/similar',
      params: {
        'bookId': bookId,
        if (count != null) 'count': count,
        if (maxIdx != null) 'maxIdx': maxIdx,
        if (sessionId != null) 'sessionId': sessionId,
      },
      cancelToken: cancelToken,
    );
    return SimilarResponse.fromJson(data);
  }

  // ═════════════════════════════════════════════════════════════════
  // Profile — 用户概况（组合接口）
  // ═════════════════════════════════════════════════════════════════

  /// 组合 `/shelf/sync` + 多次 `/book/getprogress`，返回阅读概况
  ///
  /// 默认只拉取最近 5 本电子书的进度，避免请求过多。
  Future<ProfileSummary> profileSummary({
    int recentCount = 5,
    CancelToken? cancelToken,
  }) async {
    final shelf = await shelfSync(cancelToken: cancelToken);
    final shelfTotal = shelf.totalCount;

    // 按最近阅读时间排序
    final sorted = List<ShelfBook>.from(shelf.books)
      ..sort((a, b) => (b.readUpdateTime ?? 0) - (a.readUpdateTime ?? 0));
    final recentBooks = sorted.take(recentCount);

    // 并发拉取进度
    final futures = recentBooks.map((b) async {
      try {
        final p = await progress(b.bookId, cancelToken: cancelToken);
        return ProfileRecentBook(
          bookId: b.bookId,
          title: b.title,
          progress: p.book,
        );
      } catch (_) {
        return null;
      }
    });

    final results = await Future.wait(futures);
    final recent = results.whereType<ProfileRecentBook>().toList();

    return ProfileSummary(
      shelf: shelf,
      shelfTotal: shelfTotal,
      recent: recent,
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // Utility
  // ═════════════════════════════════════════════════════════════════

  /// 查询网关上所有可用接口及参数定义
  Future<Map<String, dynamic>> listApis({CancelToken? cancelToken}) {
    return _client.listApis(cancelToken: cancelToken);
  }
}
