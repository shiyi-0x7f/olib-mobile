import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'weread_api.dart';
import 'weread_models.dart';

/// 推荐池：以书架最近在读的书为种子，拉取 `/book/detailinfo?listtypes=2` 相似书。
///
/// `/book/recommend` 实测 `books` 恒为空，不是推荐接口，不使用
/// （见 OlibTauri `dev_docs/weread-recommend.md`，本类与其 `recommend.rs` 对齐）。
/// 规则：按 bookId 去重、排除书架已有书、多种子轮流交错；某种子一页无新书即耗尽；
/// 全部耗尽后从已展示的书从头轮转。
class WereadRecommendPool {
  // 最近的几本可能都是用户导入的私人书；继续尝试较早的书架书籍。
  static const _maxSeeds = 20;
  static const _activeSources = 3;
  static const _pageSize = 12;

  /// 单个种子最多翻页数，防止服务端异常时无限拉取。
  static const _maxPagesPerSource = 20;

  final List<_Source> _sources;
  final Set<String> _shelfIds;
  final Set<String> _seen = {};
  final List<RecommendBook> _shown = [];
  int _replay = 0;
  int _turn = 0;

  WereadRecommendPool._(this._sources, this._shelfIds);

  factory WereadRecommendPool.fromShelf(ShelfSyncResponse shelf) {
    final shelfIds = shelf.books
        .map((b) => b.bookId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final recent = List<ShelfBook>.from(
      shelf.books,
    )..sort((a, b) => (b.readUpdateTime ?? 0).compareTo(a.readUpdateTime ?? 0));
    final sources = recent
        .where((b) => !b.isSecret && b.bookId.isNotEmpty)
        .take(_maxSeeds)
        .map((b) {
          final title = b.title.trim();
          return _Source(
            b.bookId,
            title.isEmpty ? '与你书架上的书相似' : '因为你在读《$title》',
          );
        })
        .toList();
    return WereadRecommendPool._(sources, shelfIds);
  }

  int get _buffered => _sources.fold(0, (n, s) => n + s.buffer.length);

  /// 缓冲不足 [want] 时，优先从最近的三个未耗尽种子里选缓冲最少者。
  _Source? _fetchTarget(int want) {
    if (_buffered >= want) return null;
    _Source? target;
    for (final source
        in _sources.where((s) => !s.exhausted).take(_activeSources)) {
      if (target == null || source.buffer.length < target.buffer.length) {
        target = source;
      }
    }
    return target;
  }

  void _applyPage(_Source source, SimilarResponse page) {
    source.pages++;
    if (page.sessionId.isNotEmpty) source.sessionId = page.sessionId;
    var newIds = 0;
    for (final item in page.books) {
      source.nextIdx = max(source.nextIdx, item.idx);
      final id = item.bookInfo.bookId;
      if (id.isEmpty || !_seen.add(id)) continue;
      newIds++;
      if (_shelfIds.contains(id) || id == source.seedId) continue;
      source.buffer.add(
        RecommendBook.fromInfo(item.bookInfo, reason: source.reason),
      );
    }
    // 无新书（含服务端忽略游标重复返回）即视为耗尽
    if (newIds == 0 || source.pages >= _maxPagesPerSource) {
      source.exhausted = true;
    }
  }

  RecommendBatch _take(int want) {
    final books = <RecommendBook>[];
    final n = _sources.length;
    var idle = 0;
    while (books.length < want && n > 0 && idle < n) {
      final source = _sources[_turn % n];
      _turn = (_turn + 1) % n;
      if (source.buffer.isEmpty) {
        idle++;
      } else {
        books.add(source.buffer.removeFirst());
        idle = 0;
      }
    }
    _shown.addAll(books);

    final exhausted = _buffered == 0 && _sources.every((s) => s.exhausted);
    var wrapped = false;
    if (books.isEmpty && exhausted && _shown.isNotEmpty) {
      wrapped = true;
      final len = _shown.length;
      final count = min(want, len);
      for (var k = 0; k < count; k++) {
        books.add(_shown[(_replay + k) % len]);
      }
      _replay = (_replay + count) % len;
    }
    return RecommendBatch(
      books: books,
      exhausted: exhausted,
      wrapped: wrapped,
      hasSeeds: n > 0,
    );
  }

  /// 取下一批推荐。单个种子失败只跳过该种子，全部失败且无书可给时才抛错。
  Future<RecommendBatch> next(WereadApi api, int want) async {
    Object? lastError;
    StackTrace? lastStack;
    for (
      var source = _fetchTarget(want);
      source != null;
      source = _fetchTarget(want)
    ) {
      try {
        final page = await api.similar(
          bookId: source.seedId,
          count: _pageSize,
          maxIdx: source.nextIdx,
          sessionId: source.sessionId,
        );
        _applyPage(source, page);
      } catch (e, st) {
        // 单个种子失败（如导入的私人书无相似书）不拖垮整体，其余种子继续
        debugPrint('WeRead similar books failed, skipping seed: $e');
        source.exhausted = true;
        lastError = e;
        lastStack = st;
      }
    }
    final batch = _take(want);
    if (lastError != null && batch.books.isEmpty) {
      Error.throwWithStackTrace(lastError, lastStack!);
    }
    return batch;
  }
}

class RecommendBatch {
  final List<RecommendBook> books;

  /// 所有种子都已拉完且没有待展示的新书
  final bool exhausted;

  /// 本批来自已展示过的书（新书已看完，从头轮转）
  final bool wrapped;

  /// 书架里是否有可作为种子的书
  final bool hasSeeds;

  const RecommendBatch({
    required this.books,
    required this.exhausted,
    required this.wrapped,
    required this.hasSeeds,
  });
}

class _Source {
  final String seedId;
  final String reason;
  String? sessionId;
  int nextIdx = 0;
  int pages = 0;
  bool exhausted = false;
  final Queue<RecommendBook> buffer = Queue();

  _Source(this.seedId, this.reason);
}
