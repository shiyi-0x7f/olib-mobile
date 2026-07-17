import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/domain_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/backend_auth_provider.dart';
import '../../../services/backend_books_api.dart';
import '../../../utils/quota_phrases.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/update_service.dart';
import '../../../routes/app_routes.dart';
import '../../reader/reader_screen.dart';

class BookActionBar extends ConsumerWidget {
  final Book book;
  final DownloadTask? downloadTask;
  final bool isDownloading;
  final bool isCompleted;
  final bool isDark;
  /// 从 AI 寻书入口进来的书，下载走 backend 免费下载路径，
  /// 不消耗用户 z站 账号配额。详见 BookDetailArgs。
  final bool fromAi;

  const BookActionBar({
    super.key,
    required this.book,
    required this.downloadTask,
    required this.isDownloading,
    required this.isCompleted,
    required this.isDark,
    this.fromAi = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hasReadOnline = book.readOnlineUrl != null && book.readOnlineUrl!.isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Download Button (Secondary or Primary if no read) ──
          Expanded(
            child: _buildDownloadButton(
              context, ref, l10n,
              isPrimary: !hasReadOnline,
            ),
          ),

          if (hasReadOnline) ...[
            const SizedBox(width: 12),

            // ── Read Button (Primary) ──
            Expanded(
              child: _buildReadButton(context, ref, l10n),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadButton(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n, {
    bool isPrimary = false,
  }) {
    final IconData icon;
    final String label;

    if (isCompleted) {
      icon = Icons.folder_open_rounded;
      label = l10n.get('open_file');
    } else if (isDownloading) {
      icon = Icons.downloading_rounded;
      label = '${(downloadTask!.progress * 100).toStringAsFixed(0)}%';
    } else {
      icon = Icons.download_rounded;
      label = l10n.get('download');
    }

    if (isPrimary) {
      return SizedBox(
        height: 50,
        child: ElevatedButton.icon(
          onPressed: isDownloading ? null : () => _handleDownload(context, ref),
          icon: Icon(icon, size: 20),
          label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: isCompleted ? AppColors.success : AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      );
    }

    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: isDownloading ? null : () => _handleDownload(context, ref),
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: isCompleted
              ? AppColors.success
              : (isDark ? Colors.white : AppColors.primary),
          side: BorderSide(
            color: isCompleted
                ? AppColors.success
                : (isDark ? Colors.white30 : AppColors.primary.withValues(alpha: 0.5)),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildReadButton(
    BuildContext context, WidgetRef ref, AppLocalizations l10n,
  ) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () => _handleRead(context, ref),
        icon: const Icon(Icons.menu_book_rounded, size: 20),
        label: Text(
          l10n.get('read'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  ACTION HANDLERS
  // ════════════════════════════════════════════════════════════
  void _handleRead(BuildContext context, WidgetRef ref) {
    final customDomain = ref.read(domainProvider);
    final authState = ref.read(authProvider);
    final user = authState.user;

    // Build the reader domain from the custom domain
    final String readerDomain;
    final languagePrefixes = {'zh', 'en', 'de', 'fr', 'es', 'it', 'pt', 'ja', 'ko', 'ru', 'ar'};
    final dotIndex = customDomain.indexOf('.');
    if (dotIndex > 0) {
      final prefix = customDomain.substring(0, dotIndex);
      if (languagePrefixes.contains(prefix)) {
        readerDomain = 'reader${customDomain.substring(dotIndex)}';
      } else {
        readerDomain = 'reader.$customDomain';
      }
    } else {
      readerDomain = 'reader.$customDomain';
    }

    String url = book.readOnlineUrl!;
    url = url.replaceAll(RegExp(r'cdn\.reader\.'), 'reader.');
    url = url.replaceAll(RegExp(r'reader\.[a-zA-Z0-9.-]+'), readerDomain);
    url = url.replaceAll(RegExp(r'z-library\.[a-zA-Z]+'), customDomain);

    if (user != null) {
      final separator = url.contains('?') ? '&' : '?';
      url = '$url${separator}remix_userkey=${user.remixUserkey}&remix_userid=${user.id}';
    }

    Navigator.of(context).pushNamed(
      AppRoutes.reader,
      arguments: ReaderArgs(url: url, title: book.title),
    );
  }

  void _handleDownload(BuildContext context, WidgetRef ref) async {
    // Check for force update block
    if (UpdateService.isBlocked && !isCompleted) {
      final locale = Localizations.localeOf(context).languageCode;
      final isZh = locale == 'zh';

      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.bottomSlide,
        title: isZh ? '功能已禁用' : 'Feature Disabled',
        desc: isZh
            ? '当前版本已过期，请更新到最新版本后使用下载功能。'
            : 'This version is outdated. Please update to use download.',
        btnOkText: isZh ? '立即更新' : 'Update Now',
        btnOkColor: AppColors.primary,
        btnOkOnPress: () {
          if (UpdateService.downloadUrl != null) {
            launchUrl(
              Uri.parse(UpdateService.downloadUrl!),
              mode: LaunchMode.externalApplication,
            );
          }
        },
      ).show();
      return;
    }

    if (isCompleted && downloadTask?.filePath != null) {
      OpenFilex.open(downloadTask!.filePath!);
    } else {
      // Check if file already exists
      final existingPath = await ref
          .read(downloadProvider.notifier)
          .checkFileExists(book);

      if (existingPath != null && context.mounted) {
        final locale = Localizations.localeOf(context).languageCode;
        final isZh = locale == 'zh';

        AwesomeDialog(
          context: context,
          dialogType: DialogType.info,
          animType: AnimType.bottomSlide,
          title: isZh ? '文件已存在' : 'File Already Exists',
          desc: isZh
              ? '这本书已经下载过了。\n\n您可以打开现有文件或重新下载。'
              : 'This book has already been downloaded.\n\nYou can open the existing file or download again.',
          btnCancelText: isZh ? '打开文件' : 'Open File',
          btnCancelColor: Colors.green,
          btnCancelOnPress: () {
            OpenFilex.open(existingPath);
          },
          btnOkText: isZh ? '重新下载' : 'Download Again',
          btnOkColor: AppColors.primary,
          btnOkOnPress: () {
            _kickoffDownload(context, ref);
          },
        ).show();
        return;
      }

      if (!context.mounted) return;
      await _kickoffDownload(context, ref);
    }
  }

  /// 真正触发下载的统一入口 — 根据 fromAi 二分：
  /// - fromAi=true:  调 backend `/books/download-url` 拿 z-lib 签名 URL（消耗
  ///                 免费下载配额），用内置 DownloadNotifier streaming 到本地
  /// - fromAi=false: 老路径，用户自己 z站 账号
  ///
  /// 配额耗尽时显示文学化文案，UI 无任何"配额/免费"商业词。
  Future<void> _kickoffDownload(BuildContext context, WidgetRef ref) async {
    final downloadingMsg = AppLocalizations.of(context).get('downloading');
    final notifier = ref.read(downloadProvider.notifier);

    if (!fromAi) {
      notifier.startDownload(book);
      _toast(context, downloadingMsg);
      return;
    }

    // AI 寻书路径：先用 backend 拿 URL（这一步消耗免费下载配额）
    final token = ref.read(backendAuthProvider).jwt;
    if (token == null) {
      // 入口已 gated，正常路径走不到这里；兜底回退到用户自己账号
      notifier.startDownload(book);
      _toast(context, downloadingMsg);
      return;
    }

    await _downloadViaBackend(context, ref, token, quiet: false);
  }

  /// 经 backend `/books/download-url` 取签名 URL 并启动下载。
  /// 返回 true 表示本次已处理完（含成功与配额用尽的文案）；
  /// [quiet]=true 时其他失败不提示、返回 false，交由调用方回退。
  Future<bool> _downloadViaBackend(
    BuildContext context,
    WidgetRef ref,
    String token, {
    required bool quiet,
  }) async {
    final notifier = ref.read(downloadProvider.notifier);
    try {
      final url = await BackendBooksApi().getAiBookDownloadUrl(
        olibToken: token,
        bookId: book.id.toString(),
        hashId: book.hash ?? '',
      );
      if (!context.mounted) return true;
      notifier.startDownload(book, presetUrl: url);
      _toast(context, AppLocalizations.of(context).get('downloading'));
      return true;
    } on FreeDownloadQuotaExceeded {
      // 额度用尽是明确结果，不回退，展示文学化文案
      if (context.mounted) {
        _toast(context, QuotaPhrases.randomFrom(QuotaPhrases.downloadQuota));
      }
      return true;
    } catch (e) {
      if (quiet) return false;
      if (!context.mounted) return true;
      final isZh = Localizations.localeOf(context).languageCode == 'zh';
      _toast(context, isZh ? '获取下载链接失败：$e' : 'Failed to get download URL: $e');
      return true;
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
