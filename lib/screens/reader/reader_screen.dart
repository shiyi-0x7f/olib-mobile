import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_colors.dart';

class ReaderScreen extends StatefulWidget {
  final String url;
  final String title;

  const ReaderScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  static const bool _probeEnabled = bool.fromEnvironment('LITERA_PROBE');
  InAppWebViewController? _webViewController;
  double _progress = 0;
  bool _isLoading = true;

  // 按需开启的 Litera 资源耗时记录，地址只保留脱敏后的路由。
  final List<Map<String, dynamic>> _probeLog = [];
  final DateTime _probeStart = DateTime.now();

  static String _probeUrl(Object? value) {
    final uri = Uri.tryParse(value?.toString() ?? '');
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return '[non-http URL]';
    }
    final path = uri.pathSegments.map((segment) {
      if (RegExp(r'^[0-9]{1,10}$').hasMatch(segment)) return ':id';
      if (const {
        'api',
        'books',
        'quotes',
        'common-by-others',
      }.contains(segment)) {
        return segment;
      }
      return ':redacted';
    }).join('/');
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port/$path';
  }

  void _addProbe(Map<String, dynamic> entry) {
    if (!_probeEnabled) return;
    entry['t_ms'] = DateTime.now().difference(_probeStart).inMilliseconds;
    _probeLog.add(entry);
    if (kDebugMode) {
      debugPrint('[LITERA_PROBE] ${jsonEncode(entry)}');
    }
    if (mounted) setState(() {});
  }

  Future<void> _shareProbeLog() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/litera_probe_$ts.json');
      final payload = {
        'reader_url': _probeUrl(widget.url),
        'captured_at': DateTime.now().toIso8601String(),
        'entry_count': _probeLog.length,
        'entries': _probeLog,
      };
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Litera Probe Log (${_probeLog.length} entries)',
        text: '${_probeLog.length} 条资源记录',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('日志导出失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_probeEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_probeLog.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: '导出资源日志',
              icon: const Icon(Icons.ios_share),
              onPressed: _probeLog.isEmpty ? null : _shareProbeLog,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webViewController?.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              useWideViewPort: true,
              loadWithOverviewMode: true,
              supportZoom: true,
              builtInZoomControls: true,
              displayZoomControls: false,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              useOnLoadResource: _probeEnabled,
              userAgent:
                  'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
              });
              if (_probeEnabled) {
                _addProbe({
                  'kind': 'load_start',
                  'url': _probeUrl(url),
                });
              }
            },
            onLoadStop: (controller, url) {
              setState(() {
                _isLoading = false;
              });
              if (_probeEnabled) {
                _addProbe({
                  'kind': 'load_stop',
                  'url': _probeUrl(url),
                });
              }
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _progress = progress / 100;
              });
            },
            onLoadResource: _probeEnabled ? (controller, resource) {
              _addProbe({
                'kind': 'resource',
                'url': _probeUrl(resource.url),
                'initiator': resource.initiatorType,
                'duration_ms': resource.duration,
              });
            } : null,
            onReceivedError: (controller, request, error) {
              if (_probeEnabled) {
                _addProbe({
                  'kind': 'error',
                  'url': _probeUrl(request.url),
                  'type': error.type.toString(),
                });
              }
              debugPrint('WebView error: ${error.type}');
            },
          ),

          // Progress indicator
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

/// Arguments for ReaderScreen
class ReaderArgs {
  final String url;
  final String title;

  const ReaderArgs({
    required this.url,
    required this.title,
  });
}
