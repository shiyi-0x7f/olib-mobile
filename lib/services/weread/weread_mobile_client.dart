import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

import 'weread_private_channel.dart';

class WereadMobileException implements Exception {
  final String message;
  final bool outcomeUnknown;

  const WereadMobileException(this.message, {this.outcomeUnknown = false});

  @override
  String toString() => message;
}

class WereadMobileQr {
  final String uuid;
  final String confirmUrl;
  const WereadMobileQr(this.uuid, this.confirmUrl);
}

class WereadImportResult {
  final String bookId;
  const WereadImportResult(this.bookId);

  Uri get deepLink => Uri.parse('https://weread.qq.com/web/reader/$bookId');
}

class _Session {
  final String vid;
  final String accessToken;
  final String refreshToken;
  final String deviceId;

  const _Session(this.vid, this.accessToken, this.refreshToken, this.deviceId);

  factory _Session.fromJson(Map<String, dynamic> json) => _Session(
    json['vid'] as String,
    json['accessToken'] as String,
    json['refreshToken'] as String,
    json['deviceId'] as String,
  );

  String encode() => jsonEncode({
    'vid': vid,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'deviceId': deviceId,
  });
}

/// Shared QR session for WeRead browsing, search, import and AI requests.
class WereadMobileClient {
  WereadMobileClient({WereadPrivateChannel? privateChannel})
    : _private = privateChannel ?? const WereadPrivateChannel(),
      _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 70),
          validateStatus: (status) => status != null && status < 600,
        ),
      );

  static const _baseUrl = 'https://i.weread.qq.com';
  static const _userAgent =
      'WeRead/2.1.2 WRBrand/Onyx wr_eink Dalvik/2.1.0 (Linux; U; Android 11; BOOX Build/onyx)';
  static const _versionHeaders = <String, String>{
    'baseapi': '30',
    'appver': '2.1.2.10245900',
    'basever': '2.1.2.10245900',
    'osver': '11',
    'channelId': '900',
    'User-Agent': _userAgent,
  };

  final Dio _dio;
  final WereadPrivateChannel _private;
  final Random _random = Random.secure();
  _Session? _session;
  bool _loaded = false;
  Future<void>? _refreshing;

  Future<bool> get isConnected async {
    await _load();
    return _session != null;
  }

  String? get connectedVid => _session?.vid;

  Future<void> _load() async {
    if (_loaded) return;
    final raw = await _private.readSession();
    if (raw != null) {
      try {
        _session = _Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        throw const WereadMobileException(
          'Saved WeRead connection is invalid. Disconnect and scan again.',
        );
      }
    }
    _loaded = true;
  }

  Future<void> disconnect() async {
    await _private.deleteSession();
    _session = null;
    _loaded = true;
  }

  String _digits(int count) =>
      List.generate(count, (_) => _random.nextInt(10)).join();

  WereadMobileException _transportError(
    String operation,
    DioException error,
  ) => WereadMobileException(
    '$operation transport failed (${error.type.name}, HTTP ${error.response?.statusCode ?? 0})',
  );

  Map<String, dynamic> _body(
    Response<dynamic> response,
    String operation, {
    bool allowHttpError = false,
  }) {
    final status = response.statusCode ?? 0;
    final raw = response.data;
    Object? decoded = raw;
    // WeChat can return JSON with a non-JSON Content-Type. Dio then leaves the
    // body as a String, while weread-omni parses the bytes as JSON regardless.
    if (raw is String) {
      if (raw.length > 1024 * 1024) {
        throw WereadMobileException(
          '$operation response is too large (HTTP $status)',
        );
      }
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        final contentType = response.headers.value(Headers.contentTypeHeader);
        final kind = contentType?.split(';').first.trim().toLowerCase();
        final safeKind = switch (kind) {
          'application/json' => 'JSON',
          'text/plain' => 'text',
          'text/html' => 'HTML',
          _ => 'unknown',
        };
        throw WereadMobileException(
          '$operation returned non-JSON (HTTP $status, $safeKind response)',
        );
      }
    }
    if (decoded is! Map) {
      throw WereadMobileException(
        '$operation returned an unexpected response (HTTP $status)',
      );
    }
    if (!allowHttpError && (status >= 400 || status == 0)) {
      final code = decoded['errcode'] ?? decoded['errCode'];
      final safeCode =
          code is num ||
              code is String && RegExp(r'^-?\d{1,10}$').hasMatch(code)
          ? ', code $code'
          : '';
      throw WereadMobileException('$operation failed (HTTP $status$safeCode)');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<WereadMobileQr> requestQr({CancelToken? cancelToken}) async {
    Response<dynamic> ticketResponse;
    try {
      ticketResponse = await _dio.get<dynamic>(
        '$_baseUrl/wxticket',
        queryParameters: {'nonceStr': 'weread'},
        options: Options(headers: _versionHeaders),
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      throw _transportError('QR ticket', error);
    }
    final ticket = _body(ticketResponse, 'QR ticket');
    final signature = ticket['signature'];
    final timestamp = ticket['timeStamp'];
    if (signature is! String || timestamp == null) {
      throw const WereadMobileException('QR ticket is incomplete');
    }
    final uri = Uri.https('open.weixin.qq.com', '/connect/sdk/qrconnect', {
      'appid': 'wxab9b71ad2b90ff34',
      'noncestr': 'weread',
      'timestamp': '$timestamp',
      'scope': 'snsapi_userinfo,snsapi_timeline,snsapi_friend',
      'signature': signature,
    });
    Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        uri.toString(),
        options: Options(headers: {'User-Agent': _userAgent}),
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      throw _transportError('WeChat QR', error);
    }
    final json = _body(response, 'WeChat QR');
    final uuid = json['uuid'];
    final code = int.tryParse('${json['errcode']}');
    if (code != 0) {
      throw WereadMobileException(
        'WeChat QR was rejected (HTTP ${response.statusCode}, code ${code ?? 'missing'})',
      );
    }
    if (uuid is! String || uuid.isEmpty) {
      throw WereadMobileException(
        'WeChat QR response omitted UUID (HTTP ${response.statusCode})',
      );
    }
    return WereadMobileQr(
      uuid,
      Uri.https('open.weixin.qq.com', '/connect/confirm', {
        'uuid': uuid,
      }).toString(),
    );
  }

  Future<void> waitForQr(
    WereadMobileQr qr, {
    CancelToken? cancelToken,
    void Function(String status)? onStatus,
  }) async {
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    int? last;
    while (DateTime.now().isBefore(deadline)) {
      if (cancelToken?.isCancelled == true) {
        throw const WereadMobileException('QR login cancelled');
      }
      Response<dynamic> response;
      try {
        response = await _dio.get<dynamic>(
          'https://long.open.weixin.qq.com/connect/l/qrconnect',
          queryParameters: {
            'f': 'json',
            'uuid': qr.uuid,
            if (last != null) 'last': last,
          },
          options: Options(headers: {'User-Agent': 'Mozilla/5.0'}),
          cancelToken: cancelToken,
        );
      } on DioException catch (error) {
        throw _transportError('QR poll', error);
      }
      final data = _body(response, 'QR poll');
      final status = int.tryParse('${data['wx_errcode']}');
      if (status == 405) {
        final code = data['wx_code'];
        if (code is! String || code.isEmpty) {
          throw const WereadMobileException('QR confirmation returned no code');
        }
        onStatus?.call('confirmed');
        await _exchange(code, cancelToken: cancelToken);
        return;
      }
      if (status == 404) onStatus?.call('scanned');
      if (status == 402) throw const WereadMobileException('QR code expired');
      if (status == 403) {
        throw const WereadMobileException('QR login was declined');
      }
      if (status != 404 && status != 408) {
        throw WereadMobileException('Unexpected QR status: $status');
      }
      last = status;
      if (status == 408) await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw const WereadMobileException('QR login timed out');
  }

  Future<void> _exchange(String code, {CancelToken? cancelToken}) async {
    final deviceId = 'eink334691225${_digits(19)}';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(1000);
    final signature = await _private.sha256('$timestamp$deviceId$random');
    Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '$_baseUrl/login',
        data: {
          'appFirstInstall': 1,
          'code': code,
          'deviceId': deviceId,
          'deviceName': 'BOOX',
          'installId': 'eink31${_digits(26)}',
          'isAutoLogout': 0,
          'isFromQrcode': 1,
          'random': random,
          'signature': signature,
          'timestamp': timestamp,
          'trackId': '',
          'deviceType': 3,
        },
        options: Options(
          headers: {
            ..._versionHeaders,
            'content-type': 'application/json; charset=UTF-8',
          },
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      throw _transportError('QR login', error);
    }
    final json = _body(response, 'QR login');
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    final vid = json['vid']?.toString();
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty ||
        vid == null ||
        vid.isEmpty) {
      final errorCode = int.tryParse('${json['errCode']}');
      throw WereadMobileException(
        'QR login returned incomplete credentials (HTTP ${response.statusCode}, code ${errorCode ?? 'missing'})',
      );
    }
    final session = _Session(vid, access, refresh, deviceId);
    await _private.writeSession(session.encode());
    _session = session;
    _loaded = true;
  }

  Future<void> _refresh() async {
    final pending = _refreshing;
    if (pending != null) return pending;
    final started = _refreshOnce();
    _refreshing = started;
    try {
      await started;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _refreshOnce() async {
    final current = _session;
    if (current == null) {
      throw const WereadMobileException('Connect WeRead first');
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(1000) + 1;
    final signature = await _private.sha256(
      '$timestamp${current.deviceId}$random',
    );
    final response = await _dio.post<dynamic>(
      '$_baseUrl/login',
      data: {
        'deviceId': current.deviceId,
        'deviceName': 'BOOX',
        'inBackground': 0,
        'kickType': 1,
        'random': random,
        'refCgi': '',
        'refreshToken': current.refreshToken,
        'signature': signature,
        'timestamp': timestamp,
        'trackId': '',
        'deviceType': 3,
      },
      options: Options(
        headers: {
          ..._versionHeaders,
          'content-type': 'application/json; charset=UTF-8',
        },
      ),
    );
    final json = _body(response, 'Session refresh');
    final vid = json['vid']?.toString() ?? current.vid;
    final access = json['accessToken'];
    final refresh = json['refreshToken'] ?? current.refreshToken;
    if (vid != current.vid ||
        access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw const WereadMobileException(
        'Session refresh returned a different or incomplete account',
      );
    }
    final updated = _Session(vid, access, refresh, current.deviceId);
    await _private.writeSession(updated.encode());
    _session = updated;
  }

  Future<Map<String, dynamic>> call(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    bool replayable = false,
    CancelToken? cancelToken,
  }) async {
    await _load();
    if (_session == null) {
      throw const WereadMobileException('Connect WeRead first');
    }
    if (!path.startsWith('/') || path.startsWith('//')) {
      throw ArgumentError.value(path, 'path');
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = _session!;
      Response<dynamic> response;
      try {
        response = await _dio.request<dynamic>(
          '$_baseUrl$path',
          data: body,
          queryParameters: query,
          options: Options(
            method: method,
            headers: {
              ..._versionHeaders,
              'vid': token.vid,
              'accessToken': token.accessToken,
              if (body != null)
                'content-type': 'application/json; charset=UTF-8',
            },
          ),
          cancelToken: cancelToken,
        );
      } on DioException {
        throw WereadMobileException(
          '$path request failed',
          outcomeUnknown: method == 'POST' && !replayable,
        );
      }
      if (response.statusCode == 401 && attempt == 0) {
        await _refresh();
        if (method == 'GET' || replayable) continue;
        throw const WereadMobileException(
          'Session was refreshed; write outcome is unknown',
          outcomeUnknown: true,
        );
      }
      final data = _body(response, path, allowHttpError: true);
      final rawErrorCode = data.containsKey('errCode')
          ? data['errCode']
          : data['errcode'];
      final errorCode = rawErrorCode == null
          ? null
          : int.tryParse('$rawErrorCode');
      if (rawErrorCode != null && errorCode == null) {
        throw WereadMobileException('$path returned invalid error code');
      }
      if (errorCode == -2012 && attempt == 0) {
        await _refresh();
        if (method == 'GET' || replayable) continue;
        throw const WereadMobileException(
          'Session was refreshed; write outcome is unknown',
          outcomeUnknown: true,
        );
      }
      if (response.statusCode == null ||
          response.statusCode! >= 400 ||
          (errorCode != null && errorCode != 0)) {
        throw WereadMobileException(
          '$path failed (HTTP ${response.statusCode ?? 0}, code ${errorCode ?? 'unknown'})',
          outcomeUnknown:
              method == 'POST' &&
              !replayable &&
              (response.statusCode ?? 0) >= 500,
        );
      }
      return data;
    }
    throw WereadMobileException('$path retry exhausted');
  }

  Future<List<String>> suggestions(
    String bookId, {
    CancelToken? cancelToken,
  }) async {
    final data = await call(
      'POST',
      '/ai/chat/suggest',
      body: {'bookId': bookId, 'chapterUid': 0, 'mpReviewId': '', 'range': ''},
      replayable: true,
      cancelToken: cancelToken,
    );
    final found = <String>[];
    for (final field in ['questions', 'questionHints', 'prompts']) {
      final values = data[field];
      if (values is List) {
        for (final item in values) {
          final text = item is String
              ? item
              : item is Map
              ? (item['question'] ?? item['text'])?.toString()
              : null;
          if (text != null && text.trim().isNotEmpty && !found.contains(text)) {
            found.add(text);
          }
        }
      }
    }
    return found;
  }

  Future<String> askBook(
    String bookId,
    String question, {
    CancelToken? cancelToken,
    void Function(String text)? onProgress,
  }) async {
    if (question.trim().isEmpty || question.length > 1000) {
      throw const WereadMobileException(
        'Question length must be 1–1000 characters',
      );
    }
    var chatId = '';
    var sessionId = '';
    var answer = '';
    for (var poll = 0; poll < 80; poll++) {
      if (cancelToken?.isCancelled == true) {
        throw const WereadMobileException('Question cancelled');
      }
      final data = await call(
        'POST',
        '/ai/chatv2',
        body: {
          'accept_text_type': 1,
          'bookId': bookId,
          'query': question.trim(),
          'scene': 1,
          'isPlugin': false,
          'intent': '',
          'weread_opt': {'intent': '', 'query_context': ''},
          'chatid': chatId,
          'session_id': sessionId,
        },
        replayable: chatId.isNotEmpty,
        cancelToken: cancelToken,
      );
      chatId = data['chatid']?.toString() ?? chatId;
      sessionId = data['session_id']?.toString() ?? sessionId;
      final result = data['result'];
      final frame = result is Map ? result['text']?.toString() ?? '' : '';
      if (frame.isNotEmpty) {
        answer = frame;
        onProgress?.call(answer);
      }
      final more = result is Map ? result['has_more'] : null;
      final extra = data['extra_sections'];
      if (more == 0 ||
          (extra is Map && extra['has_more'] == false && frame.isNotEmpty)) {
        if (answer.isEmpty) {
          throw const WereadMobileException('No answer was returned');
        }
        return answer;
      }
      if (chatId.isEmpty) {
        throw const WereadMobileException('Response omitted conversation ID');
      }
      final interval = int.tryParse('${data['request_interval']}') ?? 200;
      await Future<void>.delayed(
        Duration(milliseconds: interval.clamp(0, 1500).toInt()),
      );
    }
    throw const WereadMobileException('The answer did not finish in time');
  }

  Future<WereadImportResult> importBook(
    File file,
    String name, {
    CancelToken? cancelToken,
    void Function(int sent, int total)? onProgress,
  }) async {
    const allowed = {'epub', 'pdf', 'mobi', 'txt', 'azw3'};
    final extension = name.split('.').last.toLowerCase();
    if (!allowed.contains(extension)) {
      throw const WereadMobileException('Unsupported book format');
    }
    final size = await file.length();
    if (size <= 0 || size > 200 * 1024 * 1024) {
      throw const WereadMobileException(
        'Book must be between 1 byte and 200 MB',
      );
    }
    final baseName = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final credential = await call(
      'GET',
      '/cos/getcredential',
      query: {'name': baseName, 'from': ''},
      cancelToken: cancelToken,
    );
    final bucket = credential['bucket']?.toString() ?? '';
    final objectName = credential['ObjectName']?.toString() ?? '';
    final response = credential['Response'];
    final keys = response is Map ? response['Credentials'] : null;
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(bucket) ||
        objectName.isEmpty ||
        objectName.startsWith('//') ||
        objectName.contains('..') ||
        keys is! Map ||
        keys['TmpSecretId'] is! String ||
        keys['TmpSecretKey'] is! String ||
        keys['Token'] is! String) {
      throw const WereadMobileException('Upload credential is incomplete');
    }
    final expiry = int.tryParse('${response['ExpiredTime']}') ?? 0;
    if (expiry <= DateTime.now().millisecondsSinceEpoch ~/ 1000) {
      throw const WereadMobileException('Upload credential expired');
    }
    await _uploadCos(
      file,
      size,
      bucket,
      objectName,
      keys,
      expiry,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
    Map<String, dynamic> notification;
    try {
      notification = await call(
        'POST',
        '/cos/notify',
        query: {'name': name, 'path': objectName, 'cancel': '0'},
        body: {},
        cancelToken: cancelToken,
      );
    } on WereadMobileException catch (error) {
      throw WereadMobileException(
        'Upload finished, but import confirmation failed. Check your WeRead shelf before retrying.',
        outcomeUnknown: error.outcomeUnknown,
      );
    }
    final bookId = notification['bookId']?.toString() ?? '';
    if (notification['status'] != 1 || bookId.isEmpty) {
      throw const WereadMobileException(
        'Upload finished, but import could not be confirmed. Check your WeRead shelf before retrying.',
        outcomeUnknown: true,
      );
    }
    return WereadImportResult(bookId);
  }

  Future<void> _uploadCos(
    File file,
    int size,
    String bucket,
    String objectName,
    Map<dynamic, dynamic> keys,
    int expiry, {
    CancelToken? cancelToken,
    void Function(int, int)? onProgress,
  }) async {
    final host = '$bucket.cos.accelerate.myqcloud.com';
    final key = objectName.replaceFirst(RegExp(r'^/'), '');
    final path = '/${key.split('/').map(Uri.encodeComponent).join('/')}';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final keyTime = '$now;${min(now + 3600, expiry)}';
    final signKey = await _private.hmacSha1(
      keys['TmpSecretKey'] as String,
      keyTime,
    );
    final httpString = 'put\n$path\n\nhost=$host\n';
    final hash = await _private.sha1(httpString);
    final signature = await _private.hmacSha1(
      signKey,
      'sha1\n$keyTime\n$hash\n',
    );
    final auth =
        'q-sign-algorithm=sha1&q-ak=${keys['TmpSecretId']}'
        '&q-sign-time=$keyTime&q-key-time=$keyTime&q-header-list=host'
        '&q-url-param-list=&q-signature=$signature';
    try {
      final response = await _dio.put<dynamic>(
        'https://$host$path',
        data: file.openRead(),
        options: Options(
          contentType: 'application/octet-stream',
          responseType: ResponseType.plain,
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 2),
          headers: {
            'Authorization': auth,
            'x-cos-security-token': keys['Token'],
            Headers.contentLengthHeader: size,
          },
        ),
        cancelToken: cancelToken,
        onSendProgress: onProgress,
      );
      if (response.statusCode != 200) {
        throw WereadMobileException(
          'COS upload failed (HTTP ${response.statusCode ?? 0})',
        );
      }
    } on DioException {
      throw const WereadMobileException(
        'COS upload failed; import was not started',
      );
    }
  }
}
