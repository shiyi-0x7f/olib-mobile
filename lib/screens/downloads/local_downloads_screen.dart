import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/download_provider.dart';
import '../lan/lan_connect.dart';
import '../../widgets/empty_state.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/file_utils.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class LocalDownloadsScreen extends ConsumerWidget {
  const LocalDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 2 Tabs: Ongoing (Downloading) / Completed
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          title: Text(
            AppLocalizations.of(context).get('downloads'),
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.folder_open, color: AppColors.primary),
              tooltip: AppLocalizations.of(context).get('open_folder') ?? 'Open Folder',
              onPressed: () async {
                try {
                  final success = await openDownloadFolder();
                  if (!success && context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context).get('open_folder_failed') ?? 'Could not open download folder directly.'),
                        action: SnackBarAction(
                           label: 'OK',
                           onPressed: () {},
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha:0.08) : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: AppColors.primary, // Forest Green
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha:0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: cs.onSurfaceVariant,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: AppLocalizations.of(context).get('ongoing')),
                  Tab(text: AppLocalizations.of(context).get('completed')),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            _OngoingDownloads(),
            _CompletedDownloads(),
          ],
        ),
      ),
    );
  }
}

class _OngoingDownloads extends ConsumerWidget {
  const _OngoingDownloads();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadProvider).where((t) => t.status == DownloadStatus.downloading || t.status == DownloadStatus.pending).toList();

    if (tasks.isEmpty) {
      return EmptyState(
        icon: Icons.downloading,
        title: AppLocalizations.of(context).get('no_active_downloads'),
        message: AppLocalizations.of(context).get('downloads_appear_here'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) => _DownloadItem(task: tasks[index]),
    );
  }
}

class _CompletedDownloads extends ConsumerWidget {
  const _CompletedDownloads();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadProvider).where((t) => t.status == DownloadStatus.completed || t.status == DownloadStatus.error).toList();

    if (tasks.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        title: AppLocalizations.of(context).get('no_completed_downloads'),
        message: AppLocalizations.of(context).get('downloaded_books_here'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) => _DownloadItem(task: tasks[index]),
    );
  }
}

class _DownloadItem extends ConsumerWidget {
  final DownloadTask task;

  const _DownloadItem({required this.task});
  
  Future<void> _openFile(BuildContext context) async {
    if (task.filePath == null) return;
    
    // Check file existence
    final file = File(task.filePath!);
    if (!await file.exists()) {
       if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('File not found at ${task.filePath}')),
         );
       }
       return;
    }

    final result = await OpenFilex.open(task.filePath!);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.message} (${result.type})')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDownloading = task.status == DownloadStatus.downloading;
    final isError = task.status == DownloadStatus.error;
    final isCompleted = task.status == DownloadStatus.completed;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: isCompleted && task.filePath != null
            ? () => _openFile(context)
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cover
              Container(
                width: 50,
                height: 75,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[100],
                  image: task.book.cover != null
                      ? DecorationImage(
                          image: NetworkImage(task.book.cover!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: task.book.cover == null ? const Icon(Icons.book, color: Colors.grey) : null,
              ),
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.book.author ?? AppLocalizations.of(context).get('unknown_author') ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Progress Bar
                    if (isDownloading) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: task.progress,
                          backgroundColor: Colors.grey[100],
                          valueColor: AlwaysStoppedAnimation(
                            task.progress > 0.7 ? AppColors.progressGreen : (task.progress > 0.3 ? AppColors.progressYellow : AppColors.progressOrange),
                          ),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(task.progress * 100).toInt()}% • ${AppLocalizations.of(context).get('downloading')}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ] else if (isError) ...[
                      Text(
                        task.error ?? AppLocalizations.of(context).get('error'),
                        style: const TextStyle(color: AppColors.error, fontSize: 11),
                        maxLines: 2, 
                      ),
                    ] else ...[
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                         decoration: BoxDecoration(
                           color: AppColors.success.withValues(alpha:0.1),
                           borderRadius: BorderRadius.circular(4),
                         ),
                         child: Text(
                           AppLocalizations.of(context).get('completed'),
                           style: const TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                         ),
                       ),
                    ],
                  ],
                ),
              ),
              
              // Actions
              if (isDownloading)
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => ref.read(downloadProvider.notifier).cancelDownload(task.id),
                ),

              if (!isDownloading)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (value) => _handleMenuAction(context, ref, value),
                  itemBuilder: (context) => [
                    if (isCompleted && task.filePath != null) ...[
                      PopupMenuItem(
                        value: 'open',
                        child: Row(
                          children: [
                            const Icon(Icons.open_in_new_rounded, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context).get('open_file')),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context).get('file_details') ?? 'File Details'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            const Icon(Icons.share_rounded, size: 20, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context).get('share')),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'send_to_pc',
                        child: Row(
                          children: [
                            const Icon(Icons.computer_outlined, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context).get('lan_send_to_computer')),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                    ],
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context).get('remove')),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 推送本地书籍文件到桌面端（LAN，POST /api/upload，multipart 字段 file）。
  /// 桌面侧限制：扩展名白名单 + 默认 500 MB 上限，超限/非法由 400/413 报回。
  Future<void> _sendToComputer(BuildContext context) async {
    final filePath = task.filePath;
    if (filePath == null) return;

    final file = File(filePath);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File not found at $filePath')),
        );
      }
      return;
    }
    if (!context.mounted) return;

    final client = await connectToDesktop(context);
    if (client == null || !context.mounted) return;

    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final progress = ValueNotifier<double>(0);
    final cancelToken = CancelToken();
    var dialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('lan_sending')),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, v, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: v > 0 ? v : null),
              const SizedBox(height: 8),
              Text('${(v * 100).toInt()}%'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelToken.cancel('user cancelled');
              dialogOpen = false;
              Navigator.pop(ctx);
            },
            child: Text(l.get('cancel')),
          ),
        ],
      ),
    ).then((_) => dialogOpen = false);

    final fileName = filePath.replaceAll('\\', '/').split('/').last;
    try {
      await client.uploadFile(
        filePath,
        fileName: fileName,
        cancelToken: cancelToken,
        onProgress: (sent, total) {
          if (total > 0) progress.value = sent / total;
        },
      );
      if (!context.mounted) return;
      if (dialogOpen) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.get('lan_upload_success')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      if (dialogOpen) Navigator.pop(context);
      if (e is DioException && CancelToken.isCancel(e)) return; // 用户主动取消
      messenger.showSnackBar(
        SnackBar(content: Text(lanErrorMessage(l, e))),
      );
    }
  }

  void _showFileInfo(BuildContext context, DownloadTask task) async {
    final file = File(task.filePath ?? '');
    int? size;
    try {
      if (await file.exists()) {
        size = await file.length();
      }
    } catch (_) {}

    String sizeStr = AppLocalizations.of(context).get('unknown') ?? 'Unknown';
    if (size != null) {
      if (size > 1024 * 1024) {
        sizeStr = '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
      } else if (size > 1024) {
        sizeStr = '${(size / 1024).toStringAsFixed(2)} KB';
      } else {
        sizeStr = '$size B';
      }
    }

    AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.bottomSlide,
      title: AppLocalizations.of(context).get('file_details') ?? 'File Details',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${AppLocalizations.of(context).get('book_name')}:', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(task.book.title),
            const SizedBox(height: 8),
            Text('${AppLocalizations.of(context).get('path')}:', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(task.filePath ?? 'Unknown'),
            const SizedBox(height: 8),
            Text('${AppLocalizations.of(context).get('file_size')}:', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(sizeStr),
          ],
        ),
      ),
      btnOkOnPress: () {},
    ).show();
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String taskId) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.bottomSlide,
      title: AppLocalizations.of(context).get('delete_confirm') ?? 'Delete File?',
      desc: AppLocalizations.of(context).get('delete_desc') ?? 'This will delete the file from your device.',
      btnCancelText: AppLocalizations.of(context).get('cancel'),
      btnOkText: AppLocalizations.of(context).get('delete'),
      btnCancelOnPress: () {},
      btnOkOnPress: () {
        ref.read(downloadProvider.notifier).removeTask(taskId);
      },
      btnOkColor: AppColors.error,
    ).show();
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'open':
        _openFile(context);
        break;
      case 'details':
        if (task.filePath != null) _showFileInfo(context, task);
        break;
      case 'share':
        if (task.filePath != null) {
          Share.shareXFiles([XFile(task.filePath!)], text: task.book.title);
        }
        break;
      case 'send_to_pc':
        _sendToComputer(context);
        break;
      case 'delete':
        _confirmDelete(context, ref, task.id);
        break;
    }
  }
}
