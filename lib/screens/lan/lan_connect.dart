import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/lan_client.dart';
import '../favorites/scanner_screen.dart';

/// 与电脑配对的统一入口：先弹步骤引导（电脑开「无线传书」→ 同一 Wi-Fi →
/// 扫码），支持「手动输入地址」备选；返回解析好的对端地址。
/// 用户取消返回 null；二维码/地址无效时已用 SnackBar 提示并返回 null。
Future<LanPeer?> promptDesktopPeer(
  BuildContext context, {
  required String title,
}) async {
  final l = AppLocalizations.of(context);

  // 步骤引导：告诉用户去电脑上做什么，再选择扫码或手动输入
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(l.get('lan_guide_body')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'manual'),
          child: Text(l.get('lan_guide_manual')),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, 'scan'),
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
          label: Text(l.get('lan_guide_scan')),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return null;

  String? raw;
  if (choice == 'manual') {
    raw = await _promptManualAddress(context, l);
  } else {
    final scanned = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerScreen(hint: l.get('lan_scan_hint')),
      ),
    );
    if (scanned is String) raw = scanned;
  }
  if (raw == null || raw.trim().isEmpty || !context.mounted) return null;

  final peer = LanPeer.tryParse(raw);
  if (peer == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.get('lan_invalid_qr'))));
    return null;
  }
  return peer;
}

/// 手动输入电脑地址（扫码不可用时的备选，如无摄像头/模拟器调试）。
Future<String?> _promptManualAddress(
    BuildContext context, AppLocalizations l) {
  final controller = TextEditingController(text: 'http://');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.get('lan_manual_title')),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          hintText: l.get('lan_manual_hint'),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l.get('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(l.get('lan_guide_connect')),
        ),
      ],
    ),
  );
}

/// 「发送到电脑」共用的连接流程：引导配对 → 确认对端是 Olib 桌面端 →
/// 返回已连接的 [LanClient]。失败时已用 SnackBar 提示并返回 null。
Future<LanClient?> connectToDesktop(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final peer = await promptDesktopPeer(
    context,
    title: l.get('lan_send_to_computer'),
  );
  if (peer == null || !context.mounted) return null;

  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text(l.get('lan_connecting')),
      duration: const Duration(seconds: 1),
    ),
  );

  final client = LanClient(peer);
  try {
    final info = await client.getInfo();
    if (!info.isOlibDesktop) {
      messenger.showSnackBar(SnackBar(content: Text(l.get('lan_not_olib'))));
      return null;
    }
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(l.get('lan_connect_failed'))),
    );
    return null;
  }
  return client;
}

/// 把 LAN 写端点的类型化异常翻译成用户可读文案。
String lanErrorMessage(AppLocalizations l, Object e) {
  if (e is LanAuthException) return l.get('lan_auth_required');
  if (e is LanFileTooLargeException) return l.get('lan_file_too_large');
  if (e is LanRejectedException) {
    final detail = e.detail;
    return detail == null || detail.isEmpty
        ? l.get('lan_rejected')
        : '${l.get('lan_rejected')}: $detail';
  }
  return '${l.get('error')}: $e';
}
