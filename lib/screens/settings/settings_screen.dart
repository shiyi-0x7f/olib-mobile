import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../../providers/auth_provider.dart';
import '../../services/update_service.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/locale_utils.dart' as locale_utils;
import 'widgets/user_profile_section.dart';
import 'widgets/download_path_section.dart';
import 'widgets/about_section.dart';
import 'widgets/language_section.dart';
import 'widgets/theme_section.dart';
import 'widgets/network_section.dart';
import 'widgets/weread_settings_section.dart';
import 'widgets/section_header.dart';
import 'widgets/settings_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final t = AppLocalizations.of(context);
    final isZh = locale_utils.isZhLocale(context);

    return Scaffold(
      appBar: GradientAppBar(title: t.get('settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (user != null) UserProfileSection(user: user),
          const SizedBox(height: 24),

          // ── Library ──────────────────────────────────────────────
          SectionHeader(
            icon: Icons.menu_book_rounded,
            title: t.get('library'),
          ),
          SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text(t.get('download_history')),
              subtitle: Text(t.get('books_downloaded_any_device')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.history),
            ),
          ),
          const DownloadPathSection(),

          const SizedBox(height: 20),

          // ── Network ─────────────────────────────────────────────
          const NetworkSection(),

          const SizedBox(height: 20),

          // ── WeRead (微信读书) ─────────────────────────────────────
          const WereadSettingsSection(),

          const SizedBox(height: 20),

          // ── Theme ────────────────────────────────────────────────
          const ThemeSection(),

          const SizedBox(height: 20),

          // ── Update ───────────────────────────────────────────────
          SectionHeader(
            icon: Icons.system_update_rounded,
            title: isZh ? '更新' : 'Update',
          ),
          SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.system_update),
              title: Text(isZh ? '检查更新' : 'Check for Updates'),
              subtitle: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '...';
                  return Text(
                    isZh ? '当前版本: v$version' : 'Current version: v$version',
                  );
                },
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => UpdateService.showManualCheckDialog(context),
            ),
          ),

          const SizedBox(height: 20),

          // ── Language ─────────────────────────────────────────────
          const LanguageSection(),

          const SizedBox(height: 20),

          // ── About ────────────────────────────────────────────────
          const AboutSection(),

          const SizedBox(height: 28),

          // ── Logout (centered TextButton + confirm) ───────────────
          Center(
            child: TextButton.icon(
              onPressed: () => _confirmLogout(context, ref, isZh),
              icon: const Icon(Icons.logout, size: 18),
              label: Text(t.get('logout')),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref, bool isZh) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.bottomSlide,
      title: isZh ? '退出登录？' : 'Log out?',
      desc: isZh
          ? '退出后需要重新输入账号密码登录。'
          : 'You will need to log in again with your credentials.',
      btnCancelText: isZh ? '取消' : 'Cancel',
      btnCancelOnPress: () {},
      btnOkText: isZh ? '退出' : 'Log out',
      btnOkColor: AppColors.error,
      btnOkOnPress: () async {
        await ref.read(authProvider.notifier).logout();
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.login,
            (route) => false,
          );
        }
      },
    ).show();
  }
}
