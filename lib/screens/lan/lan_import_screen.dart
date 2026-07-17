import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/download_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/lan_client.dart';
import '../../theme/app_colors.dart';

/// 从电脑导入（LAN 取书）：扫桌面「无线传书」二维码进入。
/// 流程：GET /api/info 确认对端 → GET /api/files 列表 → 勾选下载，
/// 落盘与下载历史复用 download_provider（presetUrl 直连下载）。
class LanImportScreen extends ConsumerStatefulWidget {
  final LanPeer peer;

  const LanImportScreen({super.key, required this.peer});

  @override
  ConsumerState<LanImportScreen> createState() => _LanImportScreenState();
}

enum _Phase { connecting, error, ready }

class _LanImportScreenState extends ConsumerState<LanImportScreen> {
  late final LanClient _client = LanClient(widget.peer);

  _Phase _phase = _Phase.connecting;
  String? _errorKey; // l10n key，build 时翻译
  LanPeerInfo? _info;
  List<LanFile> _files = const [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _phase = _Phase.connecting;
      _errorKey = null;
    });

    try {
      final info = await _client.getInfo();
      if (!info.isOlibDesktop) {
        setState(() {
          _phase = _Phase.error;
          _errorKey = 'lan_not_olib';
        });
        return;
      }
      final files = await _client.listFiles();
      if (!mounted) return;
      setState(() {
        _info = info;
        _files = files;
        _phase = _Phase.ready;
      });
    } catch (e) {
      debugPrint('[LanImport] connect failed: $e');
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorKey = 'lan_connect_failed';
      });
    }
  }

  /// LAN 文件没有 z-lib 书目 ID，用文件名生成稳定的合成 ID，
  /// 供 download_provider 的任务去重与下载历史键使用。
  Book _toBook(LanFile f) {
    final dot = f.name.lastIndexOf('.');
    final title = dot > 0 ? f.name.substring(0, dot) : f.name;
    return Book(
      id: f.name.hashCode.abs(),
      title: title,
      extension: f.extension.isEmpty ? null : f.extension,
      filesize: f.size,
    );
  }

  void _downloadSelected(AppLocalizations l) {
    final notifier = ref.read(downloadProvider.notifier);
    final files = _files.where((f) => _selected.contains(f.name));
    var count = 0;
    for (final f in files) {
      notifier.startDownload(_toBook(f), presetUrl: _client.downloadUrl(f.name));
      count++;
    }
    if (count == 0) return;

    setState(() => _selected.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l.get('lan_download_started').replaceAll('%d', '$count'),
        ),
        action: SnackBarAction(
          label: l.get('lan_view_downloads'),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.downloads),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.get('lan_import_title')),
        actions: [
          if (_phase == _Phase.ready && _files.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selected.length == _files.length) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(_files.map((f) => f.name));
                  }
                });
              },
              child: Text(l.get('select_all')),
            ),
        ],
      ),
      body: switch (_phase) {
        _Phase.connecting => const Center(child: CircularProgressIndicator()),
        _Phase.error => _buildError(l, cs),
        _Phase.ready => _buildFileList(l, cs),
      },
      bottomNavigationBar: _phase == _Phase.ready && _files.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed:
                      _selected.isEmpty ? null : () => _downloadSelected(l),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    l
                        .get('lan_download_selected')
                        .replaceAll('%d', '${_selected.length}'),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildError(AppLocalizations l, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.computer_outlined, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              l.get(_errorKey ?? 'lan_connect_failed'),
              style: TextStyle(fontSize: 15, color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: _connect,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l.get('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList(AppLocalizations l, ColorScheme cs) {
    if (_files.isEmpty) {
      return Center(
        child: Text(
          l.get('lan_empty'),
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    return Column(
      children: [
        // 对端信息条
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.primary.withValues(alpha: 0.06),
          child: Row(
            children: [
              const Icon(Icons.laptop_mac_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_info?.deviceName ?? ''} · ${_files.length}',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _files.length,
            itemBuilder: (_, i) {
              final f = _files[i];
              final checked = _selected.contains(f.name);
              return CheckboxListTile(
                value: checked,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(_formatSize(f.size)),
                secondary: _extBadge(f.extension, cs),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selected.add(f.name);
                    } else {
                      _selected.remove(f.name);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _extBadge(String ext, ColorScheme cs) {
    if (ext.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        ext.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
  }
}
