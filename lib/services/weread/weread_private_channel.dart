import 'package:flutter/services.dart';

/// Platform Keychain/Keystore access and native hashes used by WeRead/COS.
/// Session JSON never enters Hive or app logs.
class WereadPrivateChannel {
  const WereadPrivateChannel();

  static const _channel = MethodChannel('olib/weread_private');

  Future<String?> readSession() => _channel.invokeMethod<String>('read');

  Future<void> writeSession(String value) =>
      _channel.invokeMethod<void>('write', {'value': value});

  Future<void> deleteSession() => _channel.invokeMethod<void>('delete');

  Future<String> sha1(String value) async =>
      (await _channel.invokeMethod<String>('sha1', {'value': value}))!;

  Future<String> sha256(String value) async =>
      (await _channel.invokeMethod<String>('sha256', {'value': value}))!;

  Future<String> hmacSha1(String key, String value) async => (await _channel
      .invokeMethod<String>('hmacSha1', {'key': key, 'value': value}))!;
}
