import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/desktop_link_provider.dart';
import '../../services/lan_client.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/gradient_app_bar.dart';
import 'lan_connect.dart';
import 'lan_import_screen.dart';
import 'send_books_flow.dart';

/// 电脑联动：记住配对过的电脑，取书 / 发书集中在一页。
///
/// 连接本身复用 [connectToDesktop]（记住的电脑在线直接用，否则引导扫码），
/// 这里只负责展示状态和入口。
class DesktopLinkScreen extends ConsumerWidget {
  const DesktopLinkScreen({super.key});

  /// 电脑端 Olib 下载页（MindSet 项目页）。
  static const _desktopDownloadUrl =
      'https://mind.11xy.cn/projects/olib-%E7%94%B5%E8%84%91%E7%AB%AF';

  /// 打不开浏览器时退回复制链接，用户可以自己发到电脑上打开。
  Future<void> _openDownloadPage(
    BuildContext context,
    AppLocalizations l,
  ) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(_desktopDownloadUrl),
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException catch (e) {
      debugPrint('[DesktopLink] open download page failed: $e');
    }
    if (!opened && context.mounted) await _copyDownloadLink(context, l);
  }

  Future<void> _copyDownloadLink(
    BuildContext context,
    AppLocalizations l,
  ) async {
    await Clipboard.setData(const ClipboardData(text: _desktopDownloadUrl));
    AppToast.success(l.get('desktop_link_link_copied'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final link = ref.watch(desktopLinkProvider);
    final notifier = ref.read(desktopLinkProvider.notifier);

    Future<void> pair({bool fresh = false}) async {
      if (fresh) await notifier.forget();
      if (!context.mounted) return;
      final client = await connectToDesktop(
        context,
        title: l.get('desktop_link_title'),
      );
      if (client != null) await notifier.refresh();
    }

    /// 需要连接的操作：在线直接用，否则先走配对。
    Future<void> withClient(
      Future<void> Function(LanClient client) action,
    ) async {
      final client =
          link.client ??
          await connectToDesktop(context, title: l.get('desktop_link_title'));
      if (client == null || !context.mounted) return;
      await action(client);
      await notifier.refresh();
    }

    return Scaffold(
      appBar: GradientAppBar(title: l.get('desktop_link_title')),
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _StatusCard(
              state: link,
              onPair: () => pair(),
              onRepair: () => pair(fresh: true),
              onRetry: notifier.refresh,
            ),
            const SizedBox(height: 20),
            _ActionTile(
              icon: Icons.download_for_offline_outlined,
              title: l.get('lan_import_title'),
              subtitle: l.get('desktop_link_import_hint'),
              onTap: () => withClient(
                (c) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LanImportScreen(peer: c.peer),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.upload_file_outlined,
              title: l.get('desktop_link_send_books'),
              subtitle: l.get('desktop_link_send_books_hint'),
              onTap: () =>
                  withClient((c) => sendBooksToDesktop(context, ref, c)),
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.desktop_windows_outlined,
              title: l.get('desktop_link_get_app'),
              subtitle: l.get('desktop_link_get_app_hint'),
              onTap: () => _openDownloadPage(context, l),
              trailing: IconButton(
                tooltip: l.get('desktop_link_copy_link'),
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: () => _copyDownloadLink(context, l),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l.get('desktop_link_footer'),
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final DesktopLinkState state;
  final VoidCallback onPair;
  final VoidCallback onRepair;
  final VoidCallback onRetry;

  const _StatusCard({
    required this.state,
    required this.onPair,
    required this.onRepair,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final name = state.saved?.deviceName ?? '';

    final (
      IconData icon,
      Color color,
      String title,
      String? hint,
    ) = switch (state.status) {
      DesktopLinkStatus.none => (
        Icons.computer_outlined,
        cs.onSurfaceVariant,
        l.get('desktop_link_none'),
        l.get('desktop_link_none_hint'),
      ),
      DesktopLinkStatus.checking => (
        Icons.computer_outlined,
        cs.primary,
        l.get('desktop_link_checking'),
        null,
      ),
      DesktopLinkStatus.online => (
        Icons.laptop_chromebook_rounded,
        Colors.green,
        '${l.get('desktop_link_online')}${name.isEmpty ? '' : ' · $name'}',
        null,
      ),
      DesktopLinkStatus.offline => (
        Icons.portable_wifi_off_rounded,
        cs.error,
        '${l.get('desktop_link_offline')}${name.isEmpty ? '' : ' · $name'}',
        l.get('desktop_link_offline_hint'),
      ),
    };

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (state.status == DesktopLinkStatus.checking)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                else
                  Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: switch (state.status) {
                DesktopLinkStatus.none => [
                  FilledButton.icon(
                    onPressed: onPair,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: Text(l.get('desktop_link_pair')),
                  ),
                ],
                DesktopLinkStatus.checking => const [],
                DesktopLinkStatus.online => [
                  OutlinedButton(
                    onPressed: onRepair,
                    child: Text(l.get('desktop_link_repair')),
                  ),
                ],
                DesktopLinkStatus.offline => [
                  FilledButton.tonalIcon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l.get('retry')),
                  ),
                  OutlinedButton(
                    onPressed: onRepair,
                    child: Text(l.get('desktop_link_repair')),
                  ),
                ],
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// 默认为右箭头。
  final Widget? trailing;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(icon, color: cs.primary, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
