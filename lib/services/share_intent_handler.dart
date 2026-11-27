import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'booklist_share_codec.dart';

/// 待处理的入站书单（来自系统分享 / 深链 / 文件关联）。
/// 由 FavoritesScreen 监听并消费，消费后置 null。
final pendingBooklistImportProvider =
    StateProvider<BooklistShareData?>((ref) => null);

class ShareIntentHandler {
  final Ref _ref;
  StreamSubscription<List<SharedMediaFile>>? _sub;
  bool _started = false;

  ShareIntentHandler(this._ref);

  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final initial =
          await ReceiveSharingIntent.instance.getInitialMedia();
      await _process(initial);
    } catch (_) {
      // 没有插件 / 平台不支持时静默
    }

    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _process,
      onError: (_) {},
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _process(List<SharedMediaFile> files) async {
    for (final f in files) {
      final raw = await _extractRaw(f);
      if (raw == null || raw.isEmpty) continue;
      final data = BooklistShareCodec.tryDecode(raw);
      if (data != null && data.entries.isNotEmpty) {
        _ref.read(pendingBooklistImportProvider.notifier).state = data;
        break;
      }
    }
    try {
      ReceiveSharingIntent.instance.reset();
    } catch (_) {}
  }

  Future<String?> _extractRaw(SharedMediaFile f) async {
    // v1.8 API：text / url 类型时 path 字段直接是文本内容
    switch (f.type) {
      case SharedMediaType.text:
      case SharedMediaType.url:
        return f.path;
      case SharedMediaType.file:
      case SharedMediaType.image:
      case SharedMediaType.video:
        try {
          return await File(f.path).readAsString();
        } catch (_) {
          return null;
        }
    }
  }
}

final shareIntentHandlerProvider = Provider<ShareIntentHandler>((ref) {
  final h = ShareIntentHandler(ref);
  ref.onDispose(h.dispose);
  return h;
});
