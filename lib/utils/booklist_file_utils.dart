import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/booklist_share_codec.dart';

class BooklistFileUtils {
  /// 把书单写入临时 JSON 并调起系统分享。
  static Future<void> exportAndShare(BooklistShareData data) async {
    final json = BooklistShareCodec.encodeJsonFile(data);
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/olib_booklist_$ts.json');
    await file.writeAsString(json);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      text: 'Olib booklist (${data.entries.length} books)',
    );
  }

  /// 让用户选一个 JSON 文件并解析。
  static Future<BooklistShareData?> pickAndParse() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],


      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final f = result.files.first;
    String content;
    if (f.bytes != null) {
      content = utf8.decode(f.bytes!);
    } else if (f.path != null) {
      content = await File(f.path!).readAsString();
    } else {
      return null;
    }
    return BooklistShareCodec.tryDecode(content);
  }
}
