import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import 'package:open_filex/open_filex.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/download_provider.dart';
import '../../routes/app_navigator.dart';
import '../../routes/app_routes.dart';
import '../../screens/book_detail/widgets/download_quota_dialog.dart';
import '../../services/update_service.dart';
import '../../theme/app_colors.dart';
import '../app_toast.dart';
import '../domain_selector.dart';
import '../update_dialog.dart';

/// z站 书籍下载的统一流程（详情页底栏与搜索结果行内下载共用）。
///
/// 依次处理：强制更新拦截 → 已下载则打开 → 本地已存在询问 → 按入口取链并启动下载。
class BookDownloadFlow {
  BookDownloadFlow._();

  /// [task] 为该书当前的下载任务（可空）。
  static Future<void> run(
    BuildContext context,
    WidgetRef ref,
    Book book, {
    DownloadTask? task,
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
        btnOkOnPress: () => _kickoff(context, ref, book),
      ).show();
      return;
    }

    if (!context.mounted) return;
    await _kickoff(context, ref, book);
  }

  /// 真正触发下载的统一入口：用户自己 z站 账号（社群版可经 olibai 中介）。
  static Future<void> _kickoff(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) async {
    final downloadingMsg = AppLocalizations.of(context).get('downloading');
    final notifier = ref.read(downloadProvider.notifier);

    if (!await ref.read(authProvider.notifier).ensureSession()) {
      if (context.mounted) _promptSessionUnavailable(context, ref);
      return;
    }
    if (await _ownQuotaExhausted(ref)) {
      if (context.mounted) showDownloadQuotaDialog(context);
      return;
    }
    if (!context.mounted) return;
    // 下载结束后刷新资料，保持本地剩余次数准确
    final auth = ref.read(authProvider.notifier);
    notifier.startDownload(book).whenComplete(auth.refreshProfile);
    _toast(context, downloadingMsg);
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


  /// Z 站账号会话不可用：未登录 → 引导登录；已登录但线路不通 → 引导切换线路。
  static void _promptSessionUnavailable(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    if (!ref.read(authProvider).isAuthenticated) {
      AppToast.show(
        l.get('download_login_required'),
        kind: ToastKind.error,
        actionLabel: l.get('login'),
        onAction: () =>
            rootNavigatorKey.currentState?.pushNamed(AppRoutes.login),
      );
      return;
    }
    AppToast.show(
      l.get('download_line_unavailable'),
      kind: ToastKind.error,
      actionLabel: l.get('download_switch_line'),
      onAction: () {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx == null) return;
        showDialog(context: ctx, builder: (_) => const DomainSelectionDialog());
      },
    );
  }

  static void _toast(BuildContext context, String message) =>
      AppToast.show(message);
}
