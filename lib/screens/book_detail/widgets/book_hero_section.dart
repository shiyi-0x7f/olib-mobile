import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../models/display_book.dart';
import '../../../providers/books_provider.dart';
import '../../../l10n/app_localizations.dart';
import 'book_3d_cover.dart';

class BookHeroSection extends ConsumerStatefulWidget {
  final DisplayBook book;
  final bool isFavorited;

  const BookHeroSection({
    super.key,
    required this.book,
    required this.isFavorited,
  });

  @override
  ConsumerState<BookHeroSection> createState() => _BookHeroSectionState();
}

class _BookHeroSectionState extends ConsumerState<BookHeroSection> {
  bool _saving = false;

  Future<void> _toggleFavorite() async {
    if (_saving) return;
    setState(() => _saving = true);
    final wasFavorited = widget.isFavorited;
    final bookId = widget.book.id;
    try {
      final notifier = ref.read(savedBooksProvider.notifier);
      final success = wasFavorited
          ? await notifier.unsaveBook(bookId)
          : await notifier.saveBook(bookId);
      if (!mounted) return;
      if (success) ref.invalidate(isBookFavoritedProvider(bookId));
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.get(
              !success
                  ? 'favorite_failed'
                  : wasFavorited
                  ? 'favorite_removed'
                  : 'like',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final height = (MediaQuery.sizeOf(context).height * 0.54).clamp(
      340.0,
      420.0,
    );
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final collapsed =
            constraints.scrollOffset >= height - kToolbarHeight - 8;
        return SliverAppBar(
          expandedHeight: height,
          pinned: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: !collapsed
              ? const Color(0xFF0D1723)
              : theme.scaffoldBackgroundColor,
          foregroundColor: collapsed ? cs.onSurface : Colors.white,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: AnimatedOpacity(
            opacity: collapsed ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Text(
              widget.book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          actions: [
            if (widget.book.isZLibrary)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: l10n.get(
                    widget.isFavorited ? 'remove_favorite' : 'like',
                  ),
                  onPressed: _saving ? null : _toggleFavorite,
                  icon: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: collapsed ? cs.primary : Colors.white,
                          ),
                        )
                      : Icon(
                          widget.isFavorited
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: collapsed
                              ? (widget.isFavorited ? cs.primary : cs.onSurface)
                              : (widget.isFavorited
                                    ? const Color(0xFFFFA6B7)
                                    : Colors.white),
                          size: 22,
                        ),
                ),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildCover(context, height, animate: !collapsed),
          ),
        );
      },
    );
  }

  Widget _buildCover(
    BuildContext context,
    double height, {
    required bool animate,
  }) {
    Widget content({ImageProvider? image, bool loading = false}) {
      final theme = Theme.of(context);
      final background = theme.scaffoldBackgroundColor;
      return Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [Color(0xFF203A4B), Color(0xFF0D1723)],
              ),
            ),
          ),
          if (image != null)
            Opacity(
              opacity: 0.10,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Image(
                  image: image,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0D1723).withValues(alpha: 0.20),
                  const Color(0xFF0D1723).withValues(alpha: 0.72),
                  background,
                ],
                stops: const [0, 0.82, 1],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
              bottom: 16,
            ),
            child: Center(
              child: Book3DCover(
                cover: image,
                title: widget.book.title,
                loading: loading,
                animate: animate && !MediaQuery.of(context).disableAnimations,
                height:
                    (height -
                            MediaQuery.paddingOf(context).top -
                            kToolbarHeight -
                            58)
                        .clamp(170.0, 295.0),
              ),
            ),
          ),
        ],
      );
    }

    final cover = widget.book.cover;
    if (cover == null || cover.isEmpty) return content();
    return CachedNetworkImage(
      imageUrl: cover,
      memCacheWidth:
          ((height - kToolbarHeight) *
                  0.7 *
                  MediaQuery.devicePixelRatioOf(context))
              .ceil()
              .clamp(400, 900),
      imageBuilder: (context, image) => content(image: image),
      placeholder: (context, url) => content(loading: true),
      errorWidget: (context, url, error) => content(),
    );
  }
}
