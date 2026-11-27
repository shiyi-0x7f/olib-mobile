/// 书籍读者评论（只读，来源 `/papi/comments/book/{id}/{offset}`）。
///
/// 接口把顶层评论与回复混在同一个 `comments` 列表里，以 `parent_id` 区分；
/// 无评论时 `comments` 可能是空对象而非数组。
library;

class BookComment {
  final int id;
  final int? parentId;
  final String text;
  final String? date;
  final String? userName;
  final String? userAvatar;

  const BookComment({
    required this.id,
    required this.parentId,
    required this.text,
    this.date,
    this.userName,
    this.userAvatar,
  });

  static BookComment? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = _toInt(raw['id']);
    if (id == null) return null;
    final user = raw['user'];
    return BookComment(
      id: id,
      parentId: _toInt(raw['parent_id']),
      text: (raw['text'] ?? '').toString().trim(),
      date: raw['date']?.toString(),
      userName: user is Map ? user['name']?.toString() : null,
      userAvatar: user is Map ? user['avatar']?.toString() : null,
    );
  }

  static int? _toInt(Object? v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// 一条顶层评论及其下所有回复（含回复的回复，按原顺序拍平）
class BookCommentThread {
  final BookComment comment;
  final List<BookComment> replies;

  const BookCommentThread(this.comment, this.replies);
}

/// 评论接口结果
class BookCommentsResult {
  final List<BookCommentThread> threads;
  final int total;
  final bool disabled;

  const BookCommentsResult({
    required this.threads,
    required this.total,
    required this.disabled,
  });

  factory BookCommentsResult.fromJson(Map<String, dynamic> json) {
    final raw = json['comments'];
    final Iterable<Object?> items = raw is List
        ? raw
        : raw is Map
        ? raw.values
        : const [];
    final list = items
        .map(BookComment.tryParse)
        .whereType<BookComment>()
        .toList();
    return BookCommentsResult(
      threads: buildThreads(list),
      total: list.length,
      disabled: json['commentsDisabled'] == true,
    );
  }

  /// 按 parent_id 组装楼中楼：回复沿父链挂到最顶层祖先下；
  /// 父评论不在列表中的回复当作顶层显示，避免丢评论。
  static List<BookCommentThread> buildThreads(List<BookComment> list) {
    final byId = {for (final c in list) c.id: c};

    int rootOf(BookComment c) {
      var cur = c;
      final seen = <int>{cur.id};
      while (true) {
        final parent = cur.parentId == null ? null : byId[cur.parentId];
        if (parent == null || !seen.add(parent.id)) return cur.id;
        cur = parent;
      }
    }

    final threads = <int, BookCommentThread>{};
    for (final c in list) {
      final root = rootOf(c);
      if (root == c.id) {
        threads.putIfAbsent(c.id, () => BookCommentThread(c, []));
      }
    }
    for (final c in list) {
      final root = rootOf(c);
      if (root == c.id) continue;
      final thread = threads[root];
      if (thread != null) {
        thread.replies.add(c);
      } else {
        // 异常数据（父链成环）兜底：单独成楼，不丢
        threads[c.id] = BookCommentThread(c, []);
      }
    }
    return threads.values.toList();
  }
}
