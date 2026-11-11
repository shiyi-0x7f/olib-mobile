import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import 'package:olib_mobile/l10n/app_localizations.dart';
import 'package:olib_mobile/models/display_book.dart';
import 'package:olib_mobile/providers/download_provider.dart';
import 'package:olib_mobile/screens/book_detail/widgets/book_action_bar.dart';
import 'package:olib_mobile/screens/book_detail/widgets/book_detail_content.dart';
import 'package:olib_mobile/screens/book_detail/widgets/book_hero_section.dart';
import 'package:olib_mobile/screens/book_detail/widgets/book_info_section.dart';
import 'package:olib_mobile/screens/weread/widgets/weread_info_section.dart';
import 'package:olib_mobile/services/weread/weread_models.dart';

Widget app(Widget body, {Brightness brightness = Brightness.light,
  double scale = 1, Widget? actionBar}) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    supportedLocales: supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(brightness: brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: body, bottomNavigationBar: actionBar),
  ),
);

void main() {
  final longText = List.filled(20, 'A long introduction that needs more than six lines.').join('\n');
  const book = Book(id: 7, title: 'A very long title to verify wrapping on a narrow phone',
    author: 'An author with a long name', publisher: 'A publishing house with a long name',
    pages: 300, language: 'English', year: 2026, extension: 'epub',
    filesizeString: '12 MB', hash: 'sample', readOnlineUrl: 'https://example.com/read');
  const wereadBook = WereadBookInfo(bookId: '7',
    title: 'A very long title to verify wrapping on a narrow phone',
    author: 'An author with a long name', category: 'A very long category name',
    publisher: 'A publishing house with a long name', isbn: '9781234567890',
    newRating: 98, newRatingCount: 123456789);

  testWidgets('short description needs no expansion control', (tester) async {
    await tester.pumpWidget(app(const BookDetailDescription(text: 'Short introduction.')));
    await tester.pumpAndSettle();
    expect(find.text('Short introduction.'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('description expands, collapses, and resets for another book', (tester) async {
    Widget description(String text) => app(SingleChildScrollView(
      child: BookDetailDescription(key: const ValueKey('description'), text: text)));
    await tester.pumpWidget(description(longText));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(longText)).maxLines, 6);
    await tester.tap(find.text('Read More'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(longText)).maxLines, isNull);
    await tester.ensureVisible(find.text('Show Less'));
    await tester.tap(find.text('Show Less'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(longText)).maxLines, 6);
    await tester.ensureVisible(find.text('Read More'));
    await tester.tap(find.text('Read More'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(description('$longText\nNew book.'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('$longText\nNew book.')).maxLines, 6);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('both detail layouts fit a narrow phone: $brightness, $scale', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final section in [
          BookInfoSection(book: book.copyWith(description: longText)),
          WereadInfoSection(bookInfo: wereadBook, isDark: brightness == Brightness.dark),
        ]) {
          await tester.pumpWidget(app(CustomScrollView(slivers: [section]),
            brightness: brightness, scale: scale));
          await tester.pumpAndSettle();
          expect(find.text(book.title), findsOneWidget);
          expect(find.text(book.author!), findsOneWidget);
          await tester.ensureVisible(find.text('Publication Details'));
          await tester.pumpAndSettle();
          expect(find.text(book.publisher!), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('hero reveals the toolbar title after scrolling', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(CustomScrollView(controller: controller, slivers: const [
      BookHeroSection(book: DisplayBook(id: '7', title: 'Scroll title', source: BookSource.weread),
        isDark: false, isFavorited: false),
      SliverToBoxAdapter(child: SizedBox(height: 1500)),
    ])));
    await tester.pumpAndSettle();
    Finder opacity() => find.ancestor(of: find.text('Scroll title'), matching: find.byType(AnimatedOpacity));
    expect(tester.widget<AnimatedOpacity>(opacity()).opacity, 0);
    controller.jumpTo(300);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(opacity()).opacity, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('WeRead chapters retain expand and collapse', (tester) async {
    final chapters = ChapterInfoResponse(bookId: '7', synckey: 0,
      chapters: List.generate(8, (i) => ChapterInfo(chapterUid: i, chapterIdx: i, title: 'Chapter $i')));
    final t = AppLocalizations(const Locale('en'));
    final expandLabel = '${t.get('weread_view_all')} (8)';
    await tester.pumpWidget(app(CustomScrollView(slivers: [
      WereadInfoSection(bookInfo: const WereadBookInfo(bookId: '7', title: 'Book'),
        chapters: chapters, isDark: false),
    ])));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 7'), findsNothing);
    await tester.ensureVisible(find.text(expandLabel));
    await tester.tap(find.text(expandLabel));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 7'), findsOneWidget);
    await tester.ensureVisible(find.text(t.get('weread_show_less')));
    await tester.tap(find.text(t.get('weread_show_less')));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 7'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('action bar fits large text and disables an active download', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const SizedBox(), scale: 2,
      actionBar: const BookActionBar(book: book,
        downloadTask: DownloadTask(id: '7', book: book, progress: .42,
          status: DownloadStatus.downloading), isDownloading: true, isCompleted: false)));
    await tester.pumpAndSettle();
    expect(find.text('42%'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNull);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
