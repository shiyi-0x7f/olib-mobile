import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/backend_auth_provider.dart';
import '../../theme/app_colors.dart';

/// 微信扫码授权页面
class QrAuthScreen extends ConsumerStatefulWidget {
  const QrAuthScreen({super.key});

  @override
  ConsumerState<QrAuthScreen> createState() => _QrAuthScreenState();
}

class _QrAuthScreenState extends ConsumerState<QrAuthScreen> {
  bool _isLoading = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _initError = null;
    });

    try {
      // 本地 token 仍有效（SCC token 离线可判）→ 无需扫码，直接返回
      if (ref.read(backendAuthProvider).isAuthorized) {
        if (mounted) Navigator.pop(context, true);
        return;
      }

      // 向 SCC 建码并开始轮询扫码状态
      final notifier = ref.read(backendAuthProvider.notifier);
      await notifier.fetchQrCode();
      notifier.startPolling();
    } catch (e) {
      _initError = e.toString();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refreshQrCode() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _initError = null;
    });

    try {
      final notifier = ref.read(backendAuthProvider.notifier);
      notifier.stopPolling();
      await notifier.fetchQrCode();

      final afterQr = ref.read(backendAuthProvider);
      if (afterQr.isAuthorized) {
        if (mounted) Navigator.pop(context, true);
        return;
      }

      notifier.startPolling();
    } catch (e) {
      _initError = e.toString();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    // 页面关闭时停止轮询
    try {
      ref.read(backendAuthProvider.notifier).stopPolling();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final isZh = locale == 'zh';
    final authState = ref.watch(backendAuthProvider);

    // 授权成功 → 自动关闭页面
    if (authState.isAuthorized && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha:0.08),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    Expanded(
                      child: Text(
                        isZh ? '扫码授权' : 'Scan to Authorize',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: _buildQrBody(authState, isZh),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// QR 流程主体：图标 + 标题 + 二维码 + 状态提示。
  Widget _buildQrBody(BackendAuthState authState, bool isZh) {
    final cs = Theme.of(context).colorScheme;
    // 曾经授权过（token 过期进来的）→ 副标题改成提示重新扫码。
    final notifier = ref.read(backendAuthProvider.notifier);
    final reauthing = notifier.lastAuthorizedAt() != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 图标
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF07C160).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.qr_code_scanner_rounded,
            size: 36,
            color: Color(0xFF07C160),
          ),
        ),
        const SizedBox(height: 20),

        // 标题
        Text(
          isZh
              ? (reauthing ? '需要重新扫码授权' : '使用微信扫描下方二维码')
              : (reauthing
                  ? 'Please scan again to re-authorize'
                  : 'Scan the QR code with WeChat'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isZh
              ? (reauthing
                  ? '会话已失效，扫码后即可继续使用'
                  : '关注公众号即可解锁 AI 寻书功能')
              : (reauthing
                  ? 'Session expired — scan to continue'
                  : 'Follow our account to unlock AI find-books'),
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // 二维码区域
        _buildQrSection(authState, isZh),

        const SizedBox(height: 24),

        // 状态提示
        _buildStatusHint(authState, isZh),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildQrSection(BackendAuthState authState, bool isZh) {
    // 初始化中
    if (_isLoading) {
      return _buildQrContainer(
        child: const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    // 初始化错误
    if (_initError != null) {
      return _buildQrContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(
              _initError!,
              style: TextStyle(color: Colors.red[400], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _initAuth,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(isZh ? '重试' : 'Retry'),
            ),
          ],
        ),
      );
    }

    // Provider 级别的错误
    if (authState.error != null && authState.qrUrl == null) {
      return _buildQrContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(
              authState.error!,
              style: TextStyle(color: Colors.red[400], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _refreshQrCode,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(isZh ? '重试' : 'Retry'),
            ),
          ],
        ),
      );
    }

    // 有二维码
    if (authState.qrUrl != null && authState.qrUrl!.isNotEmpty) {
      return Column(
        children: [
          _buildQrContainer(
            child: Image.network(
              authState.qrUrl!,
              width: 220,
              height: 220,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, loading) {
                if (loading == null) return child;
                return const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 3),
                );
              },
              errorBuilder: (_, __, ___) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_rounded,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    isZh ? '图片加载失败' : 'Image loading failed',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _refreshQrCode,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              isZh ? '刷新二维码' : 'Refresh QR Code',
              style: const TextStyle(fontSize: 13),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    // 兜底
    return _buildQrContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isZh ? '正在加载...' : 'Loading...',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _initAuth,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(isZh ? '重试' : 'Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildQrContainer({required Widget child}) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }

  Widget _buildStatusHint(BackendAuthState authState, bool isZh) {
    if (authState.isAuthorized) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF07C160), size: 20),
          const SizedBox(width: 8),
          Text(
            isZh ? '授权成功！' : 'Authorized!',
            style: const TextStyle(
              color: Color(0xFF07C160),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      );
    }

    if (authState.isPolling) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isZh ? '等待扫码中...' : 'Waiting for scan...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    if (authState.error != null) {
      return Text(
        authState.error!,
        style: TextStyle(color: Colors.orange[700], fontSize: 13),
        textAlign: TextAlign.center,
      );
    }

    return const SizedBox.shrink();
  }
}
