import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'weread_mobile_client.dart';
import 'weread_models.dart';

/// Mobile WeRead operations adapted from weread-omni's E-Ink client.
/// All requests use the same encrypted QR session as import and Ask Book.
class WereadApi {
  final WereadMobileClient _client;

  WereadApi(this._client);

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _client.call('GET', path, query: query, cancelToken: cancelToken);

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
    CancelToken? cancelToken,
  }) => _client.call(
    'POST',
    path,
    body: body,
    replayable: true,
    cancelToken: cancelToken,
  );

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
    final data = await _get(
      '/store/search',
      query: {
        'keyword': keyword,
        'scope': scope ?? 10,
        'maxIdx': maxIdx ?? 0,
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
    final data = await _get(
      '/book/info',
      query: {'bookId': bookId},
      cancelToken: cancelToken,
    );
    return WereadBookInfo.fromJson(data);
  }

  /// `/book/chapterinfo` — 章节目录
  Future<ChapterInfoResponse> chapters(
    String bookId, {
    CancelToken? cancelToken,
  }) async {
    final data = await _post(
      '/book/chapterInfos',
      body: {
        'bookIds': [bookId],
        'synckeys': [0],
        'updateTimes': [0],
        'maxfreeIdx': [0],
      },
      cancelToken: cancelToken,
    );
    final entries = data['data'];
    if (entries is! List) {
      throw const WereadMobileException('Chapter response omitted data');
    }
    final entry = entries.isNotEmpty && entries.first is Map
        ? Map<String, dynamic>.from(entries.first as Map)
        : <String, dynamic>{};
    final updated = entry['updated'];
    if (updated != null && updated is! List) {
      throw const WereadMobileException(
        'Chapter response has invalid chapters',
      );
    }
    return ChapterInfoResponse.fromJson({
      'bookId': entry['bookId'] ?? bookId,
      'synckey': entry['synckey'] ?? 0,
      'chapterUpdateTime': entry['chapterUpdateTime'],
      'chapters': updated ?? <dynamic>[],
    });
  }

  /// `/book/getprogress` — 阅读进度
  Future<BookProgress> progress(
    String bookId, {
    CancelToken? cancelToken,
  }) async {
    final data = await _get(
      '/book/getProgress',
      query: {'bookId': bookId},
      cancelToken: cancelToken,
    );
    return BookProgress.fromJson(data);
  }

  // ═════════════════════════════════════════════════════════════════
  // Shelf — 书架
  // ═════════════════════════════════════════════════════════════════

  /// `/shelf/sync` — 同步当前用户书架
  Future<ShelfSyncResponse> shelfSync({CancelToken? cancelToken}) async {
    final data = await _get('/shelf/sync', cancelToken: cancelToken);
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
    final data = await _get(
      '/readdata/detail',
      query: {
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
    final data = await _get(
      '/user/notebooks',
      query: {'count': count ?? 20, if (lastSort != null) 'lastSort': lastSort},
      cancelToken: cancelToken,
    );
    final snapshot = NotebooksResponse.fromJson(data);
    // The mobile endpoint currently returns the full descending snapshot.
    final start = lastSort == null
        ? 0
        : snapshot.books.indexWhere((book) => book.sort < lastSort);
    final remaining = start < 0
        ? <NotebookBook>[]
        : snapshot.books.skip(start).toList();
    final pageSize = count ?? 20;
    return NotebooksResponse(
      totalBookCount: snapshot.totalBookCount,
      totalNoteCount: snapshot.totalNoteCount,
      hasMore: remaining.length > pageSize || snapshot.hasMoreResults ? 1 : 0,
      books: remaining.take(pageSize).toList(),
    );
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
    final data = await _get(
      '/book/bookmarklist',
      query: {'bookId': bookId, 'synckey': synckey ?? 0},
      cancelToken: cancelToken,
    );
    return BookmarkListResponse.fromJson(data);
  }

  /// `/review/list` — 单本书的个人想法与点评
  Future<MineReviewListResponse> mineReviews(
    String bookId, {
    int? synckey,
    int? count,
    CancelToken? cancelToken,
  }) async {
    final data = await _get(
      '/review/list',
      query: {
        'bookId': bookId,
        'listType': 1,
        'listMode': 0,
        'mine': 1,
        'synckey': synckey ?? 0,
        'count': count ?? 20,
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
    final data = await _get(
      '/book/underlines',
      query: {
        'bookId': bookId,
        'chapterUid': chapterUid,
        'synckey': synckey ?? 0,
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
    final data = await _get(
      '/book/bestbookmarks',
      query: {
        'bookId': bookId,
        'chapterUid': chapterUid ?? 0,
        'count': 21,
        'maxIdx': 0,
        'synckey': synckey ?? 0,
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
    final data = await _post(
      '/book/readreviews',
      body: {
        'bookId': bookId,
        'chapterUid': chapterUid,
        'cht2sMode': '',
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
    final data = await _get(
      '/review/single',
      query: {
        'reviewId': reviewId,
        'commentsCount': commentsCount ?? 10,
        'commentsDirection': commentsDirection ?? 0,
        'likesCount': likesCount ?? 10,
        'likesDirection': likesDirection ?? 0,
        'synckey': synckey ?? 0,
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
    CancelToken? cancelToken,
  }) async {
    final offset = maxIdx ?? 0;
    final pageSize = count ?? 20;
    final data = await _get(
      '/review/list',
      query: {
        'bookId': bookId,
        'listType': reviewListType ?? 1,
        'listMode': 0,
        'mine': 0,
        'count': offset + pageSize + 1,
        'maxIdx': 0,
        'synckey': 0,
      },
      cancelToken: cancelToken,
    );
    final raw = data['reviews'];
    if (raw is! List) {
      throw const WereadMobileException('Review response omitted reviews');
    }
    final page = raw.skip(offset).take(pageSize).toList();
    return ReviewListResponse.fromJson({
      ...data,
      'reviews': page,
      'reviewsHasMore': raw.length > offset + pageSize || data['hasMore'] == 1
          ? 1
          : 0,
    });
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
    final data = await _get(
      '/book/recommend',
      query: {'count': count ?? 12, 'maxIdx': maxIdx ?? 0},
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
    final data = await _get(
      '/book/detailinfo',
      query: {
        'bookId': bookId,
        'listtypes': 2,
        'synckey': 0,
        'count': count ?? 12,
        'maxIdx': maxIdx ?? 0,
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
      } catch (error) {
        debugPrint('WeRead progress unavailable: ${error.runtimeType}');
        return null;
      }
    });

    final results = await Future.wait(futures);
    final recent = results.whereType<ProfileRecentBook>().toList();

    return ProfileSummary(shelf: shelf, shelfTotal: shelfTotal, recent: recent);
  }
}
