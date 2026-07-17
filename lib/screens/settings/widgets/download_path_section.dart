import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../providers/settings_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/locale_utils.dart' as locale_utils;
import 'section_header.dart';
import 'settings_card.dart';

class DownloadPathSection extends ConsumerWidget {
  const DownloadPathSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Platform.isIOS) return const SizedBox.shrink();

    final isZh = locale_utils.isZhLocale(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        SectionHeader(
          icon: Icons.download_rounded,
          title: isZh ? '下载' : 'Downloads',
        ),
        SettingsCard(
          child: ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(isZh ? '下载目录' : 'Download Directory'),
            subtitle: _buildSubtitle(context, ref),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDownloadPathDialog(context, ref),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle(BuildContext context, WidgetRef ref) {
    if (Platform.isAndroid) {
      return Text(
        locale_utils.isZhLocale(context)
            ? '系统下载文件夹 (MediaStore)'
            : 'System Downloads (MediaStore)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final path = ref.watch(downloadPathProvider);
    final displayPath = (path != null && path.isNotEmpty)
        ? path
        : (locale_utils.isZhLocale(context)
            ? '默认（应用文档目录）'
            : 'Default (App Documents)');
    return Text(
      displayPath,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _showDownloadPathDialog(BuildContext context, WidgetRef ref) {
    final isZh = locale_utils.isZhLocale(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // On Android 10+, MediaStore handles downloads automatically
                  if (Platform.isAndroid) ...[
                    ListTile(
                      leading: const Icon(
                          Icons.download, color: AppColors.primary),
                      title: Text(
                          isZh ? '系统下载文件夹' : 'System Downloads Folder'),
                      subtitle: Text(
                        isZh
                            ? '使用 MediaStore API 保存到公共下载目录'
                            : 'Uses MediaStore API to save to public Downloads',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isZh ? '推荐' : 'Recommended',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700],
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isZh
                                    ? '下载的书籍将保存到系统"下载"文件夹，可在文件管理器中找到。'
                                    : 'Downloaded books will be saved to the system Downloads folder, accessible via file manager.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final success = await openDownloadFolder();
                                if (!success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(isZh
                                        ? '无法打开文件夹'
                                        : 'Could not open folder')),
                                  );
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                              icon: const Icon(Icons.folder_open),
                              label: Text(isZh
                                  ? '打开下载文件夹'
                                  : 'Open Download Folder'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    ...[
                      // On desktop platforms, use file picker
                      ListTile(
                        leading: const Icon(
                            Icons.folder_open, color: AppColors.primary),
                        title: Text(isZh ? '选择文件夹' : 'Select Folder'),
                        subtitle: Text(isZh
                            ? '选择自定义下载目录'
                            : 'Choose a custom download directory'),
                        onTap: () async {
                          Navigator.pop(context);
                          final result = await FilePicker
                              .getDirectoryPath();
                          if (result != null) {
                            ref
                                .read(downloadPathProvider.notifier)
                                .setDownloadPath(result);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isZh
                                      ? '下载目录已更新'
                                      : 'Download directory updated'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      ListTile(
                        leading: Icon(
                            Icons.restore,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        title: Text(isZh ? '恢复默认' : 'Reset to Default'),
                        subtitle: Text(isZh
                            ? '使用应用默认文档目录'
                            : 'Use app default documents directory'),
                        onTap: () {
                          Navigator.pop(context);
                          ref
                              .read(downloadPathProvider.notifier)
                              .clearDownloadPath();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isZh
                                  ? '已恢复默认目录'
                                  : 'Reset to default directory'),
                            ),
                          );
                        },
                      ),
                    ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(isZh ? '关闭' : 'Close'),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
