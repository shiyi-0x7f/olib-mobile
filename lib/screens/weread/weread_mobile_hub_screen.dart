import 'dart:io';

import 'package:dio/dio.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/books_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/weread_provider.dart';
import '../../services/weread/weread_mobile_client.dart';
import '../../utils/share_utils.dart';

/// WeRead account connection and personal book import.
class WereadMobileHubScreen extends ConsumerStatefulWidget {
  final String? initialFilePath;

  const WereadMobileHubScreen({super.key, this.initialFilePath});

  @override
  ConsumerState<WereadMobileHubScreen> createState() =>
      _WereadMobileHubScreenState();
}

class _WereadMobileHubScreenState extends ConsumerState<WereadMobileHubScreen> {
  final _qrShareKey = GlobalKey();
  late Future<bool> _connected;
  CancelToken? _loginCancel;
  CancelToken? _uploadCancel;
  WereadMobileQr? _qr;
  String _loginStatus = '';
  File? _file;
  String? _fileName;
  double? _progress;
  bool _uploading = false;
  String? _message;
  WereadImportResult? _result;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _connected = ref.read(wereadMobileClientProvider).isConnected;
    if (widget.initialFilePath != null) {
      _file = File(widget.initialFilePath!);
      _fileName = widget.initialFilePath!.replaceAll('\\', '/').split('/').last;
    }
  }

  @override
  void dispose() {
    _loginCancel?.cancel();
    _uploadCancel?.cancel();
    super.dispose();
  }

  Future<void> _startLogin() async {
    _loginCancel?.cancel();
    final token = CancelToken();
    _loginCancel = token;
    setState(() {
      _qr = null;
      _message = null;
      _loginStatus = 'loading';
    });
    final mobile = ref.read(wereadMobileClientProvider);
    try {
      final qr = await mobile.requestQr(cancelToken: token);
      if (!mounted || token.isCancelled) return;
      setState(() {
        _qr = qr;
        _loginStatus = 'waiting';
      });
      await mobile.waitForQr(
        qr,
        cancelToken: token,
        onStatus: (status) {
          if (mounted) setState(() => _loginStatus = status);
        },
      );
      if (!mounted) return;
      setState(() {
        _qr = null;
        _connected = Future.value(true);
        _loginStatus = '';
      });
      ref.read(wereadConnectionProvider.notifier).setConnected(true);
    } catch (error) {
      if (!mounted || token.isCancelled) return;
      setState(() {
        _qr = null;
        _loginStatus = '';
        _message = error is WereadMobileException
            ? error.message
            : 'QR login failed';
      });
    }
  }

  Future<void> _shareQrImage() async {
    if (_qr == null) return;
    try {
      await ShareUtils.captureAndShare(
        _qrShareKey,
        filePrefix: 'olib_weread_login',
      );
    } catch (error) {
      debugPrint('Could not share WeChat QR: ${error.runtimeType}');
      if (mounted) {
        setState(
          () => _message = AppLocalizations.of(
            context,
          ).get('weread_mobile_share_failed'),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    _loginCancel?.cancel();
    try {
      await ref.read(wereadMobileClientProvider).disconnect();
      ref.read(wereadConnectionProvider.notifier).setConnected(false);
      if (mounted) {
        setState(() {
          _connected = Future.value(false);
          _qr = null;
          _message = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Could not disconnect: ${error.runtimeType}');
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['epub', 'pdf', 'mobi', 'txt', 'azw3'],
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      if (picked.path == null) {
        setState(() => _message = 'The selected file is unavailable');
        return;
      }
      setState(() {
        _file = File(picked.path!);
        _fileName = picked.name;
        _message = null;
        _result = null;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = 'Could not select file: ${error.runtimeType}',
        );
      }
    }
  }

  Future<void> _pickFromShelf() async {
    final t = AppLocalizations.of(context);
    await ref.read(downloadProvider.notifier).ready;
    if (!mounted) return;
    if (ref.read(savedBooksProvider).isLoading) {
      await ref.read(savedBooksProvider.notifier).loadSavedBooks();
      if (!mounted) return;
    }
    if (ref.read(savedBooksProvider).hasError) {
      setState(() => _message = t.get('weread_import_shelf_error'));
      return;
    }
    final saved = ref.read(savedBooksProvider).valueOrNull ?? [];
    final savedIds = saved.map((book) => book.id.toString()).toSet();
    final candidates = ref
        .read(downloadProvider)
        .where(
          (task) =>
              task.status == DownloadStatus.completed &&
              task.filePath != null &&
              savedIds.contains(task.book.id.toString()),
        )
        .toList();
    final choice = await showModalBottomSheet<DownloadTask>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t.get('weread_import_shelf_title'),
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: candidates.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            t.get('weread_import_shelf_empty'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final task = candidates[index];
                          return ListTile(
                            leading: const Icon(Icons.menu_book_outlined),
                            title: Text(
                              task.book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              task.book.author ??
                                  task.filePath!
                                      .replaceAll('\\', '/')
                                      .split('/')
                                      .last,
                            ),
                            onTap: () => Navigator.of(sheetContext).pop(task),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final path = choice.filePath!;
    if (!await File(path).exists()) {
      if (mounted) {
        setState(() => _message = t.get('weread_import_file_missing'));
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _file = File(path);
      _fileName = path.replaceAll('\\', '/').split('/').last;
      _message = null;
      _result = null;
    });
  }

  Future<void> _import() async {
    final file = _file;
    final name = _fileName;
    if (file == null || name == null || _uploading) return;
    final token = CancelToken();
    _uploadCancel = token;
    setState(() {
      _uploading = true;
      _progress = 0;
      _message = null;
      _result = null;
    });
    try {
      final result = await ref
          .read(wereadMobileClientProvider)
          .importBook(
            file,
            name,
            cancelToken: token,
            onProgress: (sent, total) {
              if (mounted && total > 0) {
                setState(() => _progress = sent / total);
              }
            },
          );
      if (mounted) {
        setState(() {
          _result = result;
          _message = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is WereadMobileException
              ? error.message
              : 'Import failed: ${error.runtimeType}',
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openImported() async {
    final uri = _result?.deepLink;
    if (uri == null) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: uri.toString(),
          package: 'com.tencent.weread',
        ).launch();
        return;
      }
      if (await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      )) {
        return;
      }
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (error) {
      debugPrint('Failed to open imported WeRead book: ${error.runtimeType}');
    }
    if (mounted) {
      setState(() => _message = 'Could not open WeRead');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.get('weread_mobile_title'))),
      body: !_supported
          ? Center(child: Text(t.get('weread_mobile_platform')))
          : FutureBuilder<bool>(
              future: _connected,
              builder: (context, snapshot) {
                if (!snapshot.hasData && !snapshot.hasError) {
                  return const Center(child: CircularProgressIndicator());
                }
                final connected = snapshot.data == true;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
                  children: [
                    Text(
                      t.get('weread_mobile_intro'),
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    if (connected) ...[
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.verified_user_outlined),
                          title: Text(t.get('weread_mobile_connected')),
                          subtitle: Text(t.get('weread_mobile_account_hint')),
                          trailing: TextButton(
                            onPressed: _uploading ? null : _disconnect,
                            child: Text(t.get('weread_mobile_disconnect')),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        t.get('weread_import_title'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        t.get('weread_import_hint'),
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.tonalIcon(
                        onPressed: _uploading ? null : _pickFromShelf,
                        icon: const Icon(Icons.bookmarks_outlined),
                        label: Text(t.get('weread_import_choose_shelf')),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickFile,
                        icon: const Icon(Icons.attach_file_rounded),
                        label: Text(t.get('weread_import_choose')),
                      ),
                      if (_fileName != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _fileName!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _uploading ? null : _import,
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: Text(t.get('weread_import_start')),
                        ),
                      ],
                      if (_uploading) ...[
                        const SizedBox(height: 14),
                        LinearProgressIndicator(value: _progress),
                        TextButton(
                          onPressed: () => _uploadCancel?.cancel(),
                          child: Text(t.get('weread_import_cancel')),
                        ),
                      ],
                      if (_result != null) ...[
                        const SizedBox(height: 12),
                        Card(
                          color: cs.primaryContainer,
                          child: ListTile(
                            title: Text(t.get('weread_import_success')),
                            subtitle: Text(_fileName ?? ''),
                            trailing: const Icon(Icons.open_in_new_rounded),
                            onTap: _openImported,
                          ),
                        ),
                      ],
                    ] else ...[
                      Text(
                        t.get('weread_mobile_scan_intro'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _loginStatus == 'loading'
                            ? null
                            : _startLogin,
                        icon: const Icon(Icons.qr_code_rounded),
                        label: Text(t.get('weread_mobile_scan')),
                      ),
                      if (_qr != null) ...[
                        const SizedBox(height: 18),
                        Center(
                          child: RepaintBoundary(
                            key: _qrShareKey,
                            child: ColoredBox(
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: QrImageView(
                                  data: _qr!.confirmUrl,
                                  size: 220,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            t.get(
                              _loginStatus == 'scanned'
                                  ? 'weread_mobile_scanned'
                                  : 'weread_mobile_waiting',
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _shareQrImage,
                          icon: const Icon(Icons.share_outlined),
                          label: Text(t.get('weread_mobile_share_qr')),
                        ),
                        Text(
                          t.get('weread_mobile_same_device_hint'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Text(_message!, style: TextStyle(color: cs.error)),
                    ],
                  ],
                );
              },
            ),
    );
  }
}
