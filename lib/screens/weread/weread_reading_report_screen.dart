import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/weread_provider.dart';
import '../../services/weread/weread_models.dart';
import '../../utils/share_utils.dart';

/// Creates a local image from the user's reading statistics. No article or book
/// content is fetched for this report.
class WereadReadingReportScreen extends ConsumerStatefulWidget {
  const WereadReadingReportScreen({super.key});

  @override
  ConsumerState<WereadReadingReportScreen> createState() =>
      _WereadReadingReportScreenState();
}

class _WereadReadingReportScreenState
    extends ConsumerState<WereadReadingReportScreen> {
  final _posterKey = GlobalKey();
  final _nameController = TextEditingController();
  String _mode = 'weekly';
  bool _dark = false;
  bool _showBook = false;
  bool _sharing = false;
  late Future<ReadDataResponse> _report;

  @override
  void initState() {
    super.initState();
    _report = _load();
    _nameController.addListener(_refreshName);
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshName);
    _nameController.dispose();
    super.dispose();
  }

  void _refreshName() => setState(() {});

  Future<ReadDataResponse> _load() async {
    final api = ref.read(wereadApiProvider);
    if (api == null) throw StateError('Connect WeRead first');
    return api.readDataDetail(mode: _mode);
  }

  void _selectMode(String mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _report = _load();
    });
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await ShareUtils.captureAndShare(
        _posterKey,
        filePrefix: 'olib_weread_report',
      );
    } catch (error) {
      debugPrint('Failed to share WeRead report: ${error.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).get('weread_report_share_failed'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _duration(int seconds, AppLocalizations t) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0
        ? '$hours ${t.get('weread_hours')} $minutes ${t.get('weread_minutes')}'
        : '$minutes ${t.get('weread_minutes')}';
  }

  String _period(ReadDataResponse data, AppLocalizations t) {
    if (data.baseTime <= 0) return t.get('weread_report_period_current');
    final start = DateTime.fromMillisecondsSinceEpoch(data.baseTime * 1000);
    String date(DateTime value) =>
        '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';
    switch (_mode) {
      case 'weekly':
        return '${date(start)} — ${date(start.add(const Duration(days: 6)))}';
      case 'monthly':
        return '${start.year}.${start.month.toString().padLeft(2, '0')}';
      default:
        return '${start.year}';
    }
  }

  String? _topBookTitle(ReadDataResponse data) {
    if (data.readLongest == null || data.readLongest!.isEmpty) return null;
    final first = data.readLongest!.first;
    final info = first['book'] ?? first['albumInfo'];
    if (info is! Map) return null;
    final title = info['title']?.toString().trim();
    return title == null || title.isEmpty ? null : title;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.get('weread_report_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            t.get('weread_report_intro'),
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (mode, label) in [
                ('weekly', 'weread_report_week'),
                ('monthly', 'weread_report_month'),
                ('annually', 'weread_report_year'),
              ])
                ChoiceChip(
                  label: Text(t.get(label)),
                  selected: _mode == mode,
                  onSelected: (_) => _selectMode(mode),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<ReadDataResponse>(
            future: _report,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 280,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return SizedBox(
                  height: 280,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.get('weread_report_load_failed')),
                        TextButton(
                          onPressed: () => setState(() => _report = _load()),
                          child: Text(t.get('weread_retry')),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final data = snapshot.data!;
              final book = _topBookTitle(data);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RepaintBoundary(
                        key: _posterKey,
                        child: _poster(data, t, book),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _nameController,
                    maxLength: 24,
                    decoration: InputDecoration(
                      labelText: t.get('weread_report_name'),
                      hintText: t.get('weread_report_name_hint'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(t.get('weread_report_paper')),
                        selected: !_dark,
                        onSelected: (_) => setState(() => _dark = false),
                      ),
                      ChoiceChip(
                        label: Text(t.get('weread_report_night')),
                        selected: _dark,
                        onSelected: (_) => setState(() => _dark = true),
                      ),
                    ],
                  ),
                  if (book != null)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.get('weread_report_show_book')),
                      value: _showBook,
                      onChanged: (value) => setState(() => _showBook = value),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sharing ? null : _share,
                      icon: Icon(
                        _sharing
                            ? Icons.hourglass_top_rounded
                            : Icons.ios_share_rounded,
                      ),
                      label: Text(t.get('weread_report_share')),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.get('weread_report_share_hint'),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _poster(ReadDataResponse data, AppLocalizations t, String? book) {
    final ink = _dark ? const Color(0xFFF7F0DF) : const Color(0xFF173F32);
    final muted = _dark ? const Color(0xFFB9C5B9) : const Color(0xFF617469);
    final background = _dark
        ? const Color(0xFF153D32)
        : const Color(0xFFF8F4E9);
    final accent = _dark ? const Color(0xFFE2C684) : const Color(0xFFBA874D);
    final entries = (data.readTimes ?? const <String, int>{}).entries.toList()
      ..sort(
        (a, b) =>
            (int.tryParse(a.key) ?? 0).compareTo(int.tryParse(b.key) ?? 0),
      );
    final values = entries.map((entry) => entry.value).toList();
    final maxValue = values.fold<int>(1, math.max);
    final displayName = _nameController.text.trim();
    return Container(
      width: 360,
      height: 480,
      padding: const EdgeInsets.fromLTRB(27, 27, 27, 22),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: .42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_stories_rounded, size: 22, color: accent),
              const SizedBox(width: 7),
              Text(
                'OLIB  /  READING',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 27),
          Text(
            displayName.isEmpty ? t.get('weread_report_heading') : displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${t.get('weread_report_reading')}  ·  ${_period(data, t)}',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 28),
          Text(
            t.get('weread_report_total'),
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 3),
          Text(
            _duration(data.totalReadTime, t),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              if (data.readDays != null) ...[
                _metric(
                  '${data.readDays}',
                  t.get('weread_read_days'),
                  ink,
                  muted,
                ),
                const SizedBox(width: 26),
              ],
              if (data.dayAverageReadTime != null)
                _metric(
                  _duration(data.dayAverageReadTime!, t),
                  t.get('weread_daily_avg'),
                  ink,
                  muted,
                ),
            ],
          ),
          const Spacer(),
          if (values.isNotEmpty) ...[
            Text(
              t.get('weread_report_trend'),
              style: TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 66,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: values
                    .map(
                      (value) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: Container(
                            height: 4 + 62 * value / maxValue,
                            decoration: BoxDecoration(
                              color: value > 0
                                  ? accent
                                  : muted.withValues(alpha: .24),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_showBook && book != null) ...[
            Text(
              '${t.get('weread_report_top_book')}  $book',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: ink),
            ),
            const SizedBox(height: 9),
          ],
          Divider(color: muted.withValues(alpha: .25)),
          const SizedBox(height: 6),
          Text(
            t.get('weread_report_credit'),
            style: TextStyle(fontSize: 10, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label, Color ink, Color muted) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
      ),
      Text(label, style: TextStyle(fontSize: 11, color: muted)),
    ],
  );
}
