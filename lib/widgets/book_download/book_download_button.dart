import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/download_provider.dart';
import 'book_download_flow.dart';

/// 某本书当前的下载任务（无则 null）。
final bookDownloadTaskProvider = Provider.family<DownloadTask?, String>((
  ref,
  bookId,
) {
  for (final t in ref.watch(downloadProvider)) {
    if (t.id == bookId) return t;
  }
  return null;
});

/// 搜索结果里的下载按钮：未下载 → 下载；下载中 → 进度；已完成 → 打开。
///
/// [label] 非空时渲染为整宽主按钮（最佳匹配卡片），否则为圆形图标按钮（列表行尾）。
class BookDownloadButton extends ConsumerWidget {
  final Book book;
  final String? label;

  const BookDownloadButton({super.key, required this.book, this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(bookDownloadTaskProvider(book.id.toString()));
    final status = task?.status;
    final downloading =
        status == DownloadStatus.downloading ||
        status == DownloadStatus.pending;
    final done = status == DownloadStatus.completed;
    final t = AppLocalizations.of(context);
    void onTap() => BookDownloadFlow.run(context, ref, book, task: task);

    if (label != null) {
      return SizedBox(
        height: 44,
        child: FilledButton.icon(
          onPressed: downloading ? null : onTap,
          icon: Icon(
            done ? Icons.folder_open_rounded : Icons.download_rounded,
            size: 20,
          ),
          label: Text(
            downloading
                ? '${(task!.progress * 100).toStringAsFixed(0)}%'
                : done
                ? t.get('open_file')
                : label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    if (downloading) {
      final progress = task!.progress;
      return SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 2.5,
                value: progress > 0 ? progress : null,
              ),
              Center(
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return IconButton(
      tooltip: done ? t.get('open_file') : t.get('download'),
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: done ? cs.primaryContainer : null,
        side: done ? null : BorderSide(color: cs.outlineVariant),
      ),
      color: done ? cs.onPrimaryContainer : cs.primary,
      icon: Icon(done ? Icons.check_rounded : Icons.download_rounded, size: 20),
    );
  }
}
