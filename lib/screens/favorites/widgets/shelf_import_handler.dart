import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/booklist_import_service.dart';
import '../../../services/booklist_share_codec.dart';
import '../../../utils/booklist_file_utils.dart';
import '../../../providers/books_provider.dart';
import '../../../widgets/share_preview_sheet.dart';
import '../../lan/lan_connect.dart';
import '../../lan/lan_import_screen.dart';
import '../scanner_screen.dart';

enum ImportSource { scan, paste, file, lan }

/// 书单导入/导出/批量操作 Mixin
mixin ShelfImportHandler<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {

  Future<void> handleImport(AppLocalizations l, ImportSource source) async {
    BooklistShareData? data;
    switch (source) {
      case ImportSource.scan:
        final scanned = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScannerScreen()),
        );
        if (scanned is String) {
          data = BooklistShareCodec.tryDecode(scanned);
        }
        break;
      case ImportSource.paste:
        data = await _pasteAndDecode(l);
        break;
      case ImportSource.file:
        try {
          data = await BooklistFileUtils.pickAndParse();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${l.get('error')}: $e')),
            );
          }
          return;
        }
        break;
      case ImportSource.lan:
        // 从电脑取书：扫桌面「无线传书」二维码，走 LAN 文件列表页，
        // 与书单导入是两条路径，处理完直接返回。
        await _importFromComputer(l);
        return;
    }

    if (!mounted) return;
    if (data == null || data.entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('invalid_booklist'))),
      );
      return;
    }

    await runImport(l, data);
  }

  /// 从电脑取书：步骤引导 → 扫码/手动输入（`http://IP:8765?token=`）→ LAN 导入页。
  Future<void> _importFromComputer(AppLocalizations l) async {
    final peer = await promptDesktopPeer(
      context,
      title: l.get('lan_import_title'),
    );
    if (peer == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LanImportScreen(peer: peer)),
    );
  }

  Future<BooklistShareData?> _pasteAndDecode(AppLocalizations l) async {
    final clip = await Clipboard.getData('text/plain');
    final initial = clip?.text ?? '';
    if (!mounted) return null;

    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('paste_token')),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: l.get('paste_token_hint'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l.get('import')),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return null;
    return BooklistShareCodec.tryDecode(result);
  }

  Future<void> runImport(AppLocalizations l, BooklistShareData data) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(l.get('processing'))),
    );

    final service = ref.read(booklistImportServiceProvider);
    final r = await service.importFromData(data);

    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    final msg = l
        .get('import_result')
        .replaceAll('%i', '${r.imported}')
        .replaceAll('%s', '${r.skipped}')
        .replaceAll('%f', '${r.failed}');
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: r.imported > 0 ? Colors.green : null,
      ),
    );
  }

  void showSharePreview(AppLocalizations l, Set<int> selectedIds) {
    final savedBooks = ref.read(savedBooksProvider).valueOrNull ?? [];
    final selectedBooks = savedBooks
        .where((b) => selectedIds.contains(b.id))
        .toList();

    if (selectedBooks.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SharePreviewSheet(books: selectedBooks),
    );
  }

  Future<void> batchRemove(Set<int> selectedIds) async {
    final notifier = ref.read(savedBooksProvider.notifier);
    for (final id in selectedIds.toList()) {
      await notifier.unsaveBook(id.toString());
    }
  }

  void confirmBatchRemove(AppLocalizations l, Set<int> selectedIds,
      VoidCallback onDone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('confirm_remove_title')),
        content: Text(
          l.get('confirm_remove_msg')
              .replaceAll('%d', '${selectedIds.length}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.get('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await batchRemove(selectedIds);
              onDone();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red[400],
            ),
            child: Text(l.get('remove')),
          ),
        ],
      ),
    );
  }
}
