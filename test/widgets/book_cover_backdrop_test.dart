import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olib_mobile/models/display_book.dart';
import 'package:olib_mobile/theme/app_theme.dart';
import 'package:olib_mobile/widgets/book_cover_backdrop.dart';

void main() {
  const book = DisplayBook(
    id: 'cover-test',
    title: '书籍名称',
    author: '作者',
    source: BookSource.weread,
  );

  for (final dark in [false, true]) {
    testWidgets('loaded shelf cover in ${dark ? 'dark' : 'light'} theme', (
      tester,
    ) async {
      final bytes = await tester.runAsync(_sampleCover);
      final image = MemoryImage(bytes!);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: Scaffold(
            body: SizedBox(
              width: 172,
              height: BookCoverBackdrop.heightFor(172),
              child: BookCoverBackdrop(
                book: book,
                image: image,
                placeholder: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(image, tester.element(find.byType(Scaffold))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.text(book.title), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

/// 仅生成内存中的测试图片，不导出截图。
Future<Uint8List> _sampleCover() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 210, 300),
    Paint()..color = const Color(0xFF558F9E),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(210, 300);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}
