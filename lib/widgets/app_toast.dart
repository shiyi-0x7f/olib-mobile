import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../routes/app_navigator.dart';

enum ToastKind { info, success, error }

/// 全局顶部提示（替代底部 SnackBar）。
///
/// - 挂在根导航器的 Overlay 上：跟随 App 主题与深浅色，叠在弹窗 / 底部面板之上；
///   不依赖调用处的 context，异步回调里也能直接用。
/// - 错误提示停留更久且文字可选中复制，便于用户截图或反馈。
/// - 最多一个操作按钮；可上滑或点 × 关闭。
class AppToast {
  AppToast._();

  static const _infoDuration = Duration(seconds: 3);
  static const _errorDuration = Duration(seconds: 6);

  static void show(
    String message, {
    ToastKind kind = ToastKind.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      debugPrint('[AppToast] no overlay, dropped: $message');
      return;
    }
    toastification.showCustom(
      overlayState: overlay,
      alignment: Alignment.topCenter,
      autoCloseDuration:
          duration ??
          (kind == ToastKind.error || actionLabel != null
              ? _errorDuration
              : _infoDuration),
      builder: (context, item) => _ToastCard(
        message: message,
        kind: kind,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                toastification.dismiss(item);
                onAction();
              },
        onClose: () => toastification.dismiss(item),
      ),
    );
  }

  static void success(String message) => show(message, kind: ToastKind.success);

  static void error(String message) => show(message, kind: ToastKind.error);

  /// 关闭当前所有提示（如「处理中…」被结果提示替换时）。
  static void dismissAll() => toastification.dismissAll();
}

class _ToastCard extends StatelessWidget {
  final String message;
  final ToastKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onClose;

  const _ToastCard({
    required this.message,
    required this.kind,
    required this.actionLabel,
    required this.onAction,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (IconData icon, Color accent) = switch (kind) {
      ToastKind.info => (Icons.info_outline_rounded, cs.primary),
      ToastKind.success => (Icons.check_circle_outline_rounded, Colors.green),
      ToastKind.error => (Icons.error_outline_rounded, cs.error),
    };
    final textStyle = TextStyle(fontSize: 14, height: 1.4, color: cs.onSurface);

    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.up,
      onDismissed: (_) => onClose(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Material(
          color: cs.surfaceContainerHigh,
          elevation: 6,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(
              children: [
                Icon(icon, color: accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: kind == ToastKind.error
                      ? SelectableText(message, style: textStyle)
                      : Text(message, style: textStyle),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  color: cs.onSurfaceVariant,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
