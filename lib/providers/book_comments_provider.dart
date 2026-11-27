import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book_comment.dart';
import 'zlibrary_provider.dart';

/// 书籍读者评论（只读、无需登录）。key 为书籍 id。
final bookCommentsProvider = FutureProvider.autoDispose
    .family<BookCommentsResult, int>((ref, bookId) async {
      final api = ref.watch(zlibraryApiProvider);
      final raw = await api.getBookComments(bookId.toString());
      if (raw['success'] == false || raw['success'] == 0) {
        throw StateError(raw['error']?.toString() ?? 'Failed to load comments');
      }
      return BookCommentsResult.fromJson(raw);
    });
