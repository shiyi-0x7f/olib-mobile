import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/locale_utils.dart' as locale_utils;
import 'section_header.dart';
import 'settings_card.dart';

class LanguageSection extends ConsumerWidget {
  const LanguageSection({super.key});

  /// All supported languages with metadata
  static const allLanguages = {
    'en': {'flag': '🇺🇸', 'native': 'English', 'english': 'English'},
    'zh': {'flag': '🇨🇳', 'native': '简体中文', 'english': 'Simplified Chinese'},
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.translate_rounded,
          title: AppLocalizations.of(context).get('language_setting'),
        ),
        SettingsCard(
          child: ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(
                AppLocalizations.of(context).get('language_setting')),
            subtitle: Text(
                _getLanguageDisplayName(ref.watch(localeProvider))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context, ref),
          ),
        ),
      ],
    );
  }

  String _getLanguageDisplayName(Locale? locale) {
    if (locale == null) return 'System';
    final key = locale_utils.getLocaleKey(locale);
    if (key == null) return '';
    return allLanguages[key]?['native'] ?? key;
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.read(localeProvider);
    final currentKey = currentLocale != null
        ? locale_utils.getLocaleKey(currentLocale)
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) =>
                Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        AppLocalizations.of(context).get('language_setting'),
                        style: Theme
                            .of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          // System option
                          _buildLanguageOption(
                            context: context,
                            ref: ref,
                            key: null,
                            flag: '🌐',
                            native: 'System',
                            english: AppLocalizations.of(context).get(
                                'follow_device'),
                            isSelected: currentKey == null,
                          ),
                          const Divider(height: 1),
                          // All languages
                          ...allLanguages.entries.map((entry) =>
                              _buildLanguageOption(
                                context: context,
                                ref: ref,
                                key: entry.key,
                                flag: entry.value['flag']!,
                                native: entry.value['native']!,
                                english: entry.value['english']!,
                                isSelected: currentKey == entry.key,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required WidgetRef ref,
    required String? key,
    required String flag,
    required String native,
    required String english,
    required bool isSelected,
  }) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 28)),
      title: Text(native, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        english,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : null,
      onTap: () {
        if (key == null) {
          ref.read(localeProvider.notifier).setLocale(null);
        } else {
          ref.read(localeProvider.notifier).setLocale(
              locale_utils.parseLocaleKey(key));
        }
        Navigator.pop(context);
      },
    );
  }
}
