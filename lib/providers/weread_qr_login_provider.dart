import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/desktop_peer_store.dart';
import '../services/lan_client.dart';
import '../services/weread/weread_mobile_client.dart';
import 'weread_provider.dart';

enum WereadQrPhase { idle, loading, waiting, scanned }

/// 推到电脑失败的原因（电脑不在线时静默改为本机显示，不算失败）
enum WereadRelayIssue { none, outdated, failed }

@immutable
class WereadQrLoginState {
  final WereadQrPhase phase;
  final WereadMobileQr? qr;

  /// 已推到电脑显示时的识别码；null = 只在本机显示
  final String? relayCode;
  final WereadRelayIssue relayIssue;
  final String? relayDetail;

  /// 登录失败原因（下次开始时清空）
  final String? error;

  const WereadQrLoginState({
    this.phase = WereadQrPhase.idle,
    this.qr,
    this.relayCode,
    this.relayIssue = WereadRelayIssue.none,
    this.relayDetail,
    this.error,
  });

  bool get active => phase != WereadQrPhase.idle;

  WereadQrLoginState copyWith({
    WereadQrPhase? phase,
    WereadMobileQr? qr,
    String? relayCode,
    bool clearRelayCode = false,
    WereadRelayIssue? relayIssue,
    String? relayDetail,
  }) => WereadQrLoginState(
    phase: phase ?? this.phase,
    qr: qr ?? this.qr,
    relayCode: clearRelayCode ? null : (relayCode ?? this.relayCode),
    relayIssue: relayIssue ?? this.relayIssue,
    relayDetail: relayDetail ?? this.relayDetail,
    error: error,
  );
}

/// 微信读书扫码登录流程（全局保活）：生成二维码 → 已配对电脑在线则直接推到电脑显示 →
/// 等待微信确认。离开微信读书页不会中断，电脑上的二维码一直保留到登录成功 / 失败 /
/// 过期 / 重新生成 / 取消。
class WereadQrLoginNotifier extends StateNotifier<WereadQrLoginState> {
  final Ref _ref;
  CancelToken? _cancel;
  LanClient? _relayClient;

  WereadQrLoginNotifier(this._ref) : super(const WereadQrLoginState());

  Future<void> start() async {
    _stop();
    final token = _cancel = CancelToken();
    state = const WereadQrLoginState(phase: WereadQrPhase.loading);
    final mobile = _ref.read(wereadMobileClientProvider);
    try {
      final qr = await mobile.requestQr(cancelToken: token);
      if (token.isCancelled) return;
      state = WereadQrLoginState(phase: WereadQrPhase.waiting, qr: qr);
      // 推到电脑不阻塞等待确认：用户可能立刻就去扫本机分享出的码
      _relayToDesktop(qr, token);
      await mobile.waitForQr(
        qr,
        cancelToken: token,
        onStatus: (status) {
          if (!token.isCancelled && status == 'scanned') {
            state = state.copyWith(phase: WereadQrPhase.scanned);
          }
        },
      );
      if (token.isCancelled) return;
      _closeRelay();
      state = const WereadQrLoginState();
      _ref.read(wereadConnectionProvider.notifier).setConnected(true);
    } catch (error) {
      if (token.isCancelled) return;
      _closeRelay();
      state = WereadQrLoginState(
        error: error is WereadMobileException ? error.message : '$error',
      );
    }
  }

  /// 取消本次登录（断开连接、用户主动放弃时）
  void cancel() {
    _stop();
    state = const WereadQrLoginState();
  }

  /// 改为在本机显示二维码（如想发到其他设备扫）：收起电脑上的弹窗
  void showOnPhone() {
    _closeRelay();
    state = state.copyWith(clearRelayCode: true);
  }

  void _stop() {
    _cancel?.cancel('stop');
    _cancel = null;
    _closeRelay();
  }

  Future<void> _relayToDesktop(WereadMobileQr qr, CancelToken token) async {
    final saved = DesktopPeerStore.read();
    if (saved == null) return;
    final client = LanClient(saved.peer);
    try {
      final info = await client.probe();
      if (info == null || token.isCancelled) return; // 电脑不在线：本机显示
      if (!info.hasCapability('weread_qr')) {
        state = state.copyWith(relayIssue: WereadRelayIssue.outdated);
        return;
      }
      final code = Random.secure().nextInt(10000).toString().padLeft(4, '0');
      await client.showWereadQr(url: qr.confirmUrl, code: code);
      if (token.isCancelled || state.qr != qr) {
        client.closeWereadQr(code);
        return;
      }
      _relayClient = client;
      state = state.copyWith(relayCode: code);
    } catch (error) {
      debugPrint('[WereadQr] relay to desktop failed: $error');
      if (token.isCancelled) return;
      state = state.copyWith(
        relayIssue: WereadRelayIssue.failed,
        relayDetail: error is LanRejectedException ? error.detail : '$error',
      );
    }
  }

  /// 通知电脑收起弹窗（不等待结果，失败时用户可在电脑上手动关）
  void _closeRelay() {
    final code = state.relayCode;
    final client = _relayClient;
    _relayClient = null;
    if (code != null && client != null) client.closeWereadQr(code);
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}

final wereadQrLoginProvider =
    StateNotifierProvider<WereadQrLoginNotifier, WereadQrLoginState>(
      (ref) => WereadQrLoginNotifier(ref),
    );
