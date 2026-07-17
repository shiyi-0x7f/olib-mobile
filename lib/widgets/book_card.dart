import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/display_book.dart';
import '../theme/app_colors.dart';

class BookCard extends StatefulWidget {
  final DisplayBook book;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BookCard({
    super.key,
    required this.book,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard> with SingleTickerProviderStateMixin {
  bool _shouldLoadImage = false;
  
  // Press feedback
  double _scale = 1.0;
  
  // Shimmer animation
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Shimmer sweep animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutSine),
    );
    
    // Delay image loading slightly to allow layout to complete
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _shouldLoadImage = true);
      }
    });
  }
  
  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _scale = 0.96);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0);
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Soft Card UI with press-scale feedback
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onTapCancel: _onTapCancel,
              child: InkWell(
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Cover Image (Expanded)
                    Expanded(
                      flex: 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (widget.book.cover != null && widget.book.cover!.isNotEmpty && _shouldLoadImage)
                            CachedNetworkImage(
                              imageUrl: widget.book.cover!,
                              fit: BoxFit.cover,
                              memCacheWidth: 300,
                              fadeInDuration: const Duration(milliseconds: 300),
                              fadeOutDuration: const Duration(milliseconds: 100),
                              httpHeaders: const {
                                'Connection': 'keep-alive',
                              },
                              errorWidget: (context, url, error) => _buildPlaceholder(),
                              placeholder: (context, url) => _buildShimmer(),
                            )
                          else
                            _shouldLoadImage ? _buildPlaceholder() : _buildShimmer(),
                        ],
                      ),
                    ),

                    // 2. Info Content
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Level 2: Category/Tag (Orange, Small) - ABOVE Title
                            _buildMetaRow(),
                            
                            const SizedBox(height: 4),

                            // Level 1: Title (Black, Bold, Large)
                            Expanded(
                              child: Text(
                                widget.book.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  height: 1.2,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            
                            // Level 3: Author (Grey, Secondary)
                            if (widget.book.author != null && widget.book.author!.isNotEmpty)
                              Text(
                                widget.book.author!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                              
                            const SizedBox(height: 8),

                            // Level 3: Bottom row (Stars/Size)
                            _buildBottomRow(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// Build the top meta row (tag + tagExtra)
  Widget _buildMetaRow() {
    final hasTag = widget.book.tag != null && widget.book.tag!.isNotEmpty;
    final hasTagExtra = widget.book.tagExtra != null && widget.book.tagExtra!.isNotEmpty;

    if (!hasTag && !hasTagExtra) {
      // Return a minimal spacer if no meta info available
      return const SizedBox(height: 12);
    }

    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (hasTag)
          Flexible(
            child: Text(
              widget.book.tag!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        if (hasTag && hasTagExtra)
          const SizedBox(width: 4),
        if (hasTagExtra)
          Text(
            hasTag ? '• ${widget.book.tagExtra}' : widget.book.tagExtra!,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
      ],
    );
  }

  /// Build the bottom row (score + meta)
  Widget _buildBottomRow() {
    final hasScore = widget.book.score != null && widget.book.score!.isNotEmpty;
    final hasMeta = widget.book.meta != null && widget.book.meta!.isNotEmpty;

    if (!hasScore && !hasMeta) {
      // Show nothing if no data available
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (hasScore) ...[
          const Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            widget.book.score!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ],
        const Spacer(),
        if (hasMeta)
          Text(
            widget.book.meta!,
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  /// Placeholder when no cover or load error — gradient background + book icon
  Widget _buildPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.primary.withValues(alpha:0.15),
                  AppColors.primary.withValues(alpha:0.08),
                ]
              : [
                  AppColors.primary.withValues(alpha:0.08),
                  AppColors.primary.withValues(alpha:0.04),
                ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_stories_rounded,
          color: AppColors.primary.withValues(alpha:isDark ? 0.4 : 0.25),
          size: 36,
        ),
      ),
    );
  }
  
  /// Real shimmer effect — animated gradient sweep
  Widget _buildShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
    final highlightColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);
    
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                _shimmerAnimation.value.clamp(0.0, 1.0),
                (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
