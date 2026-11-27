import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/book_comment.dart';
import '../../../providers/book_comments_provider.dart';

/// 书籍详情页的只读读者评论区：加载 / 空 / 已关闭 / 失败四态，
/// 默认展示前 [_collapsedCount] 楼，可展开全部。
class BookCommentsSection extends ConsumerStatefulWidget {
  final int bookId;

  const BookCommentsSection({super.key, required this.bookId});

  @override
  ConsumerState<BookCommentsSection> createState() =>
      _BookCommentsSectionState();
}

class _BookCommentsSectionState extends ConsumerState<BookCommentsSection> {
  static const _collapsedCount = 5;
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant BookCommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(bookCommentsProvider(widget.bookId));
    final total = async.valueOrNull?.total ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.forum_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              total > 0
                  ? '${l10n.get('book_comments')}（$total）'
                  : l10n.get('book_comments'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        async.when(
          loading: () => _Hint(
            leading: const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            text: l10n.get('loading'),
          ),
          error: (e, _) => _ErrorView(
            message: l10n.get('comments_load_failed'),
            detail: e.toString(),
            retryLabel: l10n.get('retry'),
            onRetry: () => ref.invalidate(bookCommentsProvider(widget.bookId)),
          ),
          data: (result) {
            if (result.disabled) {
              return _Hint(text: l10n.get('comments_disabled'));
            }
            if (result.threads.isEmpty) {
              return _Hint(text: l10n.get('comments_empty'));
            }
            return _buildThreads(context, result.threads);
          },
        ),
      ],
    );
  }

  Widget _buildThreads(BuildContext context, List<BookCommentThread> threads) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final visible = _expanded
        ? threads
        : threads.take(_collapsedCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0)
            Divider(
              height: 24,
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          _CommentTile(comment: visible[i].comment),
          for (final reply in visible[i].replies)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 12),
              child: _CommentTile(comment: reply, compact: true),
            ),
        ],
        if (threads.length > _collapsedCount)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 18,
            ),
            label: Text(
              _expanded
                  ? l10n.get('comments_collapse')
                  : l10n
                        .get('comments_show_all')
                        .replaceAll('{count}', '${threads.length}'),
            ),
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(48, 48),
            ),
          ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final BookComment comment;
  final bool compact;

  const _CommentTile({required this.comment, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = (comment.userName?.trim().isNotEmpty ?? false)
        ? comment.userName!.trim()
        : AppLocalizations.of(context).get('comments_anonymous');
    final date = comment.date;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(name: name, url: comment.userAvatar, radius: compact ? 12 : 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (date != null && date.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      date.length > 10 ? date.substring(0, 10) : date,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              SelectableText(
                comment.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatefulWidget {
  final String name;
  final String? url;
  final double radius;

  const _Avatar({required this.name, required this.url, required this.radius});

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = widget.url;
    final useImage =
        !_failed && url != null && RegExp(r'^https?://').hasMatch(url);
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: cs.surfaceContainerHighest,
      foregroundImage: useImage ? NetworkImage(url) : null,
      onForegroundImageError: useImage
          ? (_, _) {
              if (mounted) setState(() => _failed = true);
            }
          : null,
      child: Text(
        widget.name.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: widget.radius * 0.8,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final Widget? leading;
  final String text;

  const _Hint({this.leading, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Text(
            text,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 失败态：常驻显示错误摘要 + 可选中复制的详情 + 重试
class _ErrorView extends StatelessWidget {
  final String message;
  final String detail;
  final String retryLabel;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.detail,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: TextStyle(fontSize: 13, color: cs.error)),
        const SizedBox(height: 4),
        SelectableText(
          detail,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(retryLabel),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(48, 48),
          ),
        ),
      ],
    );
  }
}
