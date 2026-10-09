import 'package:dio/dio.dart';

/// 与桌面端（OlibTauri）LAN 无线传书服务的对接客户端。
///
/// 契约见 dev_docs/req_OlibTauri.md 与 OlibTauri/dev_docs/mobile-sync.md：
/// - `GET /api/info`（免认证）确认对端是 Olib 桌面端
/// - `GET /api/files` 文件列表 `[{ name, size, extension }]`
/// - `GET /download/{filename}` 下载单个文件
/// - `POST /api/booklist` 推送书单（需 token）
/// - `POST /api/upload` 推送书籍文件（multipart 字段 file，需 token）
///
/// token 来自扫码 URL 的 `?token=` 参数，请求时以 query 或 `X-Olib-Token`
/// header 携带；仅在配对会话内存中缓存（桌面重启即失效）。

/// 扫码得到的对端地址（`http://IP:8765`，阶段 2 起带 `?token=`）。
class LanPeer {
  final String baseUrl;
  final String? token;

  const LanPeer({required this.baseUrl, this.token});

  /// 解析二维码内容。非合法的 http(s) 地址返回 null。
  static LanPeer? tryParse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    final token = uri.queryParameters['token'];
    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return LanPeer(baseUrl: base, token: (token?.isEmpty ?? true) ? null : token);
  }
}

/// `GET /api/info` 响应 — 对端身份。
class LanPeerInfo {
  final String app;
  final String version;
  final String deviceName;
  final List<String> capabilities;

  const LanPeerInfo({
    required this.app,
    required this.version,
    required this.deviceName,
    required this.capabilities,
  });

  /// 是否为 Olib 桌面端（非此响应则提示"不是 Olib 桌面端"）。
  bool get isOlibDesktop => app == 'olib-desktop';

  bool hasCapability(String cap) => capabilities.contains(cap);

  factory LanPeerInfo.fromJson(Map<String, dynamic> json) {
    return LanPeerInfo(
      app: json['app'] as String? ?? '',
      version: json['version'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? '',
      capabilities: (json['capabilities'] as List?)?.cast<String>() ?? const [],
    );
  }
}

/// `GET /api/files` 条目。
class LanFile {
  final String name;
  final int size;
  final String extension;

  const LanFile({required this.name, required this.size, required this.extension});

  factory LanFile.fromJson(Map<String, dynamic> json) {
    return LanFile(
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      extension: json['extension'] as String? ?? '',
    );
  }
}

/// `POST /api/booklist` 结果。
class LanBooklistResult {
  final int imported;
  final int skipped;

  const LanBooklistResult({required this.imported, required this.skipped});

  factory LanBooklistResult.fromJson(Map<String, dynamic> json) {
    return LanBooklistResult(
      imported: (json['imported'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 写请求缺 token / token 失效（401）。
class LanAuthException implements Exception {
  const LanAuthException();
}

/// 文件超过桌面侧大小上限（413，默认 500 MB）。
class LanFileTooLargeException implements Exception {
  const LanFileTooLargeException();
}

/// 文件名非法 / 扩展名不在桌面侧白名单（400）。
class LanRejectedException implements Exception {
  final String? detail;
  const LanRejectedException([this.detail]);
}

class LanClient {
  final LanPeer peer;
  late final Dio _dio;

  LanClient(this.peer) {
    _dio = Dio(BaseOptions(
      baseUrl: peer.baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        if (peer.token != null) 'X-Olib-Token': peer.token,
      },
    ));
  }

  /// 确认对端身份（免认证）。
  Future<LanPeerInfo> getInfo() async {
    final response = await _dio.get('/api/info');
    return LanPeerInfo.fromJson(response.data as Map<String, dynamic>);
  }

  /// 拉取共享文件列表。
  Future<List<LanFile>> listFiles() async {
    final response = await _dio.get('/api/files');
    final list = response.data as List;
    return list
        .map((e) => LanFile.fromJson(e as Map<String, dynamic>))
        .where((f) => f.name.isNotEmpty)
        .toList();
  }

  /// 单文件下载 URL（download_provider 的 presetUrl 用裸 Dio，
  /// token 走 query 参数携带）。
  String downloadUrl(String fileName) {
    final encoded = Uri.encodeComponent(fileName);
    final token = peer.token;
    return '${peer.baseUrl}/download/$encoded'
        '${token != null ? '?token=${Uri.encodeQueryComponent(token)}' : ''}';
  }

  /// 推送书单（codec v1 结构原样），需 token。
  Future<LanBooklistResult> pushBooklist(Map<String, dynamic> booklistJson) async {
    try {
      final response = await _dio.post('/api/booklist', data: booklistJson);
      return LanBooklistResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapWriteError(e);
    }
  }

  /// 推送书籍文件（multipart 字段 file），需 token。
  Future<void> uploadFile(
    String filePath, {
    required String fileName,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      await _dio.post(
        '/api/upload',
        data: form,
        onSendProgress: onProgress,
        cancelToken: cancelToken,
        // 大文件上传给足时间
        options: Options(sendTimeout: const Duration(minutes: 10)),
      );
    } on DioException catch (e) {
      throw _mapWriteError(e);
    }
  }

  /// 把桌面侧的写端点错误映射为类型化异常，供 UI 分文案提示。
  Object _mapWriteError(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401) return const LanAuthException();
    if (code == 413) return const LanFileTooLargeException();
    if (code == 400) {
      final data = e.response?.data;
      final detail = data is Map ? data['detail']?.toString() : data?.toString();
      return LanRejectedException(detail);
    }
    return e;
  }
}
