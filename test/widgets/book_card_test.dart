import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olib_mobile/models/display_book.dart';
import 'package:olib_mobile/widgets/book_card.dart';

void main() {
  const book = DisplayBook(
    id: 'test-book',
    title: '这是一本书名很长的推荐书籍 A very long recommended book title',
    author: '名字很长的作者 A very long author name',
    score: '9.8',
    meta: '123456789 人正在阅读这本书',
    tag: '文学',
    tagExtra: '2026',
    source: BookSource.weread,
  );

  for (final brightness in Brightness.values) {
    for (final width in [132.0, 172.0, 216.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('compact card: $brightness, width $width, scale $scale', (
          tester,
        ) async {
          final scaler = TextScaler.linear(scale);
          final semantics = tester.ensureSemantics();
          try {
            var tapped = false;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: scaler),
                  child: child!,
                ),
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: width,
                      height: BookCard.compactHeightFor(width),
                      child: BookCard(
                        book: book,
                        compact: true,
                        onTap: () => tapped = true,
                      ),
                    ),
                  ),
                ),
              ),
            );
            expect(tester.takeException(), isNull);
            expect(find.text(book.title), findsNothing);
            expect(find.text(book.author!), findsNothing);
            expect(find.text(book.score!), findsNothing);
            expect(
              find.bySemanticsLabel(RegExp(RegExp.escape(book.title))),
              findsOneWidget,
            );
            expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
            expect(find.text(book.tag!), findsNothing);
            await tester.tap(find.byType(BookCard));
            await tester.pumpAndSettle();
            expect(tapped, isTrue);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        });
      }
    }
  }

  testWidgets('compact card handles missing optional details', (tester) async {
    const sparseBook = DisplayBook(
      id: 'sparse',
      title: '只有书名',
      source: BookSource.weread,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 132,
            height: BookCard.compactHeightFor(132),
            child: const BookCard(book: sparseBook, compact: true),
          ),
        ),
      ),
    );
    expect(find.text(sparseBook.title), findsNothing);
    expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('default card still displays category and extra details', (
    tester,
  ) async {
    const defaultBook = DisplayBook(
      id: 'default',
      title: '默认卡片',
      author: '作者',
      tag: '文学',
      tagExtra: '2026',
      score: '9.8',
      meta: '123 人在读',
      source: BookSource.weread,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 172,
            height: 300,
            child: BookCard(book: defaultBook),
          ),
        ),
      ),
    );
    expect(find.text(defaultBook.tag!), findsOneWidget);
    expect(find.text('• ${defaultBook.tagExtra}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
