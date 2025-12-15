import 'package:flutter/material.dart';
import '../models/book.dart';
import '../theme/app_colors.dart';

/// Simplified list tile for books - compact view without cover images
class BookListTile extends StatelessWidget {
  final Book book;
  final VoidCallback? onTap;

  const BookListTile({
    super.key,
    required this.book,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        title: Text(
          book.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.author != null && book.author!.isNotEmpty)
              Text(
                book.author!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                // Extension badge
                if (book.extension != null && book.extension!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      book.extension!.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (book.extension != null && book.filesizeString != null)
                  const SizedBox(width: 8),
                // File size
                if (book.filesizeString != null)
                  Text(
                    book.filesizeString!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                const Spacer(),
                // Year
                if (book.year != null && book.year != 0)
                  Text(
                    '${book.year}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
