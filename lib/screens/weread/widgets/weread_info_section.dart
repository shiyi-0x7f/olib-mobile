import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/weread/weread_models.dart';
import '../../../models/display_book.dart';
import '../../book_detail/widgets/book_detail_content.dart';

/// 微信读书详情页内容区 — 简介、个人笔记、章节、热门划线、点评
class WereadInfoSection extends StatefulWidget {
  final WereadBookInfo bookInfo;
  final ChapterInfoResponse? chapters;
  final BestBookmarksResponse? bestBookmarks;
  final ReviewListResponse? reviews;
  final BookmarkListResponse? myBookmarks;
  final MineReviewListResponse? myReviews;
  final bool isDark;
  final VoidCallback? onLoadMoreReviews;
  final bool isLoadingMoreReviews;
  final bool reviewsLoadFailed;

  const WereadInfoSection({
    super.key,
    required this.bookInfo,
    this.chapters,
    this.bestBookmarks,
    this.reviews,
    this.myBookmarks,
    this.myReviews,
    required this.isDark,
    this.onLoadMoreReviews,
    this.isLoadingMoreReviews = false,
    this.reviewsLoadFailed = false,
  });

  @override
  State<WereadInfoSection> createState() => _WereadInfoSectionState();
}

class _WereadInfoSectionState extends State<WereadInfoSection> {
  bool _chaptersExpanded = false;
  bool _myBookmarksExpanded = false;
  bool _myReviewsExpanded = false;
  int? _selectedReviewRating;

  // Convenience getters
  WereadBookInfo get bookInfo => widget.bookInfo;
  ChapterInfoResponse? get chapters => widget.chapters;
  BestBookmarksResponse? get bestBookmarks => widget.bestBookmarks;
  ReviewListResponse? get reviews => widget.reviews;
  BookmarkListResponse? get myBookmarks => widget.myBookmarks;
  MineReviewListResponse? get myReviews => widget.myReviews;
  bool get isDark => widget.isDark;
  double get _carouselWidth =>
      (MediaQuery.sizeOf(context).width - 72).clamp(190.0, 310.0);
  double get _carouselHeight =>
      (185 * MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
        185.0,
        300.0,
      );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final fields = <String, String>{
      if (bookInfo.publisher?.isNotEmpty ?? false)
        t.get('publisher'): bookInfo.publisher!,
      if (bookInfo.publishTime?.isNotEmpty ?? false)
        t.get('weread_publish_time'): bookInfo.publishTime!,
      if (bookInfo.isbn?.isNotEmpty ?? false) 'ISBN': bookInfo.isbn!,
    };
    final hasMeta =
        (bookInfo.category?.isNotEmpty ?? false) ||
        bookInfo.ratingScore != null;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookDetailHeading(book: bookInfo.toDisplay()),
            if (hasMeta) ...[const SizedBox(height: 14), _buildMetaCapsules()],
            if (fields.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildPublicationDetails(fields, cs, t),
            ],
            if (bookInfo.intro?.isNotEmpty ?? false) ...[
              const SizedBox(height: 24),
              BookDetailDescription(text: bookInfo.intro!),
            ],
            if (myBookmarks != null && myBookmarks!.updated.isNotEmpty)
              _separatedSection(cs, _buildMyBookmarksSection(context, cs, t)),
            if (myReviews != null && myReviews!.reviews.isNotEmpty)
              _separatedSection(cs, _buildMyReviewsSection(context, cs, t)),
            if (chapters != null && chapters!.chapters.isNotEmpty)
              _separatedSection(cs, _buildChaptersSection(context, cs, t)),
            if (bestBookmarks != null && bestBookmarks!.items.isNotEmpty)
              _separatedSection(cs, _buildBestBookmarksSection(context, cs, t)),
            if (reviews != null && reviews!.reviews.isNotEmpty)
              _separatedSection(cs, _buildReviewsSection(context, cs, t)),
          ],
        ),
      ),
    );
  }

  Widget _separatedSection(ColorScheme cs, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
      const SizedBox(height: 24),
      child,
    ],
  );

  Widget _buildMetaCapsules() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      if (bookInfo.category?.isNotEmpty ?? false)
        BookDetailTag(
          icon: Icons.category_outlined,
          text: bookInfo.category!,
          highlight: true,
        ),
      if (bookInfo.ratingScore != null)
        BookDetailTag(
          icon: Icons.star_rounded,
          text:
              '${bookInfo.ratingScore!.toStringAsFixed(1)}${bookInfo.newRatingCount != null ? ' (${bookInfo.newRatingCount})' : ''}',
        ),
    ],
  );

  Widget _buildPublicationDetails(
    Map<String, String> fields,
    ColorScheme cs,
    AppLocalizations t,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t.get('publication_info'),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      for (final field in fields.entries)
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 62,
                child: Text(
                  field.key,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  field.value,
                  style: TextStyle(fontSize: 12, color: cs.onSurface),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _sectionHeading(
    ColorScheme cs,
    String title,
    int count, {
    IconData? icon,
    Color? iconColor,
  }) => Row(
    children: [
      if (icon != null) ...[
        Icon(icon, size: 18, color: iconColor ?? cs.primary),
        const SizedBox(width: 6),
      ],
      Flexible(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        '($count)',
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
    ],
  );

  void _showFullText(String title, String text, {String? subtitle}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  if (subtitle?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 5),
                    Text(
                      subtitle!,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SelectableText(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.65,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 我的划线
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildMyBookmarksSection(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations t,
  ) {
    final bookmarks = myBookmarks!.updated;
    final previewCount = 2;
    final displayItems = _myBookmarksExpanded
        ? bookmarks
        : bookmarks.take(previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          cs,
          t.get('weread_my_highlights'),
          bookmarks.length,
          icon: Icons.format_underlined_rounded,
          iconColor: cs.secondary,
        ),
        const SizedBox(height: 10),
        ...displayItems.map(
          (bm) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.accent.withValues(alpha: 0.08)
                  : AppColors.accent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.6),
                  width: 3,
                ),
              ),
            ),
            child: Text(
              bm.markText,
              style: TextStyle(fontSize: 13, height: 1.5, color: cs.onSurface),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (bookmarks.length > previewCount)
          _buildExpandButton(
            t,
            _myBookmarksExpanded,
            bookmarks.length,
            () => setState(() => _myBookmarksExpanded = !_myBookmarksExpanded),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 我的想法
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildMyReviewsSection(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations t,
  ) {
    final reviewItems = myReviews!.reviews;
    final previewCount = 2;
    final displayItems = _myReviewsExpanded
        ? reviewItems
        : reviewItems.take(previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          cs,
          t.get('weread_my_thoughts'),
          myReviews!.totalCount,
          icon: Icons.lightbulb_outline_rounded,
        ),
        const SizedBox(height: 10),
        ...displayItems.map(
          (rv) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 引用原文（如果有）
                if (rv.abstract_ != null && rv.abstract_!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: cs.outlineVariant, width: 2),
                      ),
                    ),
                    child: Text(
                      rv.abstract_!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // 想法正文
                Text(
                  rv.content,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: cs.onSurface,
                  ),
                  maxLines: _myReviewsExpanded ? null : 6,
                  overflow: _myReviewsExpanded ? null : TextOverflow.ellipsis,
                ),
                // 章节名
                if (rv.chapterName != null && rv.chapterName!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '📖 ${rv.chapterName}',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (reviewItems.length > previewCount)
          _buildExpandButton(
            t,
            _myReviewsExpanded,
            myReviews!.totalCount,
            () => setState(() => _myReviewsExpanded = !_myReviewsExpanded),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 章节目录
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildChaptersSection(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations t,
  ) {
    final chapterList = chapters!.chapters;
    final previewCount = 4;
    final displayItems = _chaptersExpanded
        ? chapterList
        : chapterList.take(previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(cs, t.get('weread_chapters'), chapterList.length),
        const SizedBox(height: 10),
        ...displayItems.map(
          (ch) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text(
                  '${ch.chapterIdx + 1}.',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ch.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: cs.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (chapterList.length > previewCount)
          _buildExpandButton(
            t,
            _chaptersExpanded,
            chapterList.length,
            () => setState(() => _chaptersExpanded = !_chaptersExpanded),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 热门划线
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildBestBookmarksSection(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations t,
  ) {
    final items = bestBookmarks!.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          cs,
          t.get('weread_hot_highlights'),
          bestBookmarks!.totalCount,
          icon: Icons.format_quote_rounded,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _carouselHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final bookmark = items[index];
              return GestureDetector(
                onTap: () => _showFullText(
                  t.get('weread_hot_highlights'),
                  bookmark.markText,
                  subtitle: t
                      .get('weread_people_highlighted')
                      .replaceAll('%d', '${bookmark.totalCount}'),
                ),
                child: Container(
                  width: _carouselWidth,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? cs.surfaceContainerLow
                        : AppColors.primary.withValues(alpha: 0.045),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            color: cs.primary,
                            size: 22,
                          ),
                          const Spacer(),
                          Icon(
                            Icons.open_in_full_rounded,
                            size: 15,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          bookmark.markText,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t
                            .get('weread_people_highlighted')
                            .replaceAll('%d', '${bookmark.totalCount}'),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 公开点评
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildReviewsSection(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations t,
  ) {
    final reviewList = reviews!.reviews;
    final groups = <int, List<ReviewItem>>{};
    for (final item in reviewList) {
      final stars = item.review.starCount;
      final group = stars != null && stars >= 1 && stars <= 5 ? stars : 0;
      groups.putIfAbsent(group, () => []).add(item);
    }
    final ratings = [5, 4, 3, 2, 1, if (groups[0]?.isNotEmpty ?? false) 0];
    final selectedRating = ratings.contains(_selectedReviewRating)
        ? _selectedReviewRating!
        : ratings.firstWhere(
            (rating) => groups[rating]?.isNotEmpty ?? false,
            orElse: () => 5,
          );
    final visibleReviews = groups[selectedRating] ?? <ReviewItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          cs,
          t.get('weread_reviews'),
          reviews!.reviewsCnt,
          icon: Icons.rate_review_outlined,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 160,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedRating,
                isExpanded: true,
                borderRadius: BorderRadius.circular(12),
                dropdownColor: cs.surface,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: cs.onSurfaceVariant,
                ),
                items: [
                  for (final stars in ratings)
                    DropdownMenuItem<int>(
                      value: stars,
                      child: Row(
                        children: [
                          Icon(
                            stars == 0
                                ? Icons.star_border_rounded
                                : Icons.star_rounded,
                            size: 18,
                            color: stars == 0
                                ? cs.onSurfaceVariant
                                : AppColors.accent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            stars == 0
                                ? t.get('weread_unrated_option')
                                : t
                                      .get('weread_star_option')
                                      .replaceAll('{count}', '$stars'),
                            style: TextStyle(fontSize: 14, color: cs.onSurface),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (stars) {
                  if (stars != null) {
                    setState(() => _selectedReviewRating = stars);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (visibleReviews.isNotEmpty)
          SizedBox(
            height: _carouselHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visibleReviews.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final review = visibleReviews[index].review;
                return GestureDetector(
                  onTap: () => _showFullText(
                    selectedRating == 0
                        ? t.get('weread_unrated_reviews')
                        : t
                              .get('weread_star_reviews')
                              .replaceAll('{count}', '$selectedRating'),
                    review.content.isEmpty
                        ? t.get('weread_rating_only')
                        : review.content,
                    subtitle: review.author.name.isEmpty
                        ? t.get('weread_reader')
                        : review.author.name,
                  ),
                  child: Container(
                    width: _carouselWidth,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_circle_outlined,
                              size: 20,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                review.author.name.isEmpty
                                    ? t.get('weread_reader')
                                    : review.author.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.open_in_full_rounded,
                              size: 15,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Text(
                            review.content.isEmpty
                                ? t.get('weread_rating_only')
                                : review.content,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (review.chapterName?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 8),
                          Text(
                            review.chapterName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              t.get('weread_no_star_reviews'),
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
        if (widget.reviewsLoadFailed) ...[
          const SizedBox(height: 12),
          Text(
            t.get('weread_reviews_load_failed'),
            style: TextStyle(color: cs.error, fontSize: 12),
          ),
        ],
        if (reviews!.hasMore && widget.onLoadMoreReviews != null) ...[
          const SizedBox(height: 14),
          Center(
            child: TextButton.icon(
              onPressed: widget.isLoadingMoreReviews
                  ? null
                  : widget.onLoadMoreReviews,
              icon: widget.isLoadingMoreReviews
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(t.get('weread_load_more_reviews')),
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Helper: 展开/收起按钮
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildExpandButton(
    AppLocalizations t,
    bool expanded,
    int totalCount,
    VoidCallback onTap,
  ) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(
          expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          size: 18,
        ),
        label: Text(
          expanded
              ? t.get('weread_show_less')
              : '${t.get('weread_view_all')} ($totalCount)',
        ),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
