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
  InAppWebViewController? _webViewController;
  double _progress = 0;
  bool _isLoading = true;

  // ── Litera 侦察日志 ──
  // 仅用于一次性勘测 Litera 的请求模式（URL/方法/Content-Type/响应大小）。
  // 后续做离线缓存功能前需先看懂它的内容投递方式。
  final List<Map<String, dynamic>> _probeLog = [];
  final DateTime _probeStart = DateTime.now();

  void _addProbe(Map<String, dynamic> entry) {
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
        'reader_url': widget.url,
        'book_title': widget.title,
        'captured_at': DateTime.now().toIso8601String(),
        'entry_count': _probeLog.length,
        'entries': _probeLog,
      };
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Litera Probe Log (${_probeLog.length} entries)',
        text: '${_probeLog.length} 条请求记录，开本：${widget.title}',
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
          // ── 侦察计数 ──
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
            tooltip: '导出侦察日志',
            icon: const Icon(Icons.ios_share),
            onPressed: _probeLog.isEmpty ? null : _shareProbeLog,
          ),
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
              useShouldOverrideUrlLoading: true,
              // Android：开启请求拦截以拿到 method/headers
              useShouldInterceptRequest: true,
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
              _addProbe({
                'kind': 'load_start',
                'url': url?.toString(),
              });
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isLoading = false;
              });
              _addProbe({
                'kind': 'load_stop',
                'url': url?.toString(),
              });
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _progress = progress / 100;
              });
            },
            // 跨平台资源加载日志（Android + iOS 都触发）
            onLoadResource: (controller, resource) {
              _addProbe({
                'kind': 'resource',
                'url': resource.url.toString(),
                'initiator': resource.initiatorType,
                'duration_ms': resource.duration,
              });
            },
            // Android 专属：返回 null 不拦截，仅日志
            shouldInterceptRequest: (controller, request) async {
              _addProbe({
                'kind': 'request',
                'url': request.url.toString(),
                'method': request.method,
                'headers': request.headers,
                'is_for_main_frame': request.isForMainFrame,
              });
              return null;
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              return NavigationActionPolicy.ALLOW;
            },
            onReceivedError: (controller, request, error) {
              _addProbe({
                'kind': 'error',
                'url': request.url.toString(),
                'description': error.description,
              });
              debugPrint('WebView error: ${error.description}');
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
