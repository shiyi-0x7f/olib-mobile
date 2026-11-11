import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/domain_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/book_download/book_download_flow.dart';
import '../../reader/reader_screen.dart';

class BookActionBar extends ConsumerWidget {
  final Book book;
  final DownloadTask? downloadTask;
  final bool isDownloading;
  final bool isCompleted;
  /// 从 AI 寻书入口进来的书，下载走 backend 免费下载路径，
  /// 不消耗用户 z站 账号配额。详见 BookDetailArgs。
  final bool fromAi;

  const BookActionBar({
    super.key,
    required this.book,
    required this.downloadTask,
    required this.isDownloading,
    required this.isCompleted,
    this.fromAi = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasReadOnline = book.readOnlineUrl != null && book.readOnlineUrl!.isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        )),
      ),
      child: Row(
        children: [
          // ── Download Button (Secondary or Primary if no read) ──
          Expanded(
            child: _buildDownloadButton(
              context, ref, l10n,
              isPrimary: !hasReadOnline,
            ),
          ),

          if (hasReadOnline) ...[
            const SizedBox(width: 12),

            // ── Read Button (Primary) ──
            Expanded(
              child: _buildReadButton(context, ref, l10n),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadButton(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n, {
    bool isPrimary = false,
  }) {
    final IconData icon;
    final String label;
    final cs = Theme.of(context).colorScheme;

    if (isCompleted) {
      icon = Icons.folder_open_rounded;
      label = l10n.get('open_file');
    } else if (isDownloading) {
      icon = Icons.downloading_rounded;
      label = '${(downloadTask!.progress * 100).toStringAsFixed(0)}%';
    } else {
      icon = Icons.download_rounded;
      label = l10n.get('download');
    }

    if (isPrimary) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: ElevatedButton.icon(
          onPressed: isDownloading ? null : () => _handleDownload(context, ref),
          icon: Icon(icon, size: 20),
          label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: isCompleted ? cs.primaryContainer : cs.primary,
            foregroundColor: isCompleted ? cs.onPrimaryContainer : cs.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            elevation: 0,
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: OutlinedButton.icon(
        onPressed: isDownloading ? null : () => _handleDownload(context, ref),
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(
            color: cs.primary.withValues(alpha: 0.35),
            width: 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildReadButton(
    BuildContext context, WidgetRef ref, AppLocalizations l10n,
  ) {
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: ElevatedButton.icon(
        onPressed: () => _handleRead(context, ref),
        icon: const Icon(Icons.menu_book_rounded, size: 20),
        label: Text(
          l10n.get('preview'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          elevation: 0,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  ACTION HANDLERS
  // ════════════════════════════════════════════════════════════
  void _handleRead(BuildContext context, WidgetRef ref) {
    final customDomain = ref.read(domainProvider);
    final authState = ref.read(authProvider);
    final user = authState.user;

    // Build the reader domain from the custom domain
    final String readerDomain;
    final languagePrefixes = {'zh', 'en', 'de', 'fr', 'es', 'it', 'pt', 'ja', 'ko', 'ru', 'ar'};
    final dotIndex = customDomain.indexOf('.');
    if (dotIndex > 0) {
      final prefix = customDomain.substring(0, dotIndex);
      if (languagePrefixes.contains(prefix)) {
        readerDomain = 'reader${customDomain.substring(dotIndex)}';
      } else {
        readerDomain = 'reader.$customDomain';
      }
    } else {
      readerDomain = 'reader.$customDomain';
    }

    String url = book.readOnlineUrl!;
    url = url.replaceAll(RegExp(r'cdn\.reader\.'), 'reader.');
    url = url.replaceAll(RegExp(r'reader\.[a-zA-Z0-9.-]+'), readerDomain);
    url = url.replaceAll(RegExp(r'z-library\.[a-zA-Z]+'), customDomain);

    if (user != null) {
      final separator = url.contains('?') ? '&' : '?';
      url = '$url${separator}remix_userkey=${user.remixUserkey}&remix_userid=${user.id}';
    }

    Navigator.of(context).pushNamed(
      AppRoutes.reader,
      arguments: ReaderArgs(url: url, title: book.title),
    );
  }

  /// 下载流程见 [BookDownloadFlow]（与搜索结果行内下载共用）。
  void _handleDownload(BuildContext context, WidgetRef ref) {
    BookDownloadFlow.run(
      context,
      ref,
      book,
      task: downloadTask,
      fromAi: fromAi,
    );
  }
}
