import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:olib_mobile/models/display_book.dart';
import 'package:olib_mobile/services/weread/weread_models.dart';
import 'package:olib_mobile/widgets/book_card.dart';
import 'package:olib_mobile/widgets/book_list_tile.dart';

void main() {
  const searchCover =
      'https://cdn.weread.qq.com/weread/cover/80/yuewen_695233/s_yuewen_6952331740758482.jpg';
  const detailCover =
      'https://cdn.weread.qq.com/weread/cover/80/yuewen_695233/t6_yuewen_6952331740758482.jpg';
  const title = '一本很长很长的微信读书搜索结果书名';
  const author = '一位名字很长的作者';
  const result = SearchResultBook(
    searchIdx: 1,
    bookInfo: WereadBookInfo(
      bookId: 'weread-search-book',
      title: title,
      author: author,
      category: '文学',
      newRating: 93,
    ),
  );

  test('WeRead search uses the detail-quality cover variant', () {
    const coveredResult = SearchResultBook(
      searchIdx: 1,
      bookInfo: WereadBookInfo(
        bookId: '695233',
        title: title,
        cover: searchCover,
      ),
    );
    expect(coveredResult.toDisplay().cover, detailCover);
    expect(result.toDisplay().cover, isNull);
    const otherCdnResult = SearchResultBook(
      searchIdx: 2,
      bookInfo: WereadBookInfo(
        bookId: 'other-cover',
        title: '其他封面',
        cover: 'https://example.com/cover/s_sample.jpg',
      ),
    );
    expect(
      otherCdnResult.toDisplay().cover,
      'https://example.com/cover/s_sample.jpg',
    );
  });

  testWidgets('WeRead search grid keeps details and shows one rating', (
    tester,
  ) async {
    final book = result.toDisplay(priceLabel: '免费', showReadingCount: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 158,
              height: 264,
              child: BookCard(book: book, searchResult: true),
            ),
          ),
        ),
      ),
    );

    expect(find.text(title), findsOneWidget);
    expect(find.text(author), findsOneWidget);
    expect(
      tester.getRect(find.text(title)).bottom,
      lessThanOrEqualTo(tester.getRect(find.text(author)).top),
    );
    expect(find.text('文学'), findsOneWidget);
    expect(find.text('免费'), findsOneWidget);
    expect(find.text('9.3'), findsOneWidget);
    expect(find.textContaining('⭐'), findsNothing);
    expect(
      tester.getRect(find.text('9.3')).bottom,
      lessThan(tester.getRect(find.text('免费')).top),
    );
    expect(
      tester.getRect(find.text('免费')).bottom,
      lessThan(tester.getRect(find.text(title)).top),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Z-Library file size sits below the cover rating', (
    tester,
  ) async {
    const book = DisplayBook(
      id: 'zlibrary-search-book',
      title: '一本测试书',
      author: '测试作者',
      score: '8.4',
      meta: '12 MB',
      source: BookSource.zlibrary,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 158,
              height: 264,
              child: BookCard(book: book, searchResult: true),
            ),
          ),
        ),
      ),
    );

    expect(find.text('8.4'), findsOneWidget);
    expect(find.text('12 MB'), findsOneWidget);
    expect(
      tester.getRect(find.text('8.4')).bottom,
      lessThan(tester.getRect(find.text('12 MB')).top),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('WeRead search list keeps details and shows one rating', (
    tester,
  ) async {
    const coveredResult = SearchResultBook(
      searchIdx: 1,
      bookInfo: WereadBookInfo(
        bookId: '695233',
        title: title,
        author: author,
        category: '文学',
        newRating: 93,
        cover: searchCover,
      ),
    );
    final book = coveredResult.toDisplay(
      priceLabel: '免费',
      showReadingCount: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: BookListTile(book: book, showCover: true),
            ),
          ),
        ),
      ),
    );

    expect(find.text(title), findsOneWidget);
    expect(find.text(author), findsOneWidget);
    expect(find.text('文学'), findsOneWidget);
    expect(find.text('免费'), findsOneWidget);
    expect(find.text('9.3'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(
      tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .imageUrl,
      detailCover,
    );
    expect(tester.takeException(), isNull);
  });
}
