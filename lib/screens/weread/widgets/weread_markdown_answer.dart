import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';

/// A small Markdown renderer for the text returned by WeRead AI.
/// It keeps partial streaming responses readable, including unfinished fences.
class WereadMarkdownAnswer extends StatefulWidget {
  final String markdown;

  const WereadMarkdownAnswer({super.key, required this.markdown});

  @override
  State<WereadMarkdownAnswer> createState() => _WereadMarkdownAnswerState();
}

class _WereadMarkdownAnswerState extends State<WereadMarkdownAnswer> {
  final _links = <Uri, TapGestureRecognizer>{};
  static final _heading = RegExp(r'^\s{0,3}(#{1,4})\s+(.+)$');
  static final _list = RegExp(r'^(\s{0,6})([-*+]|\d+[.)])\s+(.+)$');
  static final _rule = RegExp(r'^\s{0,3}(?:-{3,}|\*{3,}|_{3,})\s*$');
  static final _tableRule = RegExp(r'^:?-{3,}:?$');

  @override
  void dispose() {
    for (final link in _links.values) {
      link.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bodyStyle =
        theme.textTheme.bodyLarge?.copyWith(
          fontSize: 15,
          height: 1.7,
          color: cs.onSurface,
        ) ??
        TextStyle(fontSize: 15, height: 1.7, color: cs.onSurface);
    final lines = widget.markdown.replaceAll('\r\n', '\n').split('\n');
    final blocks = <Widget>[];
    var index = 0;

    while (index < lines.length) {
      final line = lines[index];
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        index++;
        continue;
      }

      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        final fence = trimmed.substring(0, 3);
        final language = trimmed.substring(3).trim();
        final code = <String>[];
        index++;
        while (index < lines.length && !lines[index].trim().startsWith(fence)) {
          code.add(lines[index]);
          index++;
        }
        if (index < lines.length) index++;
        blocks.add(_codeBlock(code.join('\n'), language, cs));
        continue;
      }

      final heading = _heading.firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        blocks.add(_headingBlock(heading.group(2)!, level, bodyStyle, cs));
        index++;
        continue;
      }

      if (_rule.hasMatch(line)) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Divider(color: cs.outlineVariant),
          ),
        );
        index++;
        continue;
      }

      if (trimmed.startsWith('>')) {
        final quote = <String>[];
        while (index < lines.length &&
            lines[index].trimLeft().startsWith('>')) {
          quote.add(lines[index].trimLeft().replaceFirst(RegExp(r'^>\s?'), ''));
          index++;
        }
        blocks.add(_quoteBlock(quote.join('\n'), bodyStyle, cs));
        continue;
      }

      if (_isTable(lines, index)) {
        final rows = <List<String>>[_tableCells(lines[index])];
        index += 2;
        while (index < lines.length && lines[index].trim().startsWith('|')) {
          rows.add(_tableCells(lines[index]));
          index++;
        }
        blocks.add(_tableBlock(rows, bodyStyle, cs));
        continue;
      }

      if (_list.hasMatch(line)) {
        final items = <RegExpMatch>[];
        while (index < lines.length) {
          final match = _list.firstMatch(lines[index]);
          if (match == null) break;
          items.add(match);
          index++;
        }
        blocks.add(_listBlock(items, bodyStyle, cs));
        continue;
      }

      final paragraph = <String>[line.trim()];
      index++;
      while (index < lines.length &&
          lines[index].trim().isNotEmpty &&
          !_startsBlock(lines, index)) {
        paragraph.add(lines[index].trim());
        index++;
      }
      blocks.add(_richText(paragraph.join('\n'), bodyStyle));
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            blocks[i],
          ],
        ],
      ),
    );
  }

  bool _startsBlock(List<String> lines, int index) {
    final text = lines[index].trim();
    return text.startsWith('```') ||
        text.startsWith('~~~') ||
        text.startsWith('>') ||
        _heading.hasMatch(lines[index]) ||
        _list.hasMatch(lines[index]) ||
        _rule.hasMatch(lines[index]) ||
        _isTable(lines, index);
  }

  bool _isTable(List<String> lines, int index) {
    if (index + 1 >= lines.length || !lines[index].contains('|')) return false;
    final cells = _tableCells(lines[index + 1]);
    return cells.length > 1 && cells.every((cell) => _tableRule.hasMatch(cell));
  }

  List<String> _tableCells(String line) {
    var text = line.trim();
    if (text.startsWith('|')) text = text.substring(1);
    if (text.endsWith('|')) text = text.substring(0, text.length - 1);
    return text.split('|').map((cell) => cell.trim()).toList();
  }

  Widget _headingBlock(String text, int level, TextStyle body, ColorScheme cs) {
    final size = switch (level) {
      1 => 23.0,
      2 => 19.0,
      _ => 16.5,
    };
    return Padding(
      padding: EdgeInsets.only(top: level == 1 ? 8 : 4),
      child: _richText(
        text,
        body.copyWith(
          fontSize: size,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: level == 1 ? cs.primary : cs.onSurface,
        ),
      ),
    );
  }

  Widget _quoteBlock(String text, TextStyle body, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      child: _richText(text, body.copyWith(color: cs.onSurfaceVariant)),
    );
  }

  Widget _listBlock(List<RegExpMatch> items, TextStyle body, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: EdgeInsets.only(
              left: (item.group(1)?.length ?? 0) * 2.5,
              bottom: 7,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 27,
                  child: Text(
                    RegExp(r'^\d').hasMatch(item.group(2)!)
                        ? item.group(2)!
                        : '•',
                    style: body.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(child: _richText(item.group(3)!, body)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tableBlock(List<List<String>> rows, TextStyle body, ColorScheme cs) {
    final columns = rows.first.length;
    final headers = rows.first;
    final data = rows.skip(1);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(cs.surfaceContainer),
          horizontalMargin: 14,
          columnSpacing: 24,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 96,
          columns: [
            for (final header in headers)
              DataColumn(
                label: _richText(
                  header,
                  body.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
          ],
          rows: [
            for (final row in data)
              DataRow(
                cells: [
                  for (var i = 0; i < columns; i++)
                    DataCell(
                      _richText(
                        i < row.length ? row[i] : '',
                        body.copyWith(fontSize: 13),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _codeBlock(String code, String language, ColorScheme cs) {
    final t = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: cs.inverseSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language.isEmpty ? t.get('weread_ask_code') : language,
                    style: TextStyle(
                      color: cs.onInverseSurface.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: t.get('weread_ask_copy_code'),
                  onPressed: () => _copy(code),
                  icon: Icon(
                    Icons.copy_rounded,
                    size: 17,
                    color: cs.onInverseSurface,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
            child: Text(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.55,
                color: cs.onInverseSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _richText(String text, TextStyle style) {
    return Text.rich(TextSpan(children: _inline(text, style)), style: style);
  }

  List<InlineSpan> _inline(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isNotEmpty) {
        spans.add(TextSpan(text: buffer.toString()));
        buffer.clear();
      }
    }

    var index = 0;
    while (index < text.length) {
      if (text[index] == '\\' && index + 1 < text.length) {
        buffer.write(text[index + 1]);
        index += 2;
        continue;
      }
      if (text[index] == '[') {
        final labelEnd = text.indexOf('](', index + 1);
        final urlEnd = labelEnd < 0 ? -1 : text.indexOf(')', labelEnd + 2);
        if (urlEnd > labelEnd) {
          final uri = Uri.tryParse(text.substring(labelEnd + 2, urlEnd));
          if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
            flush();
            final recognizer = _links.putIfAbsent(
              uri,
              () => TapGestureRecognizer()..onTap = () => _open(uri),
            );
            spans.add(
              TextSpan(
                text: text.substring(index + 1, labelEnd),
                style: style.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
                recognizer: recognizer,
              ),
            );
            index = urlEnd + 1;
            continue;
          }
        }
      }
      if (text[index] == '`') {
        final end = text.indexOf('`', index + 1);
        if (end > index + 1) {
          flush();
          spans.add(
            TextSpan(
              text: text.substring(index + 1, end),
              style: style.copyWith(
                fontFamily: 'monospace',
                fontSize: (style.fontSize ?? 15) - 1,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              ),
            ),
          );
          index = end + 1;
          continue;
        }
      }
      var formatted = false;
      for (final marker in ['**', '__', '~~', '*', '_']) {
        if (!text.startsWith(marker, index)) continue;
        final end = text.indexOf(marker, index + marker.length);
        if (end <= index + marker.length) continue;
        flush();
        final nestedStyle = marker == '~~'
            ? style.copyWith(decoration: TextDecoration.lineThrough)
            : marker == '**' || marker == '__'
            ? style.copyWith(fontWeight: FontWeight.w700)
            : style.copyWith(fontStyle: FontStyle.italic);
        spans.add(
          TextSpan(
            style: nestedStyle,
            children: _inline(
              text.substring(index + marker.length, end),
              nestedStyle,
            ),
          ),
        );
        index = end + marker.length;
        formatted = true;
        break;
      }
      if (formatted) continue;
      buffer.write(text[index]);
      index++;
    }
    flush();
    return spans;
  }

  Future<void> _copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).get('weread_ask_copied')),
        ),
      );
    } catch (error) {
      debugPrint('Could not copy AI answer code: ${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).get('weread_ask_copy_failed'),
          ),
        ),
      );
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (error) {
      debugPrint('Could not open AI answer link: ${error.runtimeType}');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).get('weread_ask_link_failed'),
        ),
      ),
    );
  }
}
