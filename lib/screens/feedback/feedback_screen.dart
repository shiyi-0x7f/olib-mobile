import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/feedback.dart';
import '../../providers/backend_auth_provider.dart';
import '../../providers/feedback_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/feedback_api.dart';
import '../../utils/locale_utils.dart' as locale_utils;
import '../../widgets/gradient_app_bar.dart';
import 'widgets/feedback_form_widgets.dart';

/// 意见反馈表单（提交到 SCC 统一反馈）。
///
/// 填写顺序按「分类 → 描述 → 补充」由粗到细：类型、功能区点选即可，
/// 只有描述必须打字；问题类反馈才展开影响程度与复现步骤。
class FeedbackScreen extends ConsumerStatefulWidget {
  /// 从出错位置进入时的预填（见 `ReportProblemButton`）；从设置进入为 null。
  final FeedbackPrefill? prefill;

  const FeedbackScreen({super.key, this.prefill});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  static const _titleMax = 100;
  static const _contentMax = 2000;
  static const _detailMax = 1000;

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController();
  final _expectedCtrl = TextEditingController();
  final _actualCtrl = TextEditingController();
  late final FeedbackSubmitter _submitter;

  String? _type;
  String? _area;
  String? _severity;
  bool _consent = readDiagnosticsConsent();
  bool _showDetails = false;
  bool _submitting = false;
  bool _triedSubmit = false;
  String? _errorMessage;
  String? _errorDetail;

  bool get _isProblem => feedbackProblemTypes.contains(_type);

  /// 预填的内容不算用户输入：没改动就返回不必确认放弃。
  bool get _isDirty {
    final p = widget.prefill;
    return _type != p?.type ||
        _area != p?.area ||
        _contentCtrl.text.trim() != (p?.summary ?? '').trim() ||
        _titleCtrl.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _submitter = FeedbackSubmitter(ref.read(feedbackApiProvider));
    _applyPrefill(widget.prefill);
  }

  void _applyPrefill(FeedbackPrefill? p) {
    if (p == null) return;
    _type = p.type;
    _area = p.area;
    _contentCtrl.text = _clip(p.summary, _contentMax);
    final detail = _clip(p.errorDetail, _detailMax);
    if (detail.isNotEmpty) {
      _actualCtrl.text = detail;
      _showDetails = true;
    }
  }

  static String _clip(String? s, int max) {
    final v = (s ?? '').trim();
    return v.length <= max ? v : v.substring(0, max);
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _contentCtrl,
      _stepsCtrl,
      _expectedCtrl,
      _actualCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isZh = locale_utils.isZhLocale(context);
    final diag = ref.watch(deviceDiagnosticsProvider).valueOrNull;
    final unsupported = diag != null && diag.platform == null;

    return PopScope(
      canPop: !_isDirty || _submitting,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard(isZh) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: GradientAppBar(
          title: isZh ? '意见反馈' : 'Feedback',
          actions: [
            TextButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.myFeedback),
              icon: const Icon(Icons.history, size: 18),
              label: Text(isZh ? '我的反馈' : 'Mine'),
            ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _intro(isZh),
                const SizedBox(height: 20),
                FeedbackSectionLabel(
                  title: isZh ? '反馈类型' : 'Type',
                  required: true,
                  isZh: isZh,
                  errorText: _triedSubmit && _type == null
                      ? (isZh ? '请选择' : 'Pick one')
                      : null,
                ),
                FeedbackOptionChips(
                  options: feedbackTypes,
                  selected: _type,
                  isZh: isZh,
                  onSelected: (v) => setState(() {
                    _type = v;
                    if (!_isProblem) _severity = null;
                  }),
                ),
                const SizedBox(height: 20),
                FeedbackSectionLabel(
                  title: isZh ? '涉及功能' : 'Feature area',
                  required: true,
                  isZh: isZh,
                  errorText: _triedSubmit && _area == null
                      ? (isZh ? '请选择' : 'Pick one')
                      : null,
                ),
                FeedbackOptionChips(
                  options: feedbackAreas,
                  selected: _area,
                  isZh: isZh,
                  onSelected: (v) => setState(() => _area = v),
                ),
                const SizedBox(height: 20),
                FeedbackSectionLabel(
                  title: isZh ? '详细描述' : 'Description',
                  required: true,
                  isZh: isZh,
                ),
                TextFormField(
                  controller: _contentCtrl,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: _contentMax,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: _contentHint(isZh),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? (isZh ? '请描述一下遇到的情况或想法' : 'Please describe it')
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                FeedbackSectionLabel(
                  title: isZh ? '一句话标题' : 'Title',
                  required: false,
                  isZh: isZh,
                ),
                TextFormField(
                  controller: _titleCtrl,
                  maxLength: _titleMax,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: isZh
                        ? '留空则自动取描述的开头'
                        : 'Leave empty to use the description start',
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_isProblem) ..._problemSection(isZh),
                const SizedBox(height: 20),
                DiagnosticsConsentTile(
                  value: _consent,
                  diagnostics: diag,
                  isZh: isZh,
                  onChanged: (v) {
                    setState(() => _consent = v);
                    saveDiagnosticsConsent(v);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  isZh
                      ? '提交需要微信扫码登录，方便我们在「我的反馈」里告诉你处理进度。'
                      : 'Submitting requires WeChat sign-in so we can update you in "My feedback".',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  FeedbackErrorBanner(
                    message: _errorMessage!,
                    detail: _errorDetail,
                    isZh: isZh,
                    onDismiss: () =>
                        setState(() => _errorMessage = _errorDetail = null),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: (_submitting || diag == null || unsupported)
                        ? null
                        : () => _submit(isZh, diag),
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      unsupported
                          ? (isZh
                                ? '当前平台暂不支持提交'
                                : 'Not supported on this platform')
                          : (_submitting
                                ? (isZh ? '提交中…' : 'Sending…')
                                : (isZh ? '提交反馈' : 'Submit')),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro(bool isZh) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      isZh
          ? '遇到问题或有好点子？告诉我们。点选分类后写几句描述就能提交，其余都是选填。'
          : 'Found a problem or have an idea? Pick the categories, write a few lines, and send. Everything else is optional.',
      style: TextStyle(fontSize: 14, height: 1.5, color: cs.onSurfaceVariant),
    );
  }

  String _contentHint(bool isZh) {
    if (_type == 'feature') {
      return isZh
          ? '希望增加什么功能？在什么场景下会用到？'
          : 'What would you like? When would you use it?';
    }
    if (_isProblem) {
      return isZh
          ? '发生了什么？比如：搜索某本书后点下载，进度卡在 99% 不动'
          : 'What happened? e.g. download stuck at 99% after searching a book';
    }
    return isZh ? '请尽量具体地描述' : 'Please be as specific as you can';
  }

  List<Widget> _problemSection(bool isZh) {
    return [
      const SizedBox(height: 20),
      FeedbackSectionLabel(
        title: isZh ? '影响程度' : 'Severity',
        required: false,
        isZh: isZh,
      ),
      FeedbackSeveritySelector(
        selected: _severity,
        isZh: isZh,
        onChanged: (v) => setState(() => _severity = v),
      ),
      const SizedBox(height: 12),
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _showDetails,
          onExpansionChanged: (v) => _showDetails = v,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
            isZh
                ? '补充复现步骤（选填，能帮我们更快修好）'
                : 'Steps to reproduce (optional, helps us fix faster)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          children: [
            _detailField(
              _stepsCtrl,
              isZh ? '操作步骤' : 'Steps',
              isZh ? '1. 打开…\n2. 点击…' : '1. Open…\n2. Tap…',
              3,
            ),
            _detailField(
              _expectedCtrl,
              isZh ? '期望结果' : 'Expected',
              isZh ? '本来应该…' : 'It should…',
              1,
            ),
            _detailField(
              _actualCtrl,
              isZh ? '实际结果' : 'Actual',
              isZh ? '实际却…' : 'But actually…',
              1,
            ),
          ],
        ),
      ),
    ];
  }

  Widget _detailField(
    TextEditingController c,
    String label,
    String hint,
    int minLines,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        minLines: minLines,
        maxLines: minLines + 3,
        maxLength: _detailMax,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  Future<void> _submit(bool isZh, DeviceDiagnostics diag) async {
    setState(() => _triedSubmit = true);
    final formOk = _formKey.currentState!.validate();
    if (!formOk || _type == null || _area == null) return;
    FocusScope.of(context).unfocus();

    // 必须登录 SCC：未登录先扫码，扫码成功后继续提交
    if (!ref.read(backendAuthProvider).isAuthorized) {
      final ok = await Navigator.pushNamed(context, AppRoutes.qrAuth);
      if (ok != true || !mounted) return;
    }
    final token = ref.read(backendAuthProvider).jwt!;

    setState(() {
      _submitting = true;
      _errorMessage = _errorDetail = null;
    });
    try {
      await _submitter.submit(
        token: token,
        diagnostics: diag,
        draft: FeedbackDraft(
          type: _type!,
          area: _area!,
          severity: _isProblem ? _severity : null,
          title: _titleCtrl.text,
          content: _contentCtrl.text,
          steps: _isProblem ? _stepsCtrl.text : null,
          expected: _isProblem ? _expectedCtrl.text : null,
          actual: _isProblem ? _actualCtrl.text : null,
          diagnosticsConsent: _consent,
        ),
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await _showSuccess(isZh);
    } on FeedbackApiException catch (e) {
      if (e.statusCode == 401) {
        // 本地判有效但服务端拒绝 → 清掉失效 token，下次提交会弹扫码
        await ref.read(backendAuthProvider.notifier).logout();
      }
      _showError(_messageFor(e, isZh), e.toString());
    } catch (e) {
      _showError(isZh ? '提交失败，请稍后重试' : 'Submit failed, please retry', '$e');
    }
  }

  String _messageFor(FeedbackApiException e, bool isZh) =>
      switch (e.statusCode) {
        401 =>
          isZh
              ? '登录已失效，请再次点击提交并重新扫码'
              : 'Session expired. Tap submit again to sign in.',
        403 => isZh ? '反馈通道暂时关闭' : 'Feedback is currently disabled',
        422 => isZh ? '内容格式有误' : 'Invalid content',
        429 =>
          isZh
              ? '提交太频繁了，请一小时后再试'
              : 'Too many submissions, try again in an hour',
        null => isZh ? '网络连接失败，请检查网络后重试' : 'Network error, please retry',
        _ => isZh ? '提交失败，请稍后重试' : 'Submit failed, please retry',
      };

  void _showError(String message, String detail) {
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _errorMessage = message;
      _errorDetail = detail;
    });
  }

  Future<void> _showSuccess(bool isZh) async {
    final goMine = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          size: 48,
          color: Colors.green,
        ),
        title: Text(isZh ? '收到啦，谢谢你！' : 'Thanks for your feedback!'),
        content: Text(
          isZh
              ? '处理进度可在「我的反馈」里查看，修好后会标注修复版本。'
              : 'Track progress in "My feedback". We will mark the fixed version once resolved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isZh ? '查看我的反馈' : 'My feedback'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isZh ? '完成' : 'Done'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (goMine == true) {
      Navigator.pushReplacementNamed(context, AppRoutes.myFeedback);
    } else {
      Navigator.pop(context);
    }
  }

  Future<bool> _confirmDiscard(bool isZh) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isZh ? '放弃这条反馈？' : 'Discard this feedback?'),
        content: Text(
          isZh ? '已填写的内容不会保存。' : 'What you have written will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isZh ? '继续填写' : 'Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isZh ? '放弃' : 'Discard'),
          ),
        ],
      ),
    );
    return r == true;
  }
}
