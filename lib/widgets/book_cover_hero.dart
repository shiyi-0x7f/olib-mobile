import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 书卡封面 → 详情页 3D 封面的共享元素过渡（Hero），对应电脑端 2b02d67。
///
/// tag 带上来源 [scope]：同一本书可能同时出现在一个页面的多个列表里，
/// Flutter 要求同一页面内 Hero tag 唯一。
Object bookCoverHeroTag(String scope, Object bookId) =>
    'book-cover:$scope:$bookId';

/// 飞行中只显示一张平面封面（两端分别是卡片封面与 3D 书本，直接插值会很怪）。
/// 封面来自 CachedNetworkImage 缓存，飞行时不会重新加载。
HeroFlightShuttleBuilder bookCoverFlightShuttle(String? coverUrl) {
  return (context, animation, direction, fromContext, toContext) {
    final cs = Theme.of(context).colorScheme;
    final hasCover = coverUrl != null && coverUrl.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: cs.surfaceContainerHighest,
        child: hasCover
            ? Image(
                image: CachedNetworkImageProvider(coverUrl),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            : Icon(Icons.menu_book_rounded, color: cs.onSurfaceVariant),
      ),
    );
  };
}

/// 有 [tag] 时包一层 Hero，否则原样返回
Widget maybeBookCoverHero({
  required Object? tag,
  required String? coverUrl,
  required Widget child,
}) {
  if (tag == null) return child;
  return Hero(
    tag: tag,
    flightShuttleBuilder: bookCoverFlightShuttle(coverUrl),
    child: child,
  );
}
