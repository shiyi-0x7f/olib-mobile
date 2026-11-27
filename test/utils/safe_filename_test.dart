import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:olib_mobile/utils/safe_filename.dart';

void main() {
  group('sanitizeFileStem', () {
    test('keeps normal title', () {
      expect(sanitizeFileStem('三体'), '三体');
      expect(sanitizeFileStem('Clean Code'), 'Clean Code');
    });

    test('replaces invalid chars and collapses whitespace', () {
      expect(sanitizeFileStem('A/B: C?  *D*\n\tE'), 'A B C D E');
    });

    test('strips invisible chars', () {
      expect(sanitizeFileStem('\uFEFFPy\u200Bthon\u202E'), 'Python');
    });

    test('trims leading/trailing dots and spaces', () {
      expect(sanitizeFileStem('  Title...  '), 'Title');
      expect(sanitizeFileStem('...hidden'), 'hidden');
    });

    test('truncates long ascii title', () {
      final stem = sanitizeFileStem(
        "Harry Potter and the Sorcerer's Stone; " * 20,
      );
      expect(stem.runes.length, lessThanOrEqualTo(100));
      expect(
        stem.endsWith(' ') || stem.endsWith(';') || stem.endsWith('.'),
        isFalse,
      );
    });

    test('truncates long CJK title by bytes', () {
      final stem = sanitizeFileStem('这是一个非常长的中文书名' * 30);
      expect(utf8.encode(stem).length, lessThanOrEqualTo(180));
      expect(stem, isNotEmpty);
    });

    test('does not split surrogate pairs', () {
      final stem = sanitizeFileStem('😀' * 200);
      expect(() => utf8.encode(stem), returnsNormally);
      expect(stem.runes.every((r) => r == 0x1F600), isTrue);
    });

    test('handles reserved and empty names', () {
      expect(sanitizeFileStem('con'), '_con');
      expect(sanitizeFileStem('NUL.tar'), '_NUL.tar');
      expect(sanitizeFileStem('???'), '');
      expect(sanitizeFileStem(''), '');
    });
  });

  test('sanitizeExtension', () {
    expect(sanitizeExtension('.E/PUB'), 'epub');
    expect(sanitizeExtension(''), '');
  });
}
