import 'package:flutter/material.dart';
import '../models/display_book.dart';

/// 纯封面书架：完整封面、小圆角和很薄的背景留白。
class BookCoverBackdrop extends StatelessWidget {
  final ImageProvider? image;
  final Widget placeholder;
  final DisplayBook book;
  final String? sourceLabel;

  const BookCoverBackdrop({
    super.key,
    this.image,
    required this.placeholder,
    required this.book,
    this.sourceLabel,
  });

  static const _padding = 4.0;
  static const _coverAspectRatio = 0.7;

  static double heightFor(double width) =>
      (width - _padding * 2).clamp(0.0, double.infinity) / _coverAspectRatio +
      _padding * 2;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final author = book.author;
    return Semantics(
      label: [
        if (sourceLabel != null) sourceLabel!,
        book.title,
        if (author != null && author.isNotEmpty) author,
      ].join(', '),
      excludeSemantics: true,
      child: ColoredBox(
        color: cs.primary.withValues(alpha: 0.035),
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: image == null
                ? placeholder
                : Image(image: image!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
