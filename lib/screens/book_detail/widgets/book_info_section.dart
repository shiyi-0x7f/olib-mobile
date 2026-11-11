import 'package:flutter/material.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';

import '../../../models/display_book.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routes/app_routes.dart';
import '../../similar/similar_books_screen.dart';
import 'book_detail_content.dart';

class BookInfoSection extends StatelessWidget {
  final Book book;

  const BookInfoSection({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tags = <Widget>[
      if (book.extension?.isNotEmpty ?? false)
        BookDetailTag(
          icon: Icons.description_outlined,
          text: book.extension!.toUpperCase(),
          highlight: true,
        ),
      if (book.filesizeString?.isNotEmpty ?? false)
        BookDetailTag(icon: Icons.storage_outlined, text: book.filesizeString!),
      if (book.year != null && book.year != 0)
        BookDetailTag(
          icon: Icons.calendar_today_outlined,
          text: '${book.year}',
        ),
    ];
    final fields = <String, String>{
      if (book.publisher?.isNotEmpty ?? false)
        l10n.get('publisher'): book.publisher!,
      if (book.pages != null && book.pages != 0)
        l10n.get('pages'): '${book.pages}',
      if (book.language?.isNotEmpty ?? false)
        l10n.get('language'): book.language!,
    };

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookDetailHeading(book: book.toDisplay(), subtitle: book.series),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: tags),
            ],
            if (book.description?.isNotEmpty ?? false) ...[
              const SizedBox(height: 28),
              BookDetailDescription(text: book.description!),
            ],
            if (fields.isNotEmpty) ...[
              const SizedBox(height: 28),
              BookPublicationInfo(fields: fields),
            ],
            if (book.hash?.isNotEmpty ?? false) ...[
              const SizedBox(height: 24),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.auto_stories_outlined,
                  color: cs.primary,
                  size: 22,
                ),
                title: Text(
                  l10n.get('similar_books'),
                  style: const TextStyle(fontSize: 15),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.similarBooks,
                  arguments: SimilarBooksArgs(
                    bookId: book.id,
                    hashId: book.hash!,
                    bookTitle: book.title,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
