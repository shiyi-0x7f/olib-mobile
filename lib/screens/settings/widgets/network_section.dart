import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/domain_provider.dart';
import '../../../providers/speed_test_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/locale_utils.dart' as locale_utils;
import '../../../widgets/domain_selector.dart';
import 'section_header.dart';
import 'settings_card.dart';

/// Network line picker — same chevron-tile shape as the other settings.
/// Shows "Line N · 234ms" (latency from the latest speed test) and only
/// ever displays the line index, never the underlying domain.
class NetworkSection extends ConsumerWidget {
  const NetworkSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final isZh = locale_utils.isZhLocale(context);
    final currentDomain = ref.watch(domainProvider);
    final domains = ref.watch(domainListProvider);
    final speedState = ref.watch(speedTestProvider);

    final idx = domains.indexOf(currentDomain);
    final lineLabel = idx >= 0
        ? 'Line ${idx + 1}'
        : (isZh ? '自定义线路' : 'Custom Line');

    // Look up the latency for the current line.
    int? latency;
    for (final r in speedState.results) {
      if (r.domain == currentDomain) {
        latency = r.latencyMs;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.dns_rounded,
          title: t.get('network'),
        ),
        SettingsCard(
          child: ListTile(
            leading: const Icon(Icons.public_rounded),
            title: Text(t.get('network_line')),
            subtitle: _LineStatus(
              label: lineLabel,
              latency: latency,
              testing: speedState.testing,
              isZh: isZh,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog(
              context: context,
              builder: (_) => const DomainSelectionDialog(),
            ),
          ),
        ),
      ],
    );
  }
}

class _LineStatus extends StatelessWidget {
  final String label;
  final int? latency;
  final bool testing;
  final bool isZh;

  const _LineStatus({
    required this.label,
    required this.latency,
    required this.testing,
    required this.isZh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (statusText, statusColor) = _statusFor(latency, testing, isZh, cs);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _statusFor(
      int? latency, bool testing, bool isZh, ColorScheme cs) {
    if (latency == null) {
      return (
        testing ? (isZh ? '测速中' : 'Testing') : (isZh ? '未测速' : 'Untested'),
        cs.onSurfaceVariant,
      );
    }
    if (latency < 0) {
      return (isZh ? '不可用' : 'Unavailable', AppColors.error);
    }
    if (latency < 1000) {
      return ('${latency}ms', AppColors.success);
    }
    if (latency < 3000) {
      return ('${latency}ms', AppColors.warning);
    }
    return ('${latency}ms', AppColors.error);
  }
}
