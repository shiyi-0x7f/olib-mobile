import 'dart:async';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/prescription.dart';
import '../../providers/prescriber_provider.dart';
import '../../providers/backend_auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../book_detail/book_detail_args.dart';
import 'widgets/prescriber_input_section.dart';
import 'widgets/prescriber_result_section.dart';

class PrescriberScreen extends ConsumerStatefulWidget {
  const PrescriberScreen({super.key});

  @override
  ConsumerState<PrescriberScreen> createState() => _PrescriberScreenState();
}

class _PrescriberScreenState extends ConsumerState<PrescriberScreen>
    with TickerProviderStateMixin {
  final _inputController = TextEditingController();
  late AnimationController _animController;
  late AnimationController _loadingController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    // 保留上次的结果：用户切走再回来仍能看到最近一次寻书的内容。
    // 若处于 done 状态，把出场动画也补播一遍，避免淡入态停在中间。
    Future.microtask(() {
      if (!mounted) return;
      final status = ref.read(prescriberProvider).status;
      if (status == PrescriberStatus.done) {
        _animController.value = 1.0;
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _animController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  /// 检查授权状态，未授权则跳转扫码页
  Future<bool> _ensureAuthorized() async {
    final authState = ref.read(backendAuthProvider);
    if (authState.isAuthorized) return true;

    final result = await Navigator.pushNamed(context, AppRoutes.qrAuth);
    return result == true;
  }

  void _diagnoseWithTheme(String themeId) async {
    if (!await _ensureAuthorized()) return;
    final locale = Localizations.localeOf(context).languageCode;
    ref.read(prescriberProvider.notifier).diagnose(
      input: themeId,
      inputType: 'theme',
      language: locale == 'zh' ? 'zh' : 'en',
    );
    _animController.forward(from: 0);
  }

  void _diagnoseWithInput() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (!await _ensureAuthorized()) return;
    final locale = Localizations.localeOf(context).languageCode;
    ref.read(prescriberProvider.notifier).diagnose(
      input: text,
      inputType: 'free',
      language: locale == 'zh' ? 'zh' : 'en',
    );
    _animController.forward(from: 0);
    FocusScope.of(context).unfocus();
  }

  /// 重试上一次失败：自由输入有内容则用自由输入，否则不动
  void _retryLastInput() {
    if (_inputController.text.trim().isNotEmpty) {
      _diagnoseWithInput();
    }
  }

  void _reset() {
    ref.read(prescriberProvider.notifier).reset();
    _inputController.clear();
    _animController.reset();
  }

  /// 寻书结果点击处理：
  /// - 已匹配 → 进 book detail。AI 来源带 fromAi=true 标识，detail 页下载时
  ///            才真正消耗后端免费下载配额（消耗时机推迟到用户明确"下载"才发生）
  /// - 未匹配 → 跳搜索页
  void _onGetBook(ReadingTip tip) {
    if (tip.matchedBook == null) {
      Navigator.of(context).pushNamed(AppRoutes.search);
      return;
    }
    Navigator.of(context).pushNamed(
      AppRoutes.bookDetail,
      arguments: BookDetailArgs(book: tip.matchedBook!, fromAi: tip.fromAi),
    );
  }

  /// 配额耗尽时强化反馈：弹 dialog（用 AwesomeDialog 跟 app 风格保持一致）。
  /// dialog 关掉后输入区域仍处于禁用态，避免无效操作。
  void _showQuotaDialog(String message, bool isZh) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.bottomSlide,
      dismissOnTouchOutside: false,
      title: isZh ? '今日已尽' : 'Until tomorrow',
      desc: message,
      btnOkText: isZh ? '明日再来' : 'See you tomorrow',
      btnOkColor: AppColors.primary,
      btnOkOnPress: () {},
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prescriberProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final isZh = locale == 'zh';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 监听 state 转换到 quota 错误（用户刚刚撞配额上限），弹一次性 dialog。
    // ref.listen 只在 state 变化时触发，进入页面时若已是 quota 不会重弹。
    ref.listen<PrescriberState>(prescriberProvider, (prev, next) {
      final justBecameQuota = next.status == PrescriberStatus.error &&
          next.errorKind == PrescriberErrorKind.quota &&
          (prev?.errorKind != PrescriberErrorKind.quota);
      if (justBecameQuota && next.errorMessage != null) {
        _showQuotaDialog(next.errorMessage!, isZh);
      }
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary
                  .withValues(alpha: isDark ? 0.12 : 0.08),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      color: Theme.of(context).colorScheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  isZh ? '✨ 寻书' : '✨ Find Books',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                centerTitle: true,
                actions: [
                  if (state.status == PrescriberStatus.done)
                    IconButton(
                      icon: Icon(Icons.refresh_rounded,
                          color: theme.colorScheme.primary),
                      onPressed: _reset,
                      tooltip: isZh ? '再寻一次' : 'Try again',
                    ),
                ],
              ),

              // Content
              if (state.status == PrescriberStatus.idle ||
                  state.status == PrescriberStatus.error)
                PrescriberInputSection(
                  inputController: _inputController,
                  onDiagnoseWithInput: _diagnoseWithInput,
                  onDiagnoseWithTheme: _diagnoseWithTheme,
                  onRetry: _retryLastInput,
                  isZh: isZh,
                ),

              if (state.status == PrescriberStatus.loading)
                _LoadingSection(
                  isZh: isZh,
                  rotationController: _loadingController,
                ),

              if (state.status == PrescriberStatus.done &&
                  state.result != null)
                PrescriberResultSection(
                  bag: state.result!,
                  isZh: isZh,
                  fadeAnimation: _fadeAnim,
                  onReset: _reset,
                  onGetBook: _onGetBook,
                ),
            ],
          ),
        ),
      ),
    );
  }

}

// ════════════════════════════════════════════════════════════
//  Loading section — rotating reassurance copy
// ════════════════════════════════════════════════════════════

/// 加载态：图标持续旋转 + 文案每 2.5s 轮播，缓解 AI 生成 5-15 秒的焦虑。
class _LoadingSection extends StatefulWidget {
  final bool isZh;
  final AnimationController rotationController;

  const _LoadingSection({
    required this.isZh,
    required this.rotationController,
  });

  @override
  State<_LoadingSection> createState() => _LoadingSectionState();
}

class _LoadingSectionState extends State<_LoadingSection> {
  static const List<String> _messagesZh = [
    '正在翻阅书海...',
    '匹配你的心境...',
    '整理推荐理由...',
    '快好了，再等等...',
  ];

  static const List<String> _messagesEn = [
    'Browsing the bookshelves...',
    'Matching your mood...',
    'Drafting reasons...',
    'Almost there...',
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % _messages.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<String> get _messages => widget.isZh ? _messagesZh : _messagesEn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 旋转图标
            RotationTransition(
              turns: widget.rotationController,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 36,
                  color: cs.primary,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // 主文案
            Text(
              widget.isZh ? '正在为你寻书' : 'Finding books for you',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),

            // 轮播副文案 — AnimatedSwitcher 淡入淡出
            SizedBox(
              height: 22,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  _messages[_index],
                  key: ValueKey(_index),
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 进度条
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
