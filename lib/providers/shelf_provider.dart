import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../models/display_book.dart';
import '../models/unified_shelf_item.dart';
import '../services/weread/weread_models.dart';
import 'books_provider.dart';
import 'weread_provider.dart';

/// 书架来源筛选状态
final shelfFilterProvider = StateProvider<ShelfSource?>((ref) => null);

/// 统一书架 — 合并 z站收藏和微信读书书架，分组显示
final unifiedShelfProvider = Provider<AsyncValue<List<UnifiedShelfItem>>>((
  ref,
) {
  final zlibAsync = ref.watch(savedBooksProvider);
  final wereadAsync = ref.watch(wereadShelfProvider);

  // Always retain both sources so counts and local category filters stay stable.
  if (zlibAsync is AsyncLoading && wereadAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }

  final items = <UnifiedShelfItem>[];

  // WeRead 组排前面
  final wereadData = wereadAsync.valueOrNull;
  if (wereadData != null) {
    items.addAll(wereadData.books.map((b) => _fromWeread(b)));
  }

  // ZLibrary 组排后面
  final zlibData = zlibAsync.valueOrNull;
  if (zlibData != null) {
    items.addAll(zlibData.map((b) => _fromZLib(b)));
  }

  return AsyncValue.data(items);
});

UnifiedShelfItem _fromWeread(ShelfBook book) {
  return UnifiedShelfItem(
    source: ShelfSource.weread,
    displayBook: book.toDisplay(),
    rawBookId: book.bookId,
    lastReadTime: book.readUpdateTime,
    isPersonalImport: book.bookId.startsWith('CB_'),
    deepLink: book.deepLink,
  );
}

UnifiedShelfItem _fromZLib(Book book) {
  return UnifiedShelfItem(
    source: ShelfSource.library,
    displayBook: book.toDisplay(),
    rawBookId: book.id.toString(),
    lastReadTime: null,
  );
}
