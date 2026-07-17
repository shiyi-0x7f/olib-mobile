import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/weread_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'section_header.dart';
import 'settings_card.dart';

/// 设置页：微信读书 API Key 配置 section
class WereadSettingsSection extends ConsumerWidget {
  const WereadSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKey = ref.watch(wereadApiKeyProvider);
    final isConfigured = apiKey != null && apiKey.isNotEmpty;
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.menu_book_rounded,
          title: t.get('weread'),
        ),
        SettingsCard(
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isConfigured
                        ? Colors.green.withValues(alpha: 0.12)
                        : cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isConfigured
                        ? Icons.check_circle_outline
                        : Icons.key_rounded,
                    color: isConfigured ? Colors.green : cs.primary,
                    size: 20,
                  ),
                ),
                title: Text(t.get('weread_api_key')),
                subtitle: Text(
                  isConfigured
                      ? '${apiKey!.substring(0, 8)}****'
                      : t.get('weread_not_configured'),
                  style: TextStyle(
                    color: isConfigured
                        ? Colors.green
                        : cs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isConfigured)
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        onPressed: () =>
                            _confirmClear(context, ref, t),
                        tooltip: t.get('weread_clear'),
                      ),
                    Icon(Icons.chevron_right,
                        color: cs.onSurfaceVariant),
                  ],
                ),
                onTap: () => _showKeyDialog(context, ref, t, apiKey),
              ),
              const SettingsDivider(),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.help_outline_rounded,
                    color: AppColors.info,
                    size: 20,
                  ),
                ),
                title: Text(t.get('weread_how_to_get_key')),
                subtitle: Text(
                  t.get('weread_how_to_get_key_desc'),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                trailing: Icon(Icons.open_in_new,
                    size: 16, color: cs.onSurfaceVariant),
                onTap: () => _showHelpDialog(context, t),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showKeyDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    String? currentKey,
  ) {
    final controller = TextEditingController(text: currentKey ?? '');
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.get('weread_configure_key')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.get('weread_key_hint'),
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'wrk-xxxxxxxxxx',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                isDense: true,
              ),
              autofocus: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            onPressed: () {
              final key = controller.text.trim();
              if (key.isNotEmpty) {
                ref.read(wereadApiKeyProvider.notifier).setApiKey(key);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t.get('weread_key_saved')),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(t.get('save')),
          ),
        ],
      ),
    );
  }

  void _confirmClear(
      BuildContext context, WidgetRef ref, AppLocalizations t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.get('weread_clear_key')),
        content: Text(t.get('weread_clear_key_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            onPressed: () {
              ref.read(wereadApiKeyProvider.notifier).clearApiKey();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t.get('weread_key_cleared')),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(t.get('weread_clear')),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context, AppLocalizations t) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.get('weread_help_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _helpStep(cs, '1', t.get('weread_help_step1')),
            const SizedBox(height: 8),
            _helpStep(cs, '2', t.get('weread_help_step2')),
            const SizedBox(height: 8),
            _helpStep(cs, '3', t.get('weread_help_step3')),
            const SizedBox(height: 8),
            _helpStep(cs, '4', t.get('weread_help_step4')),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.get('weread_help_got_it')),
          ),
        ],
      ),
    );
  }

  Widget _helpStep(ColorScheme cs, String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            num,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}
