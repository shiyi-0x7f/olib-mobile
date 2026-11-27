import 'hive_service.dart';
import 'lan_client.dart';

/// 记住上次配对成功的电脑（Hive settings 盒），免得每次传书都重新扫码。
///
/// 桌面端目前无认证（OlibTauri `dev_docs/lan-server.md`），记住地址即可；
/// 电脑换网络导致 IP 变化时探测失败，用户在「电脑联动」页重新扫码。
/// 保留 token 字段与 401 处理（[clear]），以备桌面端日后恢复认证。
class SavedDesktop {
  final LanPeer peer;
  final String deviceName;

  const SavedDesktop({required this.peer, required this.deviceName});
}

class DesktopPeerStore {
  static const _key = 'lan_saved_desktop';

  static SavedDesktop? read() {
    final raw = HiveService.settingsBox.get(_key);
    if (raw is! Map) return null;
    final baseUrl = raw['base_url'];
    if (baseUrl is! String || baseUrl.isEmpty) return null;
    final token = raw['token'];
    return SavedDesktop(
      peer: LanPeer(baseUrl: baseUrl, token: token is String ? token : null),
      deviceName: raw['device_name'] as String? ?? '',
    );
  }

  static Future<void> save(LanPeer peer, String deviceName) =>
      HiveService.settingsBox.put(_key, {
        'base_url': peer.baseUrl,
        'token': peer.token,
        'device_name': deviceName,
      });

  static Future<void> clear() => HiveService.settingsBox.delete(_key);
}
