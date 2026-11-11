import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/download_provider.dart';
import '../../services/lan_client.dart';
import '../../widgets/app_toast.dart';
import 'lan_connect.dart';

/// 批量把已下载的书发到电脑：选书 → 逐本上传（带总进度）→ 汇总结果。
Future<void> sendBooksToDesktop(
  BuildContext context,
  WidgetRef ref,
  LanClient client,
) async {
  final l = AppLocalizations.of(context);
  final done = ref
      .read(downloadProvider)
      .where((t) => t.status == DownloadStatus.completed && t.filePath != null)
      .toList();
  if (done.isEmpty) {
    AppToast.show(l.get('desktop_link_no_books'));
    return;
  }

  final picked = await showModalBottomSheet<List<DownloadTask>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PickBooksSheet(tasks: done),
  );
  if (picked == null || picked.isEmpty || !context.mounted) return;
  await _upload(context, client, picked);
}

Future<void> _upload(
  BuildContext context,
  LanClient client,
  List<DownloadTask> tasks,
) async {
  final l = AppLocalizations.of(context);
  final navigator = Navigator.of(context);
  // (当前第几本, 本书进度 0~1)
  final progress = ValueNotifier<(int, double)>((0, 0));
  final cancelToken = CancelToken();
  var dialogOpen = true;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(l.get('lan_sending')),
      content: ValueListenableBuilder<(int, double)>(
        valueListenable: progress,
        builder: (_, v, __) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tasks[v.$1].book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: v.$2 > 0 ? v.$2 : null),
            const SizedBox(height: 8),
            Text(
              l
                  .get('desktop_link_sending_n')
                  .replaceAll('%i', '${v.$1 + 1}')
                  .replaceAll('%t', '${tasks.length}'),
            ),
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

  var sent = 0;
  Object? lastError;
  for (var i = 0; i < tasks.length; i++) {
    if (cancelToken.isCancelled) break;
    progress.value = (i, 0);
    final path = tasks[i].filePath!;
    if (!File(path).existsSync()) {
      lastError = l.get('download_file_missing');
      continue;
    }
    try {
      await client.uploadFile(
        path,
        fileName: path.replaceAll('\\', '/').split('/').last,
        cancelToken: cancelToken,
        onProgress: (s, total) {
          if (total > 0) progress.value = (i, s / total);
        },
      );
      sent++;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) break;
      lastError = e;
    } on LanAuthException catch (e) {
      // token 失效，后面的也不会成功
      lastError = e;
      break;
    } on LanFileTooLargeException catch (e) {
      lastError = e;
    } on LanRejectedException catch (e) {
      lastError = e;
    } on FileSystemException catch (e) {
      lastError = e;
    }
  }
  progress.dispose();
  if (dialogOpen) navigator.pop();

  final failed = tasks.length - sent;
  if (cancelToken.isCancelled) {
    // 用户主动取消：只告知已发出的，不算失败
    if (sent > 0) {
      AppToast.success(l.get('desktop_link_sent_n').replaceAll('%d', '$sent'));
    }
    return;
  }
  if (failed == 0) {
    AppToast.success(l.get('desktop_link_sent_n').replaceAll('%d', '$sent'));
    return;
  }
  final reason = lastError is String
      ? lastError
      : lanErrorMessage(l, lastError ?? '');
  AppToast.error(
    '${l.get('desktop_link_send_partial').replaceAll('%s', '$sent').replaceAll('%f', '$failed')}\n$reason',
  );
}

class _PickBooksSheet extends StatefulWidget {
  final List<DownloadTask> tasks;

  const _PickBooksSheet({required this.tasks});

  @override
  State<_PickBooksSheet> createState() => _PickBooksSheetState();
}

class _PickBooksSheetState extends State<_PickBooksSheet> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final all = _selected.length == widget.tasks.length;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (_, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.get('desktop_link_send_books'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    all
                        ? _selected.clear()
                        : _selected.addAll(widget.tasks.map((t) => t.id));
                  }),
                  child: Text(l.get('select_all')),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: widget.tasks.length,
              itemBuilder: (_, i) {
                final t = widget.tasks[i];
                return CheckboxListTile(
                  value: _selected.contains(t.id),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    t.book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    (t.book.extension ?? '').toUpperCase(),
                    style: const TextStyle(fontSize: 11),
                  ),
                  onChanged: (v) => setState(() {
                    v == true ? _selected.add(t.id) : _selected.remove(t.id);
                  }),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(
                          context,
                          widget.tasks
                              .where((t) => _selected.contains(t.id))
                              .toList(),
                        ),
                  icon: const Icon(Icons.send_rounded),
                  label: Text(
                    l
                        .get('desktop_link_send_n')
                        .replaceAll('%d', '${_selected.length}'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
