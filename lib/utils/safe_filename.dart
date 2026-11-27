/// 下载文件名清洗：把书名转成在 Android / iOS / Windows / macOS / Linux 上都能安全落盘的文件名。
///
/// 书名可能很长（合集书名常见数百字符），并夹带换行、零宽字符、路径分隔符等，
/// 直接拼文件名会超出单段 255 字节上限 / Windows MAX_PATH，或被文件系统拒绝。
/// 逻辑与 OlibTauri `src-tauri/src/safe_filename.rs` 保持一致。
library;

import 'dart:convert';

/// 书名部分最多保留的字符数（兼顾可读性与 MAX_PATH 限制）
const int _maxStemChars = 100;

/// 书名部分最多保留的 UTF-8 字节数（单段上限 255 字节，留出 id / 后缀 / `.part` 余量）
const int _maxStemBytes = 180;

/// 扩展名最长字符数
const int _maxExtChars = 10;

/// 文件系统非法字符与控制字符
final RegExp _invalidChars = RegExp(r'[/\\:*?"<>|\x00-\x1f\x7f]');

/// 不可见格式字符：软连字符、零宽、双向控制、BOM 等
bool _isInvisible(int r) =>
    r == 0x00AD ||
    (r >= 0x200B && r <= 0x200F) ||
    (r >= 0x202A && r <= 0x202E) ||
    (r >= 0x2060 && r <= 0x2069) ||
    r == 0xFEFF;

/// 截断/清洗后不应出现在结尾的字符（Windows 不允许结尾点和空格，其余是截断残留）
final RegExp _trailingJunk = RegExp(r'[ .,;\-_(\[（【，；]+$');

/// Windows 保留设备名（不区分大小写，带扩展名也不行）
const Set<String> _reservedNames = {
  'CON', 'PRN', 'AUX', 'NUL', //
  'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
  'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
};

/// 清洗书名部分（不含扩展名）；清洗后为空返回空串，由调用方决定兜底名。
String sanitizeFileStem(String title) {
  // 不可见字符直接丢弃（常夹在单词中间）；非法字符替换为空格避免单词粘连；空白折叠
  var stem = String.fromCharCodes(
    title.runes.where((r) => !_isInvisible(r)),
  ).replaceAll(_invalidChars, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  // 按字符数（rune）与 UTF-8 字节数双重上限截断，只在字符边界截
  final buffer = StringBuffer();
  var count = 0;
  var bytes = 0;
  for (final rune in stem.runes) {
    final ch = String.fromCharCode(rune);
    final len = utf8.encode(ch).length;
    if (count >= _maxStemChars || bytes + len > _maxStemBytes) break;
    buffer.write(ch);
    count++;
    bytes += len;
  }
  stem = buffer
      .toString()
      .replaceFirst(RegExp(r'^[. ]+'), '')
      .replaceFirst(_trailingJunk, '');
  if (stem.isEmpty) return '';

  final base = stem.split('.').first.toUpperCase();
  if (_reservedNames.contains(base)) return '_$stem';
  return stem;
}

/// 扩展名只保留 ASCII 字母数字并转小写
String sanitizeExtension(String extension) {
  final ext = extension.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  return ext.length > _maxExtChars ? ext.substring(0, _maxExtChars) : ext;
}
