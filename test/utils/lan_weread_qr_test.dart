import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olib_mobile/services/lan_client.dart';

/// 记录请求并按预设状态码回包
class _FakeAdapter implements HttpClientAdapter {
  final int status;
  final String body;
  final List<RequestOptions> requests = [];
  _FakeAdapter(this.status, [this.body = '{"ok":true}']);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

LanClient _client(_FakeAdapter adapter) =>
    LanClient(const LanPeer(baseUrl: 'http://192.168.1.2:8765'))
      ..dioForTest.httpClientAdapter = adapter;

void main() {
  const url = 'https://open.weixin.qq.com/connect/confirm?uuid=abc';

  test('showWereadQr posts url and code', () async {
    final adapter = _FakeAdapter(200);
    await _client(adapter).showWereadQr(url: url, code: '0427');
    final req = adapter.requests.single;
    expect(req.path, '/api/weread-qr');
    expect(req.method, 'POST');
    final data = req.data is String ? jsonDecode(req.data as String) : req.data;
    expect(data, {'url': url, 'code': '0427'});
  });

  test('showWereadQr maps 400 to LanRejectedException with detail', () async {
    final adapter = _FakeAdapter(400, '{"detail":"只接受微信授权二维码"}');
    await expectLater(
      _client(adapter).showWereadQr(url: url, code: '0427'),
      throwsA(
        isA<LanRejectedException>().having(
          (e) => e.detail,
          'detail',
          '只接受微信授权二维码',
        ),
      ),
    );
  });

  test('closeWereadQr posts code and swallows errors', () async {
    final ok = _FakeAdapter(200);
    await _client(ok).closeWereadQr('0427');
    expect(ok.requests.single.path, '/api/weread-qr/close');

    // 电脑不在线 / 报错时不抛异常，用户可在电脑上手动关
    await _client(_FakeAdapter(500)).closeWereadQr('0427');
  });
}
