import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class WereadBookCover extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String? author;
  final double width;
  final double height;
  final double radius;

  const WereadBookCover({
    super.key,
    required this.imageUrl,
    required this.title,
    this.author,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trimmedAuthor = author?.trim();
    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.16),
            colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: const Alignment(0, -0.38),
            child: Icon(
              Icons.menu_book_rounded,
              color: colorScheme.primary.withValues(alpha: 0.34),
              size: width.clamp(20.0, 34.0).toDouble(),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC183327)],
                stops: [0.35, 1],
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: width < 90 ? 10.5 : 12,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                if (trimmedAuthor != null && trimmedAuthor.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    trimmedAuthor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: width < 90 ? 8.5 : 9.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    final url = imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null || url.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url,
                memCacheWidth:
                    (width * MediaQuery.devicePixelRatioOf(context) * 1.5)
                        .round()
                        .clamp(300, 900)
                        .toInt(),
                fit: BoxFit.cover,
                imageBuilder: (context, provider) => Image(
                  image: provider,
                  fit: BoxFit.cover,
                  semanticLabel: title,
                ),
                placeholder: (context, url) => placeholder,
                errorWidget: (context, url, error) => placeholder,
              ),
      ),
    );
  }
}
