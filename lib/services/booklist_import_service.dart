import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/books_provider.dart';
import 'booklist_share_codec.dart';

class BooklistImportResult {
  final int imported;
  final int skipped;
  final int failed;
  final int total;

  const BooklistImportResult({
    required this.imported,
    required this.skipped,
    required this.failed,
    required this.total,
  });
}

class BooklistImportService {
  final Ref _ref;
  BooklistImportService(this._ref);

  /// 尝试解析任意输入并把书加入收藏，返回汇总。
  Future<BooklistImportResult?> importFromRaw(String raw) async {
    final data = BooklistShareCodec.tryDecode(raw);
    if (data == null || data.entries.isEmpty) return null;
    return importFromData(data);
  }

  Future<BooklistImportResult> importFromData(BooklistShareData data) async {
    final notifier = _ref.read(savedBooksProvider.notifier);
    final existing = (_ref.read(savedBooksProvider).valueOrNull ?? [])
        .map((b) => b.id.toString())
        .toSet();

    int imported = 0, skipped = 0, failed = 0;
    for (final entry in data.entries) {
      if (existing.contains(entry.id)) {
        skipped++;
        continue;
      }
      if (int.tryParse(entry.id) == null) {
        failed++;
        continue;
      }
      final ok = await notifier.saveBook(entry.id);
      if (ok) {
        imported++;
        existing.add(entry.id);
      } else {
        failed++;
      }
    }

    return BooklistImportResult(
      imported: imported,
      skipped: skipped,
      failed: failed,
      total: data.entries.length,
    );
  }
}

final booklistImportServiceProvider = Provider<BooklistImportService>((ref) {
  return BooklistImportService(ref);
});
