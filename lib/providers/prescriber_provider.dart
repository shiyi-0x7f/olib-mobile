import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prescription.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../services/ai_service.dart';
import '../utils/quota_phrases.dart';
import 'zlibrary_provider.dart';
import 'backend_auth_provider.dart';

/// AI 服务 Provider — 读取后端 JWT 注入
final aiServiceProvider = Provider<AiService>((ref) {
  final authState = ref.watch(backendAuthProvider);
  return RemoteAiService(token: authState.jwt ?? '');
});

/// 诊断状态
enum PrescriberStatus { idle, loading, done, error }

/// 错误分类 — 给 UI 区分展示样式 / 是否提供重试入口
/// - [generic]: 网络 / 服务器 / AI 偏差等真错误，需要展示 "寻书失败" 标题 + 重试
/// - [quota]:  当日配额耗尽（含 AI 调用配额 / 全局预算），重试无意义，
///             改用温和的文学化文案 + 隐藏重试按钮
enum PrescriberErrorKind { generic, quota }

/// 诊断器状态
class PrescriberState {
  final PrescriberStatus status;
  final ReadingBag? result;
  final String? errorMessage;
  final PrescriberErrorKind errorKind;
  final String? preferredFormat; // 用户首选格式：pdf / epub / mobi / null(不限)

  const PrescriberState({
    this.status = PrescriberStatus.idle,
    this.result,
    this.errorMessage,
    this.errorKind = PrescriberErrorKind.generic,
    this.preferredFormat,
  });

  PrescriberState copyWith({
    PrescriberStatus? status,
    ReadingBag? result,
    String? errorMessage,
    PrescriberErrorKind? errorKind,
    String? preferredFormat,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return PrescriberState(
      status: status ?? this.status,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorKind: errorKind ?? this.errorKind,
      preferredFormat: preferredFormat ?? this.preferredFormat,
    );
  }
}

/// 诊断器 StateNotifier
class PrescriberNotifier extends StateNotifier<PrescriberState> {
  final AiService _aiService;
  final ZLibraryApi _api;

  // 每次新诊断递增；旧的异步循环检测到不匹配则自我退出
  int _generation = 0;
  CancelToken? _diagnoseCancelToken;

  PrescriberNotifier(this._aiService, this._api)
      : super(const PrescriberState());

  /// 设置首选格式
  void setFormat(String? format) {
    state = state.copyWith(preferredFormat: format);
  }

  /// 执行诊断
  Future<void> diagnose({
    required String input,
    String inputType = 'auto',
    String language = 'zh',
  }) async {
    final gen = ++_generation;
    _diagnoseCancelToken?.cancel('new diagnose');
    final cancelToken = _diagnoseCancelToken = CancelToken();

    state = PrescriberState(
      status: PrescriberStatus.loading,
      preferredFormat: state.preferredFormat,
    );

    try {
      final bag = await _aiService.diagnose(
        input: input,
        inputType: inputType,
        language: language,
        cancelToken: cancelToken,
      );
      if (gen != _generation || !mounted) return;
      state = PrescriberState(
        status: PrescriberStatus.done,
        result: bag,
        preferredFormat: state.preferredFormat,
      );

      // 异步匹配 z站 书籍
      _matchBooks(bag, gen);
    } catch (e) {
      if (gen != _generation || !mounted) return;
      if (e is DioException && CancelToken.isCancel(e)) return;
      // AI 配额耗尽 → 切文学化文案 + errorKind=quota，UI 据此换样式
      String message;
      PrescriberErrorKind kind;
      if (e is AiUserQuotaExceeded) {
        message = QuotaPhrases.randomFrom(QuotaPhrases.aiQuota);
        kind = PrescriberErrorKind.quota;
      } else if (e is AiGlobalQuotaExceeded) {
        message = QuotaPhrases.randomFrom(QuotaPhrases.aiGlobal);
        kind = PrescriberErrorKind.quota;
      } else {
        message = _cleanError(e);
        kind = PrescriberErrorKind.generic;
      }
      state = PrescriberState(
        status: PrescriberStatus.error,
        errorMessage: message,
        errorKind: kind,
        preferredFormat: state.preferredFormat,
      );
    }
  }

  /// 异步匹配每本书的 z站 资源
  Future<void> _matchBooks(ReadingBag bag, int gen) async {
    for (int i = 0; i < bag.tips.length; i++) {
      if (gen != _generation || !mounted) return;
      final tip = bag.tips[i];

      // 标记正在搜索
      _updateTip(gen, i, (t) => t.copyWith(isSearching: true));

      try {
        final fmt = state.preferredFormat;
        Book? matchedBook = await _searchBook(
          tip.bookName,
          tip.author,
          fmt: fmt,
        );
        // 指定格式没找到时，降级用不限格式再搜一次
        if (matchedBook == null && fmt != null) {
          matchedBook = await _searchBook(tip.bookName, tip.author);
        }
        // 仍然没有时，仅按书名搜
        if (matchedBook == null) {
          matchedBook = await _searchBook(tip.bookName, '');
        }

        if (gen != _generation || !mounted) return;
        _updateTip(
          gen,
          i,
          (t) => t.copyWith(matchedBook: matchedBook, isSearching: false),
        );
      } catch (_) {
        if (gen != _generation || !mounted) return;
        _updateTip(gen, i, (t) => t.copyWith(isSearching: false));
      }
    }
  }

  Future<Book?> _searchBook(String bookName, String author, {String? fmt}) async {
    final query = author.isEmpty ? bookName : '$bookName $author';
    final response = await _api.search(
      message: query,
      extensions: fmt != null ? [fmt] : null,
      limit: 5,
    );
    if (response.success && response.data != null && response.data!.isNotEmpty) {
      return response.data!.first;
    }
    return null;
  }

  void _updateTip(int gen, int index, ReadingTip Function(ReadingTip) update) {
    if (gen != _generation || !mounted) return;
    final result = state.result;
    if (result == null || index >= result.tips.length) return;
    final newTips = List<ReadingTip>.from(result.tips);
    newTips[index] = update(newTips[index]);
    state = state.copyWith(result: result.copyWith(tips: newTips));
  }

  String _cleanError(Object e) {
    final s = e.toString();
    // 去掉 "Exception: " 前缀
    if (s.startsWith('Exception: ')) return s.substring(11);
    return s;
  }

  /// 重置状态（保留格式设置）
  void reset() {
    _generation++;
    _diagnoseCancelToken?.cancel('reset');
    _diagnoseCancelToken = null;
    state = PrescriberState(preferredFormat: state.preferredFormat);
  }

  @override
  void dispose() {
    _diagnoseCancelToken?.cancel('dispose');
    super.dispose();
  }
}

/// Provider — 当 JWT 变化时自动重建（ref.watch）
final prescriberProvider =
    StateNotifierProvider<PrescriberNotifier, PrescriberState>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final api = ref.watch(zlibraryApiProvider);
  return PrescriberNotifier(aiService, api);
});
