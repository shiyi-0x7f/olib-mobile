import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import 'section_header.dart';
import 'settings_card.dart';

/// Three theme modes laid out as a single M3 SegmentedButton row.
/// Replaces the three stacked RadioListTiles to save ~70% vertical space.
class ThemeSection extends ConsumerWidget {
  const ThemeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.palette_rounded,
          title: t.get('appearance'),
        ),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<AppThemeMode>(
                segments: [
                  ButtonSegment(
                    value: AppThemeMode.light,
                    icon: const Icon(Icons.light_mode_rounded, size: 18),
                    label: Text(t.get('light')),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.dark,
                    icon: const Icon(Icons.dark_mode_rounded, size: 18),
                    label: Text(t.get('dark')),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.system,
                    icon: const Icon(Icons.phone_iphone_rounded, size: 18),
                    label: Text(t.get('system')),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (set) {
                  if (set.isNotEmpty) {
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(set.first);
                  }
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return cs.onPrimary;
                    }
                    return cs.onSurfaceVariant;
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return cs.primary;
                    }
                    return Colors.transparent;
                  }),
                ),
                showSelectedIcon: false,
              ),
            ),
          ),
      ],
    );
  }
}
