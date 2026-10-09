import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/weread_provider.dart';
import '../../weread/weread_mobile_hub_screen.dart';
import 'section_header.dart';
import 'settings_card.dart';

/// 微信读书扫码连接入口。
class WereadSettingsSection extends ConsumerWidget {
  const WereadSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(wereadConnectionProvider);
    final connected = connection.valueOrNull == true;
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(icon: Icons.menu_book_rounded, title: t.get('weread')),
        SettingsCard(
          child: ListTile(
            leading: Icon(
              connected ? Icons.verified_user_outlined : Icons.qr_code_rounded,
              color: connected ? Colors.green : cs.primary,
            ),
            title: Text(t.get('weread_mobile_title')),
            subtitle: Text(
              connection.isLoading
                  ? t.get('loading')
                  : connected
                  ? t.get('weread_mobile_connected')
                  : t.get('weread_not_configured'),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const WereadMobileHubScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
