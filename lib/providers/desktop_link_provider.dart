import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/desktop_peer_store.dart';
import '../services/lan_client.dart';

enum DesktopLinkStatus {
  /// 从未配对（或已忘记）
  none,
  checking,
  online,

  /// 记住了电脑，但当前连不上（没开无线传书 / 不在同一 Wi-Fi / IP 变了）
  offline,
}

class DesktopLinkState {
  final DesktopLinkStatus status;
  final SavedDesktop? saved;

  const DesktopLinkState(this.status, [this.saved]);

  LanClient? get client =>
      status == DesktopLinkStatus.online ? LanClient(saved!.peer) : null;
}

/// 「电脑联动」页的连接状态：读记住的电脑并探测是否在线。
class DesktopLinkNotifier extends StateNotifier<DesktopLinkState> {
  DesktopLinkNotifier()
    : super(const DesktopLinkState(DesktopLinkStatus.none)) {
    refresh();
  }

  Future<void> refresh() async {
    final saved = DesktopPeerStore.read();
    if (saved == null) {
      state = const DesktopLinkState(DesktopLinkStatus.none);
      return;
    }
    state = DesktopLinkState(DesktopLinkStatus.checking, saved);
    final info = await LanClient(saved.peer).probe();
    if (!mounted) return;
    if (info == null) {
      state = DesktopLinkState(DesktopLinkStatus.offline, saved);
      return;
    }
    // 设备名可能在电脑端改过，顺手更新
    if (info.deviceName != saved.deviceName) {
      await DesktopPeerStore.save(saved.peer, info.deviceName);
    }
    if (!mounted) return;
    state = DesktopLinkState(
      DesktopLinkStatus.online,
      SavedDesktop(peer: saved.peer, deviceName: info.deviceName),
    );
  }

  Future<void> forget() async {
    await DesktopPeerStore.clear();
    if (!mounted) return;
    state = const DesktopLinkState(DesktopLinkStatus.none);
  }
}

final desktopLinkProvider =
    StateNotifierProvider.autoDispose<DesktopLinkNotifier, DesktopLinkState>(
      (ref) => DesktopLinkNotifier(),
    );
