import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/download_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/file_utils.dart';
import '../../widgets/empty_state.dart';
import '../lan/lan_connect.dart';
import '../weread/weread_mobile_hub_screen.dart';

class LocalDownloadsScreen extends ConsumerWidget {
  const LocalDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tasks = ref.watch(downloadProvider);
    final ongoing = tasks
        .where((task) => task.status != DownloadStatus.completed)
        .toList();
    final completed =
        tasks.where((task) => task.status == DownloadStatus.completed).toList()
          ..sort(
            (a, b) => (b.downloadedAt ?? DateTime(0)).compareTo(
              a.downloadedAt ?? DateTime(0),
            ),
          );
    ongoing.sort((a, b) => _priority(a.status).compareTo(_priority(b.status)));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.get('downloads')),
          actions: [
            IconButton(
              tooltip: l.get('open_folder'),
              icon: const Icon(Icons.folder_open_rounded),
              onPressed: () async {
                try {
                  final opened = await openDownloadFolder();
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.get('open_folder_failed'))),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.get('open_folder_failed'))),
                    );
                  }
                }
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            tabs: [
              Tab(text: '${l.get('ongoing')} (${ongoing.length})'),
              Tab(text: '${l.get('completed')} (${completed.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DownloadList(
              tasks: ongoing,
              emptyIcon: Icons.downloading_rounded,
              emptyTitle: l.get('no_active_downloads'),
              emptyMessage: l.get('downloads_appear_here'),
            ),
            _DownloadList(
              tasks: completed,
              emptyIcon: Icons.check_circle_outline_rounded,
              emptyTitle: l.get('no_completed_downloads'),
              emptyMessage: l.get('downloaded_books_here'),
            ),
          ],
        ),
      ),
    );
  }

  static int _priority(DownloadStatus status) => switch (status) {
    DownloadStatus.downloading => 0,
    DownloadStatus.pending => 1,
    DownloadStatus.error => 2,
    DownloadStatus.cancelled => 3,
    DownloadStatus.completed => 4,
  };
}

class _DownloadList extends StatelessWidget {
  const _DownloadList({
    required this.tasks,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<DownloadTask> tasks;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _DownloadItem(task: tasks[index]),
    );
  }
}

class _DownloadItem extends ConsumerWidget {
  const _DownloadItem({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final isActive =
        task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.pending;
    final isComplete = task.status == DownloadStatus.completed;
    final details = [
      if (task.book.extension?.isNotEmpty ?? false)
        task.book.extension!.toUpperCase(),
      if (task.fileSize != null) _formatSize(task.fileSize!),
      if (task.fileSize == null &&
          (task.book.filesizeString?.isNotEmpty ?? false))
        task.book.filesizeString!,
      if (task.downloadedAt != null) _formatDate(task.downloadedAt!),
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 64,
                    height: 92,
                    child: task.book.cover?.isNotEmpty == true
                        ? CachedNetworkImage(
                            imageUrl: task.book.cover!,
                            fit: BoxFit.cover,
                            memCacheWidth:
                                (64 * MediaQuery.devicePixelRatioOf(context))
                                    .ceil(),
                            errorWidget: (_, __, ___) => _coverPlaceholder(cs),
                          )
                        : _coverPlaceholder(cs),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        task.book.author?.isNotEmpty == true
                            ? task.book.author!
                            : l.get('unknown_author'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          details,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 9),
                      _statusLabel(context, l),
                    ],
                  ),
                ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value:
                    task.status == DownloadStatus.pending || task.progress <= 0
                    ? null
                    : task.progress,
                minHeight: 5,
                borderRadius: BorderRadius.circular(5),
              ),
              const SizedBox(height: 4),
              Text(
                task.status == DownloadStatus.pending
                    ? l.get('download_preparing')
                    : '${(task.progress * 100).round()}%',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
            if (task.status == DownloadStatus.error) ...[
              const SizedBox(height: 8),
              Text(
                task.missingFile
                    ? l.get('download_file_missing')
                    : task.quotaExceeded
                    ? l.get('download_quota_exceeded')
                    : task.needsFreshLink
                    ? l.get('download_fresh_link_required')
                    : task.error ?? l.get('download_failed'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.error),
              ),
            ],
            if (task.status == DownloadStatus.cancelled &&
                task.needsFreshLink) ...[
              const SizedBox(height: 8),
              Text(
                l.get('download_fresh_link_required'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (isComplete)
                  FilledButton.tonalIcon(
                    onPressed: () => _openFile(context, ref),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(l.get('open_file')),
                  )
                else if (task.canRetry)
                  FilledButton.tonalIcon(
                    onPressed: () => ref
                        .read(downloadProvider.notifier)
                        .startDownload(task.book),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l.get('retry')),
                  )
                else if (isActive)
                  TextButton.icon(
                    onPressed: () => ref
                        .read(downloadProvider.notifier)
                        .cancelDownload(task.id),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(l.get('cancel')),
                  ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: l.get('more'),
                  onSelected: (value) => _onMenu(context, ref, value),
                  itemBuilder: (_) => [
                    if (isComplete) ...[
                      PopupMenuItem(
                        value: 'details',
                        child: Text(l.get('file_details')),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: Text(l.get('share')),
                      ),
                      PopupMenuItem(
                        value: 'import_weread',
                        child: Text(l.get('weread_import_title')),
                      ),
                      PopupMenuItem(
                        value: 'send_to_pc',
                        child: Text(l.get('lan_send_to_computer')),
                      ),
                      const PopupMenuDivider(),
                    ],
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        isComplete
                            ? l.get('download_delete_file')
                            : l.get('download_remove_record'),
                      ),
                    ),
                  ],
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder(ColorScheme cs) => ColoredBox(
    color: cs.surfaceContainerHighest,
    child: Icon(Icons.menu_book_rounded, color: cs.onSurfaceVariant),
  );

  Widget _statusLabel(BuildContext context, AppLocalizations l) {
    final (label, color) = switch (task.status) {
      DownloadStatus.pending => (
        l.get('download_preparing'),
        AppColors.primary,
      ),
      DownloadStatus.downloading => (l.get('downloading'), AppColors.primary),
      DownloadStatus.completed => (l.get('completed'), AppColors.success),
      DownloadStatus.error => (
        l.get('download_failed'),
        Theme.of(context).colorScheme.error,
      ),
      DownloadStatus.cancelled => (
        l.get('download_cancelled'),
        Theme.of(context).colorScheme.outline,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<bool> _fileExists(BuildContext context, WidgetRef ref) async {
    final path = task.filePath;
    if (path != null && await File(path).exists()) return true;
    ref.read(downloadProvider.notifier).markMissingFile(task.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).get('download_file_missing'),
          ),
        ),
      );
    }
    return false;
  }

  Future<void> _openFile(BuildContext context, WidgetRef ref) async {
    if (!await _fileExists(context, ref)) return;
    try {
      final result = await OpenFilex.open(task.filePath!);
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final l = AppLocalizations.of(context);
    switch (action) {
      case 'details':
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(l.get('file_details')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.book.title),
                const SizedBox(height: 8),
                if (task.fileSize != null) Text(_formatSize(task.fileSize!)),
                if (task.downloadedAt != null)
                  Text(_formatDate(task.downloadedAt!)),
                const SizedBox(height: 8),
                SelectableText(task.filePath ?? ''),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.get('done')),
              ),
            ],
          ),
        );
        return;
      case 'share':
        if (!await _fileExists(context, ref)) return;
        try {
          await SharePlus.instance.share(
            ShareParams(files: [XFile(task.filePath!)], text: task.book.title),
          );
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error.toString())));
          }
        }
        return;
      case 'import_weread':
        if (!await _fileExists(context, ref) || !context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                WereadMobileHubScreen(initialFilePath: task.filePath),
          ),
        );
        return;
      case 'send_to_pc':
        await _sendToComputer(context, ref);
        return;
      case 'delete':
        await _confirmDelete(context, ref);
        return;
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          task.status == DownloadStatus.completed
              ? l.get('download_delete_file')
              : l.get('download_remove_record'),
        ),
        content: Text(
          task.status == DownloadStatus.completed
              ? l.get('delete_desc')
              : l.get('download_remove_record_hint'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.get('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.get('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(downloadProvider.notifier).removeTask(task.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.get('download_delete_failed'))),
        );
      }
    }
  }

  Future<void> _sendToComputer(BuildContext context, WidgetRef ref) async {
    if (!await _fileExists(context, ref) || !context.mounted) return;
    final client = await connectToDesktop(context);
    if (client == null || !context.mounted) return;

    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final progress = ValueNotifier<double>(0);
    final cancelToken = CancelToken();
    var dialogOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.get('lan_sending')),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, value, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value > 0 ? value : null),
              const SizedBox(height: 8),
              Text('${(value * 100).round()}%'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelToken.cancel('user cancelled');
              dialogOpen = false;
              Navigator.pop(dialogContext);
            },
            child: Text(l.get('cancel')),
          ),
        ],
      ),
    ).then((_) => dialogOpen = false);

    final path = task.filePath!;
    final fileName = path.replaceAll('\\', '/').split('/').last;
    try {
      await client.uploadFile(
        path,
        fileName: fileName,
        cancelToken: cancelToken,
        onProgress: (sent, total) {
          if (total > 0) progress.value = sent / total;
        },
      );
      if (!context.mounted) return;
      if (dialogOpen) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(l.get('lan_upload_success'))),
      );
    } catch (error) {
      if (!context.mounted) return;
      if (dialogOpen) Navigator.pop(context);
      if (error is DioException && CancelToken.isCancel(error)) return;
      messenger.showSnackBar(
        SnackBar(content: Text(lanErrorMessage(l, error))),
      );
    } finally {
      progress.dispose();
    }
  }
}
