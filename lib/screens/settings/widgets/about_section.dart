import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/locale_utils.dart' as locale_utils;
import 'section_header.dart';
import 'settings_card.dart';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isZh = locale_utils.isZhLocale(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.info_outline_rounded,
          title: AppLocalizations.of(context).get('about'),
        ),
        SettingsCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(AppLocalizations.of(context).get('version')),
                trailing: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.data?.version ?? '...';
                    return Text(version);
                  },
                ),
              ),
              const SettingsDivider(),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: Text(isZh ? '分享应用' : 'Share App'),
                subtitle: Text(isZh ? '推荐给朋友' : 'Recommend to friends'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _shareApp(context),
              ),
              const SettingsDivider(),
              ListTile(
                leading: const Icon(Icons.book_outlined),
                title: Text(
                    AppLocalizations.of(context).get('about_zlibrary')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAboutApp(context),
              ),
              const SettingsDivider(),
              ListTile(
                leading: const Icon(Icons.code),
                title: Text(isZh ? 'GitHub 开源' : 'GitHub Open Source'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () =>
                    _launchUrl('https://github.com/shiyi-0x7f/olib-mobile'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareApp(BuildContext context) {
    final isZh = locale_utils.isZhLocale(context);
    final text = isZh
        ? '推荐一款开源电子书阅读器 Olib，由AI构建的第三方客户端！\n下载地址: https://bookbook.space\nGitHub: https://github.com/shiyi-0x7f/olib-mobile'
        : 'Check out Olib - an open-source ebook reader built with AI!\nDownload: https://bookbook.space\nGitHub: https://github.com/shiyi-0x7f/olib-mobile';
    Share.share(text);
  }

  void _showAboutApp(BuildContext context) {
    final isZh = locale_utils.isZhLocale(context);
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_stories,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Olib',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isZh
                    ? '🤖 AI构建的开源第三方客户端'
                    : '🤖 AI-Built Open Source Third-Party Client',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isZh
                    ? 'Olib 是一个由AI辅助构建的开源项目。\n\n📱 本项目仅提供前端界面\n📚 所有书籍数据来源于外部图书馆服务\n🔓 100% 开源，代码公开透明\n\n⚠️ 声明：\n• Olib 是第三方客户端，非官方客户端\n• 与任何官方服务无关联\n• 使用本应用即表示您理解并接受以上内容'
                    : 'Olib is an open-source project built with AI assistance.\n\n📱 This project only provides frontend interface\n📚 All book data comes from external library services\n🔓 100% open source, transparent code\n\n⚠️ Disclaimer:\n• Olib is a third-party client, not an official client\n• Not affiliated with any official service\n• By using this app you understand and accept the above',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isZh
                            ? '"知识无边界"'
                            : '"Knowledge has no boundaries"',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isZh ? '关闭' : 'Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl('https://github.com/shiyi-0x7f/olib-mobile');
            },
            icon: const Icon(Icons.code, size: 16),
            label: Text(isZh ? '查看源码' : 'View Source'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
