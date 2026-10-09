import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/weread_provider.dart';
import '../../services/weread/weread_mobile_client.dart';
import 'weread_mobile_hub_screen.dart';
import 'widgets/weread_markdown_answer.dart';

class WereadAskBookScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String title;

  const WereadAskBookScreen({
    super.key,
    required this.bookId,
    required this.title,
  });

  @override
  ConsumerState<WereadAskBookScreen> createState() =>
      _WereadAskBookScreenState();
}

class _WereadAskBookScreenState extends ConsumerState<WereadAskBookScreen> {
  final _question = TextEditingController();
  CancelToken? _cancel;
  late Future<bool> _connected;
  late Future<List<String>> _suggestions;
  String _answer = '';
  String? _error;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    final mobile = ref.read(wereadMobileClientProvider);
    _connected = mobile.isConnected;
    _suggestions = _connected.then(
      (value) => value ? mobile.suggestions(widget.bookId) : <String>[],
    );
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _question.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WereadMobileHubScreen()),
    );
    if (!mounted) return;
    setState(() {
      final mobile = ref.read(wereadMobileClientProvider);
      _connected = mobile.isConnected;
      _suggestions = _connected.then(
        (value) => value ? mobile.suggestions(widget.bookId) : <String>[],
      );
    });
  }

  Future<void> _ask([String? suggestion]) async {
    final query = (suggestion ?? _question.text).trim();
    if (query.isEmpty || _asking) return;
    _question.text = query;
    final token = CancelToken();
    _cancel = token;
    setState(() {
      _asking = true;
      _error = null;
      _answer = '';
    });
    try {
      final answer = await ref
          .read(wereadMobileClientProvider)
          .askBook(
            widget.bookId,
            query,
            cancelToken: token,
            onProgress: (text) {
              if (mounted) setState(() => _answer = text);
            },
          );
      if (mounted) setState(() => _answer = answer);
    } catch (error) {
      if (mounted && !token.isCancelled) {
        setState(
          () => _error = error is WereadMobileException
              ? error.message
              : 'Could not answer: ${error.runtimeType}',
        );
      }
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _copyAnswer() async {
    try {
      await Clipboard.setData(ClipboardData(text: _answer));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).get('weread_ask_copied')),
        ),
      );
    } catch (error) {
      debugPrint('Could not copy WeRead AI answer: ${error.runtimeType}');
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.get('weread_ask_title'))),
      body: FutureBuilder<bool>(
        future: _connected,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.smart_toy_outlined, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      t.get('weread_ask_connect_hint'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _connect,
                      child: Text(t.get('weread_mobile_scan')),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                t.get('weread_ask_intro'),
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              FutureBuilder<List<String>>(
                future: _suggestions,
                builder: (context, suggestions) {
                  final values = suggestions.data ?? const <String>[];
                  if (values.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.get('weread_ask_suggestions'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final value in values.take(6))
                            ActionChip(
                              label: Text(value),
                              onPressed: _asking ? null : () => _ask(value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
              TextField(
                controller: _question,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: t.get('weread_ask_placeholder'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _asking ? null : () => _ask(),
                icon: const Icon(Icons.send_rounded),
                label: Text(t.get('weread_ask_send')),
              ),
              if (_asking) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
                TextButton(
                  onPressed: () => _cancel?.cancel(),
                  child: Text(t.get('weread_ask_cancel')),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: TextStyle(color: cs.error)),
              ],
              if (_answer.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cs.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: cs.primary,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t.get('weread_ask_answer'),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (_asking)
                              Text(
                                t.get('weread_ask_writing'),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: cs.primary),
                              ),
                            IconButton(
                              tooltip: t.get('weread_ask_copy_answer'),
                              onPressed: _copyAnswer,
                              icon: const Icon(
                                Icons.copy_all_rounded,
                                size: 19,
                              ),
                            ),
                          ],
                        ),
                        Divider(color: cs.outlineVariant, height: 20),
                        WereadMarkdownAnswer(markdown: _answer),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                t.get('weread_ask_disclaimer'),
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }
}
