import 'package:flutter/material.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routes/app_routes.dart';
import '../../similar/similar_books_screen.dart';

class BookInfoSection extends StatelessWidget {
  final Book book;
  final bool isDark;

  const BookInfoSection({
    super.key,
    required this.book,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SliverToBoxAdapter(
      child: Transform.translate(
        offset: const Offset(0, -32),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Series / Subtitle ──
              if (book.series != null && book.series!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    book.series!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              // ── Main Title ──
              Text(
                book.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 10),

              // ── Author ──
              if (book.author != null && book.author!.isNotEmpty)
                Text(
                  book.author!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

              const SizedBox(height: 20),

              // ── Metadata Capsules ──
              _buildMetadataCapsules(context),

              // ── Description ──
              if (book.description != null && book.description!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  l10n.get('description'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  book.description!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              // ── Similar Books Entry Card ──
              if (book.hash != null && book.hash!.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSimilarBooksCard(context, l10n),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataCapsules(BuildContext context) {
    final capsules = <Widget>[];

    // Format
    if (book.extension != null && book.extension!.isNotEmpty) {
      capsules.add(_capsule(
        context,
        Icons.description_outlined,
        book.extension!.toUpperCase(),
        highlight: true,
      ));
    }

    // File size
    if (book.filesizeString != null && book.filesizeString!.isNotEmpty) {
      capsules.add(_capsule(context, Icons.storage_outlined, book.filesizeString!));
    }

    // Year
    if (book.year != null && book.year != 0) {
      capsules.add(_capsule(context, Icons.calendar_today_outlined, '${book.year}'));
    }

    // Publisher
    if (book.publisher != null && book.publisher!.isNotEmpty) {
      capsules.add(_capsule(context, Icons.business_outlined, book.publisher!));
    }

    // Pages — hide if 0 or null
    if (book.pages != null && book.pages != 0) {
      capsules.add(_capsule(context, Icons.auto_stories_outlined, '${book.pages} p'));
    }

    // Language tag
    if (book.language != null && book.language!.isNotEmpty) {
      capsules.add(_languageTag(book.language!));
    }

    if (capsules.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: capsules,
    );
  }

  Widget _capsule(BuildContext context, IconData icon, String text, {bool highlight = false}) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = highlight
        ? AppColors.primary.withValues(alpha: 0.12)
        : cs.surfaceContainerHighest;
    final fgColor = highlight ? AppColors.primary : cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                color: fgColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageTag(String language) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        language,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.info,
        ),
      ),
    );
  }

  Widget _buildSimilarBooksCard(BuildContext context, AppLocalizations l10n) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).pushNamed(
          AppRoutes.similarBooks,
          arguments: SimilarBooksArgs(
            bookId: book.id,
            hashId: book.hash!,
            bookTitle: book.title,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.get('similar_books'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDark ? 'Discover more like this' : '发现更多类似书籍',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
