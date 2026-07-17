/// 微信读书 API 数据模型
///
/// 对应 OpenWeRead TypeScript SDK 的 types.ts 及各 API 模块的 interface。
/// 手写 fromJson，与项目中 ReadingBag / ReadingTip 风格保持一致。
library;

// ═══════════════════════════════════════════════════════════════════
// 通用
// ═══════════════════════════════════════════════════════════════════

/// 书籍基本信息 — 多个接口共用
class WereadBookInfo {
  final String bookId;
  final String title;
  final String? author;
  final String? translator;
  final String? cover;
  final String? intro;
  final String? category;
  final String? publisher;
  final String? publishTime;
  final String? isbn;
  final int? wordCount;
  final int? newRating;
  final int? newRatingCount;
  final String? newRatingTitle; // newRatingDetail.title
  final int? payType;
  final int? price;
  final int? soldout;

  const WereadBookInfo({
    required this.bookId,
    required this.title,
    this.author,
    this.translator,
    this.cover,
    this.intro,
    this.category,
    this.publisher,
    this.publishTime,
    this.isbn,
    this.wordCount,
    this.newRating,
    this.newRatingCount,
    this.newRatingTitle,
    this.payType,
    this.price,
    this.soldout,
  });

  factory WereadBookInfo.fromJson(Map<String, dynamic> json) {
    final ratingDetail = json['newRatingDetail'] as Map<String, dynamic>?;
    return WereadBookInfo(
      bookId: json['bookId'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      translator: json['translator'] as String?,
      cover: json['cover'] as String?,
      intro: json['intro'] as String?,
      category: json['category'] as String?,
      publisher: json['publisher'] as String?,
      publishTime: json['publishTime'] as String?,
      isbn: json['isbn'] as String?,
      wordCount: _asInt(json['wordCount']),
      newRating: _asInt(json['newRating']),
      newRatingCount: _asInt(json['newRatingCount']),
      newRatingTitle: ratingDetail?['title'] as String?,
      payType: _asInt(json['payType']),
      price: _asInt(json['price']),
      soldout: _asInt(json['soldout']),
    );
  }

  /// 评分格式化：0-100 → 0.0-10.0
  double? get ratingScore =>
      newRating != null ? newRating! / 10.0 : null;

  /// 是否已下架
  bool get isSoldout => soldout == 1;
}

// ═══════════════════════════════════════════════════════════════════
// Search — 搜索
// ═══════════════════════════════════════════════════════════════════

class SearchResultBook {
  final int searchIdx;
  final WereadBookInfo bookInfo;
  final int? readingCount;
  final int? newRating;
  final int? newRatingCount;
  final String? newRatingTitle;

  const SearchResultBook({
    required this.searchIdx,
    required this.bookInfo,
    this.readingCount,
    this.newRating,
    this.newRatingCount,
    this.newRatingTitle,
  });

  factory SearchResultBook.fromJson(Map<String, dynamic> json) {
    final ratingDetail = json['newRatingDetail'] as Map<String, dynamic>?;
    return SearchResultBook(
      searchIdx: _asInt(json['searchIdx']) ?? 0,
      bookInfo: WereadBookInfo.fromJson(json['bookInfo'] as Map<String, dynamic>),
      readingCount: _asInt(json['readingCount']),
      newRating: _asInt(json['newRating']),
      newRatingCount: _asInt(json['newRatingCount']),
      newRatingTitle: ratingDetail?['title'] as String?,
    );
  }
}

class SearchResultGroup {
  final String title;
  final int scope;
  final int scopeCount;
  final int currentCount;
  final List<SearchResultBook> books;

  const SearchResultGroup({
    required this.title,
    required this.scope,
    required this.scopeCount,
    required this.currentCount,
    required this.books,
  });

  factory SearchResultGroup.fromJson(Map<String, dynamic> json) {
    return SearchResultGroup(
      title: json['title'] as String,
      scope: json['scope'] as int,
      scopeCount: json['scopeCount'] as int,
      currentCount: json['currentCount'] as int,
      books: (json['books'] as List<dynamic>?)
              ?.map((e) => SearchResultBook.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SearchResponse {
  final String sid;
  final int hasMore;
  final List<SearchResultGroup> results;

  const SearchResponse({
    required this.sid,
    required this.hasMore,
    required this.results,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      sid: json['sid'] as String? ?? '',
      hasMore: json['hasMore'] as int? ?? 0,
      results: (json['results'] as List<dynamic>?)
              ?.map((e) => SearchResultGroup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get hasMoreResults => hasMore == 1;
}

// ═══════════════════════════════════════════════════════════════════
// Book — 书籍详情 / 章节 / 进度
// ═══════════════════════════════════════════════════════════════════

class ChapterInfo {
  final int chapterUid;
  final int chapterIdx;
  final String title;
  final int? wordCount;
  final int? level;
  final int? updateTime;
  final int? price;
  final int? paid;
  final int? isMPChapter;

  const ChapterInfo({
    required this.chapterUid,
    required this.chapterIdx,
    required this.title,
    this.wordCount,
    this.level,
    this.updateTime,
    this.price,
    this.paid,
    this.isMPChapter,
  });

  factory ChapterInfo.fromJson(Map<String, dynamic> json) {
    return ChapterInfo(
      chapterUid: json['chapterUid'] as int,
      chapterIdx: json['chapterIdx'] as int,
      title: json['title'] as String,
      wordCount: json['wordCount'] as int?,
      level: json['level'] as int?,
      updateTime: json['updateTime'] as int?,
      price: json['price'] as int?,
      paid: json['paid'] as int?,
      isMPChapter: json['isMPChapter'] as int?,
    );
  }
}

class ChapterInfoResponse {
  final String bookId;
  final int synckey;
  final int? chapterUpdateTime;
  final List<ChapterInfo> chapters;

  const ChapterInfoResponse({
    required this.bookId,
    required this.synckey,
    this.chapterUpdateTime,
    required this.chapters,
  });

  factory ChapterInfoResponse.fromJson(Map<String, dynamic> json) {
    return ChapterInfoResponse(
      bookId: json['bookId'] as String,
      synckey: json['synckey'] as int,
      chapterUpdateTime: json['chapterUpdateTime'] as int?,
      chapters: (json['chapters'] as List<dynamic>?)
              ?.map((e) => ChapterInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BookProgressData {
  final int? chapterUid;
  final int? chapterOffset;
  /// 0-100, 1 表示 1%
  final int progress;
  final int? updateTime;
  final int? recordReadingTime;
  final int? finishTime;
  final int? isStartReading;

  const BookProgressData({
    this.chapterUid,
    this.chapterOffset,
    required this.progress,
    this.updateTime,
    this.recordReadingTime,
    this.finishTime,
    this.isStartReading,
  });

  factory BookProgressData.fromJson(Map<String, dynamic> json) {
    return BookProgressData(
      chapterUid: json['chapterUid'] as int?,
      chapterOffset: json['chapterOffset'] as int?,
      progress: json['progress'] as int? ?? 0,
      updateTime: json['updateTime'] as int?,
      recordReadingTime: json['recordReadingTime'] as int?,
      finishTime: json['finishTime'] as int?,
      isStartReading: json['isStartReading'] as int?,
    );
  }

  bool get isFinished => finishTime != null && finishTime! > 0;
}

class BookProgress {
  final String bookId;
  final BookProgressData book;

  const BookProgress({required this.bookId, required this.book});

  factory BookProgress.fromJson(Map<String, dynamic> json) {
    return BookProgress(
      bookId: json['bookId'] as String,
      book: BookProgressData.fromJson(json['book'] as Map<String, dynamic>),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shelf — 书架
// ═══════════════════════════════════════════════════════════════════

class ShelfBook {
  final String bookId;
  final String title;
  final String? author;
  final String? cover;
  final String? category;
  final int? readUpdateTime;
  final int? finishReading;
  final int? updateTime;
  final int? isTop;
  final int? secret;

  const ShelfBook({
    required this.bookId,
    required this.title,
    this.author,
    this.cover,
    this.category,
    this.readUpdateTime,
    this.finishReading,
    this.updateTime,
    this.isTop,
    this.secret,
  });

  factory ShelfBook.fromJson(Map<String, dynamic> json) {
    return ShelfBook(
      bookId: json['bookId'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      cover: json['cover'] as String?,
      category: json['category'] as String?,
      readUpdateTime: json['readUpdateTime'] as int?,
      finishReading: json['finishReading'] as int?,
      updateTime: json['updateTime'] as int?,
      isTop: json['isTop'] as int?,
      secret: json['secret'] as int?,
    );
  }

  bool get isPinned => isTop == 1;
  bool get isSecret => secret == 1;
  bool get isFinished => finishReading == 1;
}

class ShelfAlbumInfo {
  final String albumId;
  final String name;
  final String? authorName;
  final String? cover;
  final int? trackCount;
  final String? finishStatus;
  final int? finish;
  final int? payType;
  final String? intro;
  final int? updateTime;

  const ShelfAlbumInfo({
    required this.albumId,
    required this.name,
    this.authorName,
    this.cover,
    this.trackCount,
    this.finishStatus,
    this.finish,
    this.payType,
    this.intro,
    this.updateTime,
  });

  factory ShelfAlbumInfo.fromJson(Map<String, dynamic> json) {
    return ShelfAlbumInfo(
      albumId: json['albumId'] as String,
      name: json['name'] as String,
      authorName: json['authorName'] as String?,
      cover: json['cover'] as String?,
      trackCount: json['trackCount'] as int?,
      finishStatus: json['finishStatus'] as String?,
      finish: json['finish'] as int?,
      payType: json['payType'] as int?,
      intro: json['intro'] as String?,
      updateTime: json['updateTime'] as int?,
    );
  }
}

class ShelfAlbumExtra {
  final int? secret;
  final int? lecturePaid;
  final int? lectureReadUpdateTime;
  final int? isTop;

  const ShelfAlbumExtra({
    this.secret,
    this.lecturePaid,
    this.lectureReadUpdateTime,
    this.isTop,
  });

  factory ShelfAlbumExtra.fromJson(Map<String, dynamic> json) {
    return ShelfAlbumExtra(
      secret: json['secret'] as int?,
      lecturePaid: json['lecturePaid'] as int?,
      lectureReadUpdateTime: json['lectureReadUpdateTime'] as int?,
      isTop: json['isTop'] as int?,
    );
  }
}

class ShelfAlbum {
  final ShelfAlbumInfo albumInfo;
  final ShelfAlbumExtra? albumInfoExtra;

  const ShelfAlbum({required this.albumInfo, this.albumInfoExtra});

  factory ShelfAlbum.fromJson(Map<String, dynamic> json) {
    return ShelfAlbum(
      albumInfo: ShelfAlbumInfo.fromJson(json['albumInfo'] as Map<String, dynamic>),
      albumInfoExtra: json['albumInfoExtra'] != null
          ? ShelfAlbumExtra.fromJson(json['albumInfoExtra'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ShelfArchive {
  final String name;
  final List<String> bookIds;

  const ShelfArchive({required this.name, required this.bookIds});

  factory ShelfArchive.fromJson(Map<String, dynamic> json) {
    return ShelfArchive(
      name: json['name'] as String,
      bookIds: (json['bookIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

class ShelfSyncResponse {
  final List<ShelfBook> books;
  final List<ShelfAlbum> albums;
  final Map<String, dynamic>? mp;
  final List<ShelfArchive>? archive;
  final int? bookCount;

  const ShelfSyncResponse({
    required this.books,
    required this.albums,
    this.mp,
    this.archive,
    this.bookCount,
  });

  factory ShelfSyncResponse.fromJson(Map<String, dynamic> json) {
    return ShelfSyncResponse(
      books: (json['books'] as List<dynamic>?)
              ?.map((e) => ShelfBook.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      albums: (json['albums'] as List<dynamic>?)
              ?.map((e) => ShelfAlbum.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      mp: json['mp'] as Map<String, dynamic>?,
      archive: (json['archive'] as List<dynamic>?)
              ?.map((e) => ShelfArchive.fromJson(e as Map<String, dynamic>))
              .toList(),
      bookCount: json['bookCount'] as int?,
    );
  }

  /// 书架总条目数 = books + albums + (mp 非空 ? 1 : 0)
  int get totalCount {
    final mpCount = (mp != null && mp!.isNotEmpty) ? 1 : 0;
    return books.length + albums.length + mpCount;
  }

  /// 私密阅读数
  int get secretCount {
    int count = books.where((b) => b.isSecret).length;
    count += albums.where((a) => a.albumInfoExtra?.secret == 1).length;
    if (mp != null && mp!.isNotEmpty) count += 1;
    return count;
  }

  /// 公开阅读数
  int get publicCount => totalCount - secretCount;
}

// ═══════════════════════════════════════════════════════════════════
// ReadData — 阅读统计
// ═══════════════════════════════════════════════════════════════════

class ReadStatItem {
  final String stat;
  final String counts;
  final String? scheme;

  const ReadStatItem({
    required this.stat,
    required this.counts,
    this.scheme,
  });

  factory ReadStatItem.fromJson(Map<String, dynamic> json) {
    return ReadStatItem(
      stat: json['stat'] as String,
      counts: json['counts'] as String,
      scheme: json['scheme'] as String?,
    );
  }
}

class ReadDataResponse {
  final int baseTime;
  /// 秒
  final int totalReadTime;
  /// 秒
  final int? dayAverageReadTime;
  final int? readDays;
  final Map<String, int>? readTimes;
  final Map<String, int>? dailyReadTimes;
  final int? compare;
  final List<ReadStatItem>? readStat;
  final List<Map<String, dynamic>>? readLongest;
  final List<Map<String, dynamic>>? preferCategory;
  final List<int>? preferTime;
  final String? preferTimeWord;
  final List<Map<String, dynamic>>? preferAuthor;
  final int? authorCount;
  final List<Map<String, dynamic>>? preferPublisher;
  final Map<String, dynamic>? rank;

  const ReadDataResponse({
    required this.baseTime,
    required this.totalReadTime,
    this.dayAverageReadTime,
    this.readDays,
    this.readTimes,
    this.dailyReadTimes,
    this.compare,
    this.readStat,
    this.readLongest,
    this.preferCategory,
    this.preferTime,
    this.preferTimeWord,
    this.preferAuthor,
    this.authorCount,
    this.preferPublisher,
    this.rank,
  });

  factory ReadDataResponse.fromJson(Map<String, dynamic> json) {
    return ReadDataResponse(
      baseTime: _asInt(json['baseTime']) ?? 0,
      totalReadTime: _asInt(json['totalReadTime']) ?? 0,
      dayAverageReadTime: _asInt(json['dayAverageReadTime']),
      readDays: _asInt(json['readDays']),
      readTimes: _castIntMap(json['readTimes']),
      dailyReadTimes: _castIntMap(json['dailyReadTimes']),
      compare: _asInt(json['compare']),
      readStat: (json['readStat'] as List<dynamic>?)
          ?.map((e) => ReadStatItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      readLongest: _castMapList(json['readLongest']),
      preferCategory: _castMapList(json['preferCategory']),
      preferTime: (json['preferTime'] as List<dynamic>?)
          ?.map((e) => _asInt(e) ?? 0)
          .toList(),
      preferTimeWord: json['preferTimeWord'] as String?,
      preferAuthor: _castMapList(json['preferAuthor']),
      authorCount: _asInt(json['authorCount']),
      preferPublisher: _castMapList(json['preferPublisher']),
      rank: json['rank'] as Map<String, dynamic>?,
    );
  }

  /// 总阅读时长格式化
  String get formattedTotalReadTime => _formatDuration(totalReadTime);

  /// 日均阅读时长格式化
  String? get formattedDayAverageReadTime =>
      dayAverageReadTime != null ? _formatDuration(dayAverageReadTime!) : null;
}

// ═══════════════════════════════════════════════════════════════════
// Notes — 笔记 / 划线
// ═══════════════════════════════════════════════════════════════════

class NotebookBookInfo {
  final String bookId;
  final String title;
  final String? author;
  final String? cover;

  const NotebookBookInfo({
    required this.bookId,
    required this.title,
    this.author,
    this.cover,
  });

  factory NotebookBookInfo.fromJson(Map<String, dynamic> json) {
    return NotebookBookInfo(
      bookId: json['bookId'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      cover: json['cover'] as String?,
    );
  }
}

class NotebookBook {
  final String bookId;
  final NotebookBookInfo book;
  /// 想法/点评数
  final int reviewCount;
  /// 划线数（高亮原文条数）
  final int noteCount;
  /// 书签数
  final int bookmarkCount;
  final int? readingProgress;
  final int? markedStatus;
  final int sort;

  const NotebookBook({
    required this.bookId,
    required this.book,
    required this.reviewCount,
    required this.noteCount,
    required this.bookmarkCount,
    this.readingProgress,
    this.markedStatus,
    required this.sort,
  });

  factory NotebookBook.fromJson(Map<String, dynamic> json) {
    return NotebookBook(
      bookId: json['bookId'] as String,
      book: NotebookBookInfo.fromJson(json['book'] as Map<String, dynamic>),
      reviewCount: json['reviewCount'] as int? ?? 0,
      noteCount: json['noteCount'] as int? ?? 0,
      bookmarkCount: json['bookmarkCount'] as int? ?? 0,
      readingProgress: json['readingProgress'] as int?,
      markedStatus: json['markedStatus'] as int?,
      sort: json['sort'] as int,
    );
  }

  /// 笔记总数 = 划线 + 想法/点评 + 书签
  int get totalNoteCount => reviewCount + noteCount + bookmarkCount;

  /// 是否读完
  bool get isFinished => markedStatus == 1;
}

class NotebooksResponse {
  final int totalBookCount;
  final int totalNoteCount;
  final int hasMore;
  final List<NotebookBook> books;

  const NotebooksResponse({
    required this.totalBookCount,
    required this.totalNoteCount,
    required this.hasMore,
    required this.books,
  });

  factory NotebooksResponse.fromJson(Map<String, dynamic> json) {
    return NotebooksResponse(
      totalBookCount: json['totalBookCount'] as int? ?? 0,
      totalNoteCount: json['totalNoteCount'] as int? ?? 0,
      hasMore: json['hasMore'] as int? ?? 0,
      books: (json['books'] as List<dynamic>?)
              ?.map((e) => NotebookBook.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get hasMoreResults => hasMore == 1;
}

class Bookmark {
  final String bookmarkId;
  final String bookId;
  final int? chapterUid;
  /// 形如 "900-2004"
  final String range;
  final String markText;
  final int? createTime;
  final int? style;
  final int? type;

  const Bookmark({
    required this.bookmarkId,
    required this.bookId,
    this.chapterUid,
    required this.range,
    required this.markText,
    this.createTime,
    this.style,
    this.type,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      bookmarkId: json['bookmarkId'] as String,
      bookId: json['bookId'] as String,
      chapterUid: json['chapterUid'] as int?,
      range: json['range'] as String? ?? '',
      markText: json['markText'] as String? ?? '',
      createTime: json['createTime'] as int?,
      style: json['style'] as int?,
      type: json['type'] as int?,
    );
  }
}

class BookmarkChapter {
  final int chapterUid;
  final String? title;

  const BookmarkChapter({required this.chapterUid, this.title});

  factory BookmarkChapter.fromJson(Map<String, dynamic> json) {
    return BookmarkChapter(
      chapterUid: json['chapterUid'] as int,
      title: json['title'] as String?,
    );
  }
}

class BookmarkListResponse {
  final Map<String, dynamic>? book;
  final List<BookmarkChapter>? chapters;
  final List<Bookmark> updated;

  const BookmarkListResponse({
    this.book,
    this.chapters,
    required this.updated,
  });

  factory BookmarkListResponse.fromJson(Map<String, dynamic> json) {
    return BookmarkListResponse(
      book: json['book'] as Map<String, dynamic>?,
      chapters: (json['chapters'] as List<dynamic>?)
          ?.map((e) => BookmarkChapter.fromJson(e as Map<String, dynamic>))
          .toList(),
      updated: (json['updated'] as List<dynamic>?)
              ?.map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MineReviewItem {
  final String reviewId;
  final String content;
  final int? createTime;
  final int? star;
  final String? chapterName;
  final int? isFinish;
  final String? range;
  final int? chapterUid;
  final String? abstract_;

  const MineReviewItem({
    required this.reviewId,
    required this.content,
    this.createTime,
    this.star,
    this.chapterName,
    this.isFinish,
    this.range,
    this.chapterUid,
    this.abstract_,
  });

  factory MineReviewItem.fromJson(Map<String, dynamic> json) {
    return MineReviewItem(
      reviewId: json['reviewId'] as String,
      content: json['content'] as String? ?? '',
      createTime: json['createTime'] as int?,
      star: json['star'] as int?,
      chapterName: json['chapterName'] as String?,
      isFinish: json['isFinish'] as int?,
      range: json['range'] as String?,
      chapterUid: json['chapterUid'] as int?,
      abstract_: json['abstract'] as String?,
    );
  }
}

class MineReviewListResponse {
  final int totalCount;
  final int hasMore;
  final int synckey;
  final List<MineReviewItem> reviews;

  const MineReviewListResponse({
    required this.totalCount,
    required this.hasMore,
    required this.synckey,
    required this.reviews,
  });

  factory MineReviewListResponse.fromJson(Map<String, dynamic> json) {
    return MineReviewListResponse(
      totalCount: json['totalCount'] as int? ?? 0,
      hasMore: json['hasMore'] as int? ?? 0,
      synckey: json['synckey'] as int? ?? 0,
      reviews: (json['reviews'] as List<dynamic>?)
              ?.map((e) {
                final wrapper = e as Map<String, dynamic>;
                return MineReviewItem.fromJson(
                    wrapper['review'] as Map<String, dynamic>);
              })
              .toList() ??
          [],
    );
  }

  bool get hasMoreResults => hasMore == 1;
}

class UnderlineItem {
  final String range;
  final int count;
  final int? score;
  final int? type;

  const UnderlineItem({
    required this.range,
    required this.count,
    this.score,
    this.type,
  });

  factory UnderlineItem.fromJson(Map<String, dynamic> json) {
    return UnderlineItem(
      range: json['range'] as String,
      count: json['count'] as int,
      score: json['score'] as int?,
      type: json['type'] as int?,
    );
  }
}

class UnderlinesResponse {
  final String bookId;
  final int chapterUid;
  final int synckey;
  final List<UnderlineItem> underlines;

  const UnderlinesResponse({
    required this.bookId,
    required this.chapterUid,
    required this.synckey,
    required this.underlines,
  });

  factory UnderlinesResponse.fromJson(Map<String, dynamic> json) {
    return UnderlinesResponse(
      bookId: json['bookId'] as String,
      chapterUid: json['chapterUid'] as int,
      synckey: json['synckey'] as int? ?? 0,
      underlines: (json['underlines'] as List<dynamic>?)
              ?.map((e) => UnderlineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BestBookmarkItem {
  final String bookId;
  final String? userVid;
  final String bookmarkId;
  final int chapterUid;
  final String range;
  final String markText;
  final int totalCount;
  final String? simplifiedRange;
  final String? traditionalRange;

  const BestBookmarkItem({
    required this.bookId,
    this.userVid,
    required this.bookmarkId,
    required this.chapterUid,
    required this.range,
    required this.markText,
    required this.totalCount,
    this.simplifiedRange,
    this.traditionalRange,
  });

  factory BestBookmarkItem.fromJson(Map<String, dynamic> json) {
    return BestBookmarkItem(
      bookId: json['bookId'] as String,
      userVid: json['userVid']?.toString(),
      bookmarkId: json['bookmarkId'] as String,
      chapterUid: json['chapterUid'] as int,
      range: json['range'] as String,
      markText: json['markText'] as String? ?? '',
      totalCount: json['totalCount'] as int,
      simplifiedRange: json['simplifiedRange'] as String?,
      traditionalRange: json['traditionalRange'] as String?,
    );
  }
}

class BestBookmarkChapter {
  final String bookId;
  final int chapterUid;
  final int? chapterIdx;
  final String? title;

  const BestBookmarkChapter({
    required this.bookId,
    required this.chapterUid,
    this.chapterIdx,
    this.title,
  });

  factory BestBookmarkChapter.fromJson(Map<String, dynamic> json) {
    return BestBookmarkChapter(
      bookId: json['bookId'] as String,
      chapterUid: json['chapterUid'] as int,
      chapterIdx: json['chapterIdx'] as int?,
      title: json['title'] as String?,
    );
  }
}

class BestBookmarksResponse {
  final int synckey;
  final int totalCount;
  final List<BestBookmarkItem> items;
  final List<BestBookmarkChapter>? chapters;

  const BestBookmarksResponse({
    required this.synckey,
    required this.totalCount,
    required this.items,
    this.chapters,
  });

  factory BestBookmarksResponse.fromJson(Map<String, dynamic> json) {
    return BestBookmarksResponse(
      synckey: json['synckey'] as int? ?? 0,
      totalCount: json['totalCount'] as int? ?? 0,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => BestBookmarkItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      chapters: (json['chapters'] as List<dynamic>?)
          ?.map((e) => BestBookmarkChapter.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── ReadReviews (划线下的想法) ──

class ReadReviewsRangeParams {
  final String range;
  final int? maxIdx;
  final int? count;
  final int? synckey;

  const ReadReviewsRangeParams({
    required this.range,
    this.maxIdx,
    this.count,
    this.synckey,
  });

  Map<String, dynamic> toJson() {
    return {
      'range': range,
      if (maxIdx != null) 'maxIdx': maxIdx,
      if (count != null) 'count': count,
      if (synckey != null) 'synckey': synckey,
    };
  }
}

class ReadReviewAuthor {
  final String userVid;
  final String name;
  final String? avatar;

  const ReadReviewAuthor({
    required this.userVid,
    required this.name,
    this.avatar,
  });

  factory ReadReviewAuthor.fromJson(Map<String, dynamic> json) {
    return ReadReviewAuthor(
      userVid: json['userVid']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String?,
    );
  }
}

class ReadReviewDetail {
  final String reviewId;
  final String? abstract_;
  final String content;
  final String? range;
  final int? createTime;
  final ReadReviewAuthor? author;

  const ReadReviewDetail({
    required this.reviewId,
    this.abstract_,
    required this.content,
    this.range,
    this.createTime,
    this.author,
  });

  factory ReadReviewDetail.fromJson(Map<String, dynamic> json) {
    return ReadReviewDetail(
      reviewId: json['reviewId'] as String,
      abstract_: json['abstract'] as String?,
      content: json['content'] as String? ?? '',
      range: json['range'] as String?,
      createTime: json['createTime'] as int?,
      author: json['author'] != null
          ? ReadReviewAuthor.fromJson(json['author'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ReadReviewPageReview {
  final String reviewId;
  final ReadReviewDetail review;

  const ReadReviewPageReview({
    required this.reviewId,
    required this.review,
  });

  factory ReadReviewPageReview.fromJson(Map<String, dynamic> json) {
    return ReadReviewPageReview(
      reviewId: json['reviewId'] as String,
      review: ReadReviewDetail.fromJson(json['review'] as Map<String, dynamic>),
    );
  }
}

class ReadReviewsRangeResult {
  final String range;
  final int totalCount;
  final int hasMore;
  final int maxIdx;
  final int synckey;
  final List<ReadReviewPageReview> pageReviews;

  const ReadReviewsRangeResult({
    required this.range,
    required this.totalCount,
    required this.hasMore,
    required this.maxIdx,
    required this.synckey,
    required this.pageReviews,
  });

  factory ReadReviewsRangeResult.fromJson(Map<String, dynamic> json) {
    return ReadReviewsRangeResult(
      range: json['range'] as String,
      totalCount: json['totalCount'] as int? ?? 0,
      hasMore: json['hasMore'] as int? ?? 0,
      maxIdx: json['maxIdx'] as int? ?? 0,
      synckey: json['synckey'] as int? ?? 0,
      pageReviews: (json['pageReviews'] as List<dynamic>?)
              ?.map((e) =>
                  ReadReviewPageReview.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get hasMoreResults => hasMore == 1;
}

class ReadReviewsResponse {
  final String bookId;
  final int chapterUid;
  final List<ReadReviewsRangeResult> reviews;

  const ReadReviewsResponse({
    required this.bookId,
    required this.chapterUid,
    required this.reviews,
  });

  factory ReadReviewsResponse.fromJson(Map<String, dynamic> json) {
    return ReadReviewsResponse(
      bookId: json['bookId'] as String,
      chapterUid: json['chapterUid'] as int,
      reviews: (json['reviews'] as List<dynamic>?)
              ?.map((e) =>
                  ReadReviewsRangeResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// ── ReviewSingle (单条想法详情) ──

class ReviewSingleDetail {
  final String reviewId;
  final String content;
  final String? bookId;
  final int? chapterUid;
  final int? createTime;
  final ReadReviewAuthor? author;

  const ReviewSingleDetail({
    required this.reviewId,
    required this.content,
    this.bookId,
    this.chapterUid,
    this.createTime,
    this.author,
  });

  factory ReviewSingleDetail.fromJson(Map<String, dynamic> json) {
    return ReviewSingleDetail(
      reviewId: json['reviewId'] as String,
      content: json['content'] as String? ?? '',
      bookId: json['bookId'] as String?,
      chapterUid: json['chapterUid'] as int?,
      createTime: json['createTime'] as int?,
      author: json['author'] != null
          ? ReadReviewAuthor.fromJson(json['author'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ReviewSingleResponse {
  final String reviewId;
  final int synckey;
  final String? htmlContent;
  final ReviewSingleDetail review;

  const ReviewSingleResponse({
    required this.reviewId,
    required this.synckey,
    this.htmlContent,
    required this.review,
  });

  factory ReviewSingleResponse.fromJson(Map<String, dynamic> json) {
    return ReviewSingleResponse(
      reviewId: json['reviewId'] as String,
      synckey: json['synckey'] as int? ?? 0,
      htmlContent: json['htmlContent'] as String?,
      review:
          ReviewSingleDetail.fromJson(json['review'] as Map<String, dynamic>),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Review — 公开点评
// ═══════════════════════════════════════════════════════════════════

class PublicReviewAuthor {
  final String userVid;
  final String name;
  final String? avatar;

  const PublicReviewAuthor({
    required this.userVid,
    required this.name,
    this.avatar,
  });

  factory PublicReviewAuthor.fromJson(Map<String, dynamic> json) {
    return PublicReviewAuthor(
      userVid: json['userVid']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String?,
    );
  }
}

class PublicReviewBook {
  final String bookId;
  final String? title;
  final String? author;

  const PublicReviewBook({
    required this.bookId,
    this.title,
    this.author,
  });

  factory PublicReviewBook.fromJson(Map<String, dynamic> json) {
    return PublicReviewBook(
      bookId: json['bookId'] as String,
      title: json['title'] as String?,
      author: json['author'] as String?,
    );
  }
}

class PublicReviewDetail {
  final String reviewId;
  final String content;
  final String? htmlContent;
  /// 20/40/60/80/100
  final int? star;
  final int? isFinish;
  final int? createTime;
  final String? chapterName;
  final PublicReviewAuthor author;
  final PublicReviewBook book;

  const PublicReviewDetail({
    required this.reviewId,
    required this.content,
    this.htmlContent,
    this.star,
    this.isFinish,
    this.createTime,
    this.chapterName,
    required this.author,
    required this.book,
  });

  factory PublicReviewDetail.fromJson(Map<String, dynamic> json) {
    return PublicReviewDetail(
      reviewId: json['reviewId']?.toString() ?? '',
      content: json['content'] as String? ?? '',
      htmlContent: json['htmlContent'] as String?,
      star: _asInt(json['star']),
      isFinish: _asInt(json['isFinish']),
      createTime: _asInt(json['createTime']),
      chapterName: json['chapterName'] as String?,
      author: json['author'] != null
          ? PublicReviewAuthor.fromJson(json['author'] as Map<String, dynamic>)
          : const PublicReviewAuthor(userVid: '', name: ''),
      book: json['book'] != null
          ? PublicReviewBook.fromJson(json['book'] as Map<String, dynamic>)
          : const PublicReviewBook(bookId: ''),
    );
  }

  /// 评分格式化：20→1星, 40→2星, …, 100→5星
  int? get starCount => star != null ? star! ~/ 20 : null;
}

class ReviewItem {
  final int idx;
  final PublicReviewDetail review;

  const ReviewItem({required this.idx, required this.review});

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    // 结构: { idx, review: { reviewId, review: { ...detail } } }
    final outer = json['review'] as Map<String, dynamic>;
    return ReviewItem(
      idx: json['idx'] as int,
      review: PublicReviewDetail.fromJson(
          outer['review'] as Map<String, dynamic>),
    );
  }
}

class ReviewListResponse {
  final int synckey;
  final int reviewsCnt;
  final int? recentTotalCnt;
  final int? reviewsHasMore;
  final int? friendCommentCount;
  final List<ReviewItem> reviews;

  const ReviewListResponse({
    required this.synckey,
    required this.reviewsCnt,
    this.recentTotalCnt,
    this.reviewsHasMore,
    this.friendCommentCount,
    required this.reviews,
  });

  factory ReviewListResponse.fromJson(Map<String, dynamic> json) {
    return ReviewListResponse(
      synckey: json['synckey'] as int? ?? 0,
      reviewsCnt: json['reviewsCnt'] as int? ?? 0,
      recentTotalCnt: json['recentTotalCnt'] as int?,
      reviewsHasMore: json['reviewsHasMore'] as int?,
      friendCommentCount: json['friendCommentCount'] as int?,
      reviews: (json['reviews'] as List<dynamic>?)
              ?.map((e) => ReviewItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get hasMore => reviewsHasMore == 1;
}

// ═══════════════════════════════════════════════════════════════════
// Discover — 推荐
// ═══════════════════════════════════════════════════════════════════

class RecommendBook extends WereadBookInfo {
  final String? reason;
  final int? readingCount;
  final int? searchIdx;
  final int? type;

  const RecommendBook({
    required super.bookId,
    required super.title,
    super.author,
    super.cover,
    super.intro,
    super.category,
    super.newRating,
    super.newRatingCount,
    super.newRatingTitle,
    super.payType,
    super.price,
    this.reason,
    this.readingCount,
    this.searchIdx,
    this.type,
  });

  factory RecommendBook.fromJson(Map<String, dynamic> json) {
    final ratingDetail = json['newRatingDetail'] as Map<String, dynamic>?;
    return RecommendBook(
      bookId: json['bookId'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      cover: json['cover'] as String?,
      intro: json['intro'] as String?,
      category: json['category'] as String?,
      newRating: _asInt(json['newRating']),
      newRatingCount: _asInt(json['newRatingCount']),
      newRatingTitle: ratingDetail?['title'] as String?,
      payType: _asInt(json['payType']),
      price: _asInt(json['price']),
      reason: json['reason'] as String?,
      readingCount: _asInt(json['readingCount']),
      searchIdx: _asInt(json['searchIdx']),
      type: _asInt(json['type']),
    );
  }
}

class RecommendResponse {
  final List<RecommendBook> books;

  const RecommendResponse({required this.books});

  factory RecommendResponse.fromJson(Map<String, dynamic> json) {
    return RecommendResponse(
      books: (json['books'] as List<dynamic>?)
              ?.map((e) => RecommendBook.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SimilarBookItem {
  final int idx;
  final WereadBookInfo bookInfo;

  const SimilarBookItem({required this.idx, required this.bookInfo});

  factory SimilarBookItem.fromJson(Map<String, dynamic> json) {
    final book = json['book'] as Map<String, dynamic>;
    return SimilarBookItem(
      idx: json['idx'] as int,
      bookInfo:
          WereadBookInfo.fromJson(book['bookInfo'] as Map<String, dynamic>),
    );
  }
}

class SimilarResponse {
  final String sessionId;
  final List<SimilarBookItem> books;

  const SimilarResponse({required this.sessionId, required this.books});

  factory SimilarResponse.fromJson(Map<String, dynamic> json) {
    final similar = json['booksimilar'] as Map<String, dynamic>;
    return SimilarResponse(
      sessionId: similar['sessionId'] as String? ?? '',
      books: (similar['books'] as List<dynamic>?)
              ?.map(
                  (e) => SimilarBookItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Profile — 用户概况（组合接口）
// ═══════════════════════════════════════════════════════════════════

class ProfileRecentBook {
  final String bookId;
  final String title;
  final BookProgressData progress;

  const ProfileRecentBook({
    required this.bookId,
    required this.title,
    required this.progress,
  });
}

class ProfileSummary {
  final ShelfSyncResponse shelf;
  final int shelfTotal;
  final List<ProfileRecentBook> recent;

  const ProfileSummary({
    required this.shelf,
    required this.shelfTotal,
    required this.recent,
  });
}

// ═══════════════════════════════════════════════════════════════════
// 工具函数
// ═══════════════════════════════════════════════════════════════════

/// 秒 → "X小时Y分钟" 格式化
String _formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0 && minutes > 0) return '$hours小时$minutes分钟';
  if (hours > 0) return '$hours小时';
  if (minutes > 0) return '$minutes分钟';
  return '不到1分钟';
}

/// Unix 时间戳 → DateTime
DateTime? timestampToDateTime(int? timestamp) {
  if (timestamp == null || timestamp == 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
}

/// Unix 时间戳 → "YYYY-MM-DD" 格式化
String? formatTimestamp(int? timestamp) {
  final dt = timestampToDateTime(timestamp);
  if (dt == null) return null;
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

/// 安全地将 JSON 数值（可能是 int 或 double）转为 int
int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

Map<String, int>? _castIntMap(dynamic value) {
  if (value == null) return null;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _asInt(v) ?? 0));
  }
  return null;
}

List<Map<String, dynamic>>? _castMapList(dynamic value) {
  if (value == null) return null;
  if (value is List) {
    return value
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
  return null;
}
