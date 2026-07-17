import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/display_book.dart';
import '../../../providers/books_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class BookHeroSection extends ConsumerWidget {
  final DisplayBook book;
  final bool isDark;
  final bool isFavorited;

  const BookHeroSection({
    super.key,
    required this.book,
    required this.isDark,
    required this.isFavorited,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black26,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      actions: [
        // ── Favorite Heart Icon (only for z站 books) ──
        if (book.isZLibrary)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black26,
              child: IconButton(
                icon: Icon(
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: isFavorited ? Colors.redAccent : Colors.white,
                  size: 20,
                ),
                onPressed: () async {
                  final bookId = book.id;
                  if (isFavorited) {
                    await ref.read(savedBooksProvider.notifier).unsaveBook(bookId);
                  } else {
                    await ref.read(savedBooksProvider.notifier).saveBook(bookId);
                  }
                  // Refresh the favorite state
                  ref.invalidate(isBookFavoritedProvider(bookId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isFavorited ? '已取消收藏' : AppLocalizations.of(context).get('like')),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // ── Layer 1: Blurred Cover Background ──
            if (book.cover != null)
              CachedNetworkImage(
                imageUrl: book.cover!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              )
            else
              Container(color: AppColors.primary.withValues(alpha: 0.3)),

            // ── Layer 2: Blur Filter ──
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(color: Colors.transparent),
              ),
            ),

            // ── Layer 3: Gradient Overlay ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.2),
                    (isDark ? const Color(0xFF121212) : AppColors.background).withValues(alpha: 0.8),
                    isDark ? const Color(0xFF121212) : AppColors.background,
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),

            // ── Layer 4: 3D Book Cover ──
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 48, bottom: 32),
                child: _build3DBookCover(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build3DBookCover() {
    return Container(
      height: 220,
      width: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(8, 12),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: book.cover != null
            ? CachedNetworkImage(
                imageUrl: book.cover!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _buildCoverPlaceholder(),
              )
            : _buildCoverPlaceholder(),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.15),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_rounded, size: 40, color: AppColors.primary),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                book.title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
