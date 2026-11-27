import 'package:flutter_test/flutter_test.dart';
import 'package:olib_mobile/models/book_comment.dart';

Map<String, dynamic> _c(int id, int? parent, [String text = 't']) => {
  'id': id,
  'parent_id': parent,
  'text': text,
  'user': {'name': 'u$id'},
};

void main() {
  test('groups replies, including nested replies, under the root', () {
    final r = BookCommentsResult.fromJson({
      'comments': [_c(1, null), _c(2, 1), _c(3, 2), _c(4, null)],
    });
    expect(r.total, 4);
    expect(r.threads.map((t) => t.comment.id), [1, 4]);
    expect(r.threads.first.replies.map((c) => c.id), [2, 3]);
  });

  test('orphan reply is shown as top-level', () {
    final r = BookCommentsResult.fromJson({
      'comments': [_c(5, 99)],
    });
    expect(r.threads.single.comment.id, 5);
  });

  test('parent cycle does not drop comments', () {
    final r = BookCommentsResult.fromJson({
      'comments': [_c(1, 2), _c(2, 1)],
    });
    final shown = r.threads.expand((t) => [t.comment, ...t.replies]);
    expect(shown.map((c) => c.id).toSet(), {1, 2});
  });

  test('empty object and disabled flag', () {
    final r = BookCommentsResult.fromJson({
      'comments': <String, dynamic>{},
      'commentsDisabled': true,
    });
    expect(r.threads, isEmpty);
    expect(r.disabled, isTrue);
  });

  test('string ids and trimmed text are parsed', () {
    final r = BookCommentsResult.fromJson({
      'comments': [
        {'id': '7', 'parent_id': null, 'text': '  hi \n'},
      ],
    });
    expect(r.threads.single.comment.id, 7);
    expect(r.threads.single.comment.text, 'hi');
  });
}
