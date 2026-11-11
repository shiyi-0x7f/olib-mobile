import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import 'package:open_filex/open_filex.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/backend_auth_provider.dart';
import '../../providers/download_provider.dart';
import '../../screens/book_detail/widgets/download_quota_dialog.dart';
import '../../services/backend_books_api.dart';
import '../../services/update_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/quota_phrases.dart';
import '../app_toast.dart';
import '../update_dialog.dart';

/// z站 书籍下载的统一流程（详情页底栏与搜索结果行内下载共用）。
///
/// 依次处理：强制更新拦截 → 已下载则打开 → 本地已存在询问 → 按入口取链并启动下载。
class BookDownloadFlow {
  BookDownloadFlow._();

  /// [task] 为该书当前的下载任务（可空）；[fromAi] 见 BookDetailArgs。
  static Future<void> run(
    BuildContext context,
    WidgetRef ref,
    Book book, {
    DownloadTask? task,
    bool fromAi = false,
  }) async {
    final isCompleted = task?.status == DownloadStatus.completed;
    if (UpdateService.isBlocked && !isCompleted) {
      showUpdateDialog(context);
      return;
    }

    if (isCompleted && task?.filePath != null) {
      OpenFilex.open(task!.filePath!);
      return;
    }

    final existingPath = await ref
        .read(downloadProvider.notifier)
        .checkFileExists(book);

    if (existingPath != null && context.mounted) {
      final isZh = Localizations.localeOf(context).languageCode == 'zh';
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
        btnCancelOnPress: () => OpenFilex.open(existingPath),
        btnOkText: isZh ? '重新下载' : 'Download Again',
        btnOkColor: AppColors.primary,
        btnOkOnPress: () => _kickoff(context, ref, book, fromAi: fromAi),
      ).show();
      return;
    }

    if (!context.mounted) return;
    await _kickoff(context, ref, book, fromAi: fromAi);
  }

  /// 真正触发下载的统一入口 — 根据 fromAi 二分：
  /// - fromAi=true:  调 backend `/books/download-url` 拿 z-lib 签名 URL（消耗
  ///                 免费下载配额），用内置 DownloadNotifier streaming 到本地
  /// - fromAi=false: 老路径，用户自己 z站 账号
  ///
  /// 配额耗尽时显示文学化文案，UI 无任何"配额/免费"商业词。
  static Future<void> _kickoff(
    BuildContext context,
    WidgetRef ref,
    Book book, {
    required bool fromAi,
  }) async {
    final downloadingMsg = AppLocalizations.of(context).get('downloading');
    final notifier = ref.read(downloadProvider.notifier);

    if (!fromAi) {
      if (await _ownQuotaExhausted(ref)) {
        if (context.mounted) showDownloadQuotaDialog(context);
        return;
      }
      if (!context.mounted) return;
      // 下载结束后刷新资料，保持本地剩余次数准确
      final auth = ref.read(authProvider.notifier);
      notifier.startDownload(book).whenComplete(auth.refreshProfile);
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

    await _downloadViaBackend(context, ref, book, token, quiet: false);
  }

  /// 本地缓存显示用户自己 Z 站账号额度已用尽时，刷新资料再确认一次
  /// （额度按天重置，缓存可能过期）。
  static Future<bool> _ownQuotaExhausted(WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user == null || user.downloadsLeft > 0) return false;
    await ref.read(authProvider.notifier).refreshProfile();
    final refreshed = ref.read(authProvider).user;
    return refreshed != null && refreshed.downloadsLeft <= 0;
  }

  /// 经 backend `/books/download-url` 取签名 URL 并启动下载。
  /// 返回 true 表示本次已处理完（含成功与配额用尽的文案）；
  /// [quiet]=true 时其他失败不提示、返回 false，交由调用方回退。
  static Future<bool> _downloadViaBackend(
    BuildContext context,
    WidgetRef ref,
    Book book,
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
      AppToast.error(
        isZh ? '获取下载链接失败：$e' : 'Failed to get download URL: $e',
      );
      return true;
    }
  }

  static void _toast(BuildContext context, String message) =>
      AppToast.show(message);
}
