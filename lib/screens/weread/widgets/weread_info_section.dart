import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/weread/weread_models.dart';

/// 微信读书详情页内容区 — 简介、个人笔记、章节、热门划线、点评
class WereadInfoSection extends StatefulWidget {
  final WereadBookInfo bookInfo;
  final ChapterInfoResponse? chapters;
  final BestBookmarksResponse? bestBookmarks;
  final ReviewListResponse? reviews;
  final BookmarkListResponse? myBookmarks;
  final MineReviewListResponse? myReviews;
  final bool isDark;

  const WereadInfoSection({
    super.key,
    required this.bookInfo,
    this.chapters,
    this.bestBookmarks,
    this.reviews,
    this.myBookmarks,
    this.myReviews,
    required this.isDark,
  });

  @override
  State<WereadInfoSection> createState() => _WereadInfoSectionState();
}

class _WereadInfoSectionState extends State<WereadInfoSection> {
  bool _chaptersExpanded = false;
  bool _myBookmarksExpanded = false;
  bool _myReviewsExpanded = false;
  bool _bestBookmarksExpanded = false;
  bool _reviewsExpanded = false;

  // Convenience getters
  WereadBookInfo get bookInfo => widget.bookInfo;
  ChapterInfoResponse? get chapters => widget.chapters;
  BestBookmarksResponse? get bestBookmarks => widget.bestBookmarks;
  ReviewListResponse? get reviews => widget.reviews;
  BookmarkListResponse? get myBookmarks => widget.myBookmarks;
  MineReviewListResponse? get myReviews => widget.myReviews;
  bool get isDark => widget.isDark;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

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
              // ── 书名 + 作者 ──
              Text(
                bookInfo.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              if (bookInfo.author != null && bookInfo.author!.isNotEmpty)
                Text(
                  bookInfo.author!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

              const SizedBox(height: 16),

              // ── 元数据胶囊 ──
              _buildMetaCapsules(context, cs),

              // ── 简介 ──
              if (bookInfo.intro != null && bookInfo.intro!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  t.get('description'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  bookInfo.intro!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],

              // ── 我的划线 ──
              if (myBookmarks != null &&
                  myBookmarks!.updated.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildMyBookmarksSection(context, cs, t),
              ],

              // ── 我的想法 ──
              if (myReviews != null &&
                  myReviews!.reviews.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildMyReviewsSection(context, cs, t),
              ],

              // ── 章节目录 ──
              if (chapters != null && chapters!.chapters.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildChaptersSection(context, cs, t),
              ],

              // ── 热门划线 ──
              if (bestBookmarks != null &&
                  bestBookmarks!.items.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildBestBookmarksSection(context, cs, t),
              ],

              // ── 公开点评 ──
              if (reviews != null && reviews!.reviews.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildReviewsSection(context, cs, t),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaCapsules(BuildContext context, ColorScheme cs) {
    final capsules = <Widget>[];

    if (bookInfo.category != null && bookInfo.category!.isNotEmpty) {
      capsules.add(_capsule(
        context,
        Icons.category_outlined,
        bookInfo.category!,
        highlight: true,
      ));
    }

    if (bookInfo.publisher != null && bookInfo.publisher!.isNotEmpty) {
      capsules.add(
          _capsule(context, Icons.business_outlined, bookInfo.publisher!));
    }

    if (bookInfo.ratingScore != null) {
      final countStr = bookInfo.newRatingCount != null
          ? ' (${bookInfo.newRatingCount})'
          : '';
      capsules.add(_capsule(
        context,
        Icons.star_rounded,
        '${bookInfo.ratingScore!.toStringAsFixed(1)}$countStr',
      ));
    }

    if (capsules.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: capsules);
  }

  Widget _capsule(BuildContext context, IconData icon, String text,
      {bool highlight = false}) {
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

  // ═══════════════════════════════════════════════════════════════════
  // 我的划线
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildMyBookmarksSection(
      BuildContext context, ColorScheme cs, AppLocalizations t) {
    final bookmarks = myBookmarks!.updated;
    final previewCount = 8;
    final displayItems = _myBookmarksExpanded
        ? bookmarks
        : bookmarks.take(previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.format_underlined_rounded,
                size: 18, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(
              t.get('weread_my_highlights'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${bookmarks.length})',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...displayItems.map((bm) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.accent.withValues(alpha: 0.08)
                    : AppColors.accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: AppColors.accent.withValues(alpha: 0.6),
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                bm.markText,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: cs.onSurface,
                ),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            )),
        if (bookmarks.length > previewCount)
          _buildExpandButton(
            t, _myBookmarksExpanded, bookmarks.length,
            () => setState(() => _myBookmarksExpanded = !_myBookmarksExpanded),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 我的想法
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildMyReviewsSection(
      BuildContext context, ColorScheme cs, AppLocalizations t) {
    final reviewItems = myReviews!.reviews;
    final previewCount = 8;
    final displayItems = _myReviewsExpanded
        ? reviewItems
        : reviewItems.take(previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              t.get('weread_my_thoughts'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${myReviews!.totalCount})',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...displayItems.map((rv) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
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
                          left: BorderSide(
                            color: cs.outlineVariant,
                            width: 2,
                          ),
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
                  if (rv.chapterName != null &&
                      rv.chapterName!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '📖 ${rv.chapterName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            )),
        if (reviewItems.length > previewCount)
          _buildExpandButton(
            t, _myReviewsExpanded, myReviews!.totalCount,
            () => setState(() => _myReviewsExpanded = !_myReviewsExpanded),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 章节目录
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildChaptersSection(
      BuildContext context, ColorScheme cs, AppLocalizations t) {
    final chapterList = chapters!.chapters;
    final previewCount = 6;
    final displayItems = _chaptersExpanded
        ? chapterList
        : chapterList.take(previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              t.get('weread_chapters'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${chapterList.length})',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...displayItems.map((ch) => Padding(
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
            )),
        if (chapterList.length > previewCount)
          _buildExpandButton(
            t, _chaptersExpanded, chapterList.length,
            () => setState(() => _chaptersExpanded = !_chaptersExpanded),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 热门划线
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildBestBookmarksSection(
      BuildContext context, ColorScheme cs, AppLocalizations t) {
    final items = bestBookmarks!.items;
    final previewCount = 5;
    final displayItems = _bestBookmarksExpanded
        ? items
        : items.take(previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              t.get('weread_hot_highlights'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${bestBookmarks!.totalCount})',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...displayItems.map((bm) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : AppColors.primary.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bm.markText,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: cs.onSurface,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: _bestBookmarksExpanded ? null : 4,
                    overflow: _bestBookmarksExpanded ? null : TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.get('weread_people_highlighted')
                        .replaceAll('%d', '${bm.totalCount}'),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )),
        if (items.length > previewCount)
          _buildExpandButton(
            t, _bestBookmarksExpanded, items.length,
            () => setState(() => _bestBookmarksExpanded = !_bestBookmarksExpanded),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 公开点评
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildReviewsSection(
      BuildContext context, ColorScheme cs, AppLocalizations t) {
    final reviewList = reviews!.reviews;
    final previewCount = 5;
    final displayItems = _reviewsExpanded
        ? reviewList
        : reviewList.take(previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              t.get('weread_reviews'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${reviews!.reviewsCnt})',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...displayItems.map((rv) {
          final detail = rv.review;
          final starCount = detail.starCount ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < starCount
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 14,
                        color: i < starCount
                            ? AppColors.accent
                            : cs.outlineVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      detail.author.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                if (detail.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    detail.content,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: _reviewsExpanded ? null : 4,
                    overflow: _reviewsExpanded ? null : TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          );
        }),
        if (reviewList.length > previewCount)
          _buildExpandButton(
            t, _reviewsExpanded, reviewList.length,
            () => setState(() => _reviewsExpanded = !_reviewsExpanded),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Helper: 展开/收起按钮
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildExpandButton(
      AppLocalizations t, bool expanded, int totalCount, VoidCallback onTap) {
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
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
    );
  }
}
