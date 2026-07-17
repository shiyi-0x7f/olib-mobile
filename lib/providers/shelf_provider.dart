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
final unifiedShelfProvider =
    Provider<AsyncValue<List<UnifiedShelfItem>>>((ref) {
  final filter = ref.watch(shelfFilterProvider);
  final zlibAsync = ref.watch(savedBooksProvider);
  final wereadAsync = ref.watch(wereadShelfProvider);

  // 如果正在筛选某个来源，只等待该来源的数据
  if (filter == ShelfSource.library) {
    return zlibAsync.whenData((books) =>
        books.map((b) => _fromZLib(b)).toList());
  }
  if (filter == ShelfSource.weread) {
    return wereadAsync.whenData((shelf) {
      if (shelf == null) return <UnifiedShelfItem>[];
      return shelf.books.map((b) => _fromWeread(b)).toList();
    });
  }

  // 全部：两个来源都加载完才显示
  if (zlibAsync is AsyncLoading || wereadAsync is AsyncLoading) {
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
    // 非上传书（不是 CB_ 开头）视为正版
    isPurchased: !book.bookId.startsWith('CB_'),
  );
}

UnifiedShelfItem _fromZLib(Book book) {
  return UnifiedShelfItem(
    source: ShelfSource.library,
    displayBook: book.toDisplay(),
    rawBookId: book.id.toString(),
    lastReadTime: null,
    isPurchased: false,
  );
}
