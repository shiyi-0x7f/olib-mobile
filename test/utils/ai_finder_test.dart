import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olib_mobile/services/ai/ai_client.dart';
import 'package:olib_mobile/services/ai/ai_prompt.dart';
import 'package:olib_mobile/services/ai/ai_settings.dart';

const _settings = AiSettings(
  provider: 'openai',
  baseUrl: 'https://api.example.com/v1',
  model: 'm',
  apiKey: 'k',
);

Map<String, dynamic> _bag(int n) => {
  'diagnosis': '短句诊断',
  'tips': [
    for (var i = 0; i < n; i++)
      {'book_name': '书$i', 'author': '作者', 'reason': '理由', 'category': '分类'},
  ],
};

String _completion(String content) => jsonEncode({
  'choices': [
    {
      'message': {'content': content},
    },
  ],
});

/// 依次返回预设响应，并记录每次请求体
class _FakeAdapter implements HttpClientAdapter {
  final List<(int, String)> responses;
  final List<Map<String, dynamic>> requests = [];
  _FakeAdapter(this.responses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.data is String) {
      requests.add(jsonDecode(options.data as String) as Map<String, dynamic>);
    }
    final (status, body) = responses[requests.length - 1];
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

AiClient _client(_FakeAdapter adapter) {
  final dio = Dio(
    BaseOptions(validateStatus: (_) => true, responseType: ResponseType.plain),
  )..httpClientAdapter = adapter;
  return AiClient(dio: dio);
}

void main() {
  group('buildPrompt', () {
    test('maps theme, keeps free text, injects count and extra', () {
      expect(buildPrompt('relax', 'theme', 3, ''), contains('工作压力大'));
      expect(buildPrompt('relax', 'free', 3, ''), contains('"relax"'));
      expect(buildPrompt('想学心理学', 'theme', 3, ''), contains('想学心理学'));
      final p = buildPrompt('relax', 'theme', 5, ' 只要中文书 ');
      expect(p, contains('请推荐 5 本'));
      expect(p, contains('tips 数组固定 5 项'));
      expect(p, contains('用户的补充要求（在不违反以上格式的前提下遵守）：只要中文书'));
      expect(buildPrompt('relax', 'theme', 3, '  '), isNot(contains('补充要求')));
    });
  });

  group('extractJson', () {
    test('plain, fenced and wrapped json', () {
      expect(extractJson('{"a": 1}'), {'a': 1});
      expect(extractJson('```json\n{"a": 1}\n```'), {'a': 1});
      expect(extractJson('Sure! Here is the result:\n```\n{"b": 2}\n```\n'), {
        'b': 2,
      });
    });

    test('strips think block', () {
      expect(extractJson('<think>先想想 {不是 JSON}</think>\n{"d": 4}'), {'d': 4});
    });

    test('rejects non json', () {
      expect(() => extractJson('not json'), throwsA(isA<AiFormatException>()));
    });
  });

  group('validateReadingBag', () {
    test('truncates and filters', () {
      expect(validateReadingBag(_bag(3), 3).tips.length, 3);
      expect(validateReadingBag(_bag(5), 3).tips.length, 3);
      expect(validateReadingBag(_bag(1), 3).tips.length, 1);
    });

    test('rejects malformed', () {
      for (final bad in [
        _bag(0),
        {'tips': []},
        {'diagnosis': 'x'},
        {'diagnosis': 'x', 'tips': 'oops'},
        [1, 2],
      ]) {
        expect(
          () => validateReadingBag(bad, 3),
          throwsA(isA<AiFormatException>()),
        );
      }
    });

    test('drops tips without book name', () {
      final bag = validateReadingBag({
        'diagnosis': 'x',
        'tips': [
          {'book_name': '  '},
          {'book_name': '三体', 'author': 3},
        ],
      }, 3);
      expect(bag.tips.single.bookName, '三体');
      expect(bag.tips.single.author, '');
    });
  });

  group('AiSettings', () {
    test('normalizes and validates', () {
      final s = const AiSettings(
        provider: ' deepseek ',
        baseUrl: ' https://api.deepseek.com/ ',
        model: ' m ',
        apiKey: ' k ',
        tipCount: 99,
      ).normalized();
      expect(s.baseUrl, 'https://api.deepseek.com');
      expect(s.model, 'm');
      expect(s.tipCount, maxTipCount);
      expect(s.validate(), isNull);
      expect(
        AiSettings(
          provider: 'x',
          baseUrl: 'api.x.com',
          model: 'm',
          apiKey: 'k',
        ).validate(),
        isNotNull,
      );
      expect(
        AiSettings(
          provider: 'x',
          baseUrl: 'https://x',
          model: 'm',
          apiKey: 'k',
          extraPrompt: 'a' * (maxExtraPromptChars + 1),
        ).validate(),
        isNotNull,
      );
    });

    test('json round trip', () {
      final s = AiSettings.fromJson(_settings.toJson())!;
      expect(s.baseUrl, _settings.baseUrl);
      expect(s.tipCount, defaultTipCount);
      expect(AiSettings.fromJson('oops'), isNull);
    });
  });

  group('client helpers', () {
    test('chatBody switches params for reasoning models', () {
      final normal = chatBody(_settings, 'hi', 100, false);
      expect(normal['max_tokens'], 100);
      expect(normal['temperature'], 0.8);
      expect(normal.containsKey('max_completion_tokens'), isFalse);
      final compat = chatBody(_settings, 'hi', 100, true);
      expect(compat['max_completion_tokens'], 100);
      expect(compat.containsKey('max_tokens'), isFalse);
      expect(compat.containsKey('temperature'), isFalse);
    });

    test('detects unsupported param errors', () {
      expect(
        needsReasoningCompat(
          400,
          "Unsupported parameter: 'max_tokens'. Use 'max_completion_tokens' instead.",
        ),
        isTrue,
      );
      expect(
        needsReasoningCompat(400, "Unsupported value: 'temperature'"),
        isTrue,
      );
      expect(needsReasoningCompat(400, 'model not found'), isFalse);
      expect(needsReasoningCompat(401, 'max_completion_tokens'), isFalse);
    });

    test('messageContent rejects empty', () {
      expect(messageContent(jsonDecode(_completion('{}'))), '{}');
      expect(
        () => messageContent(jsonDecode(_completion('  '))),
        throwsA(isA<AiFormatException>()),
      );
    });

    test('apiErrorMessage prefers provider message', () {
      final msg = apiErrorMessage(
        401,
        '{"error":{"message":"Invalid API key"}}',
      );
      expect(msg, contains('API Key 无效'));
      expect(msg, contains('Invalid API key'));
      final msg2 = apiErrorMessage(402, 'Insufficient Balance');
      expect(msg2, contains('余额不足'));
      expect(msg2, contains('Insufficient Balance'));
    });
  });

  group('AiClient', () {
    test('retries with reasoning params after 400', () async {
      final adapter = _FakeAdapter([
        (
          400,
          '{"error":{"message":"Unsupported parameter: max_tokens, use max_completion_tokens"}}',
        ),
        (200, _completion(jsonEncode(_bag(3)))),
      ]);
      final bag = await _client(adapter).findBooks(_settings, 'relax', 'theme');
      expect(bag.tips.length, 3);
      expect(adapter.requests[0].containsKey('max_tokens'), isTrue);
      expect(adapter.requests[1].containsKey('max_completion_tokens'), isTrue);
    });

    test('retries once on malformed output, then fails readably', () async {
      final ok = _FakeAdapter([
        (200, _completion('not json')),
        (200, _completion(jsonEncode(_bag(3)))),
      ]);
      expect(
        (await _client(ok).findBooks(_settings, 'x', 'free')).tips,
        hasLength(3),
      );

      final bad = _FakeAdapter([
        (200, _completion('not json')),
        (200, _completion('still not json')),
      ]);
      await expectLater(
        _client(bad).findBooks(_settings, 'x', 'free'),
        throwsA(
          isA<AiServiceException>().having(
            (e) => e.message,
            'message',
            contains('AI 返回格式异常'),
          ),
        ),
      );
    });

    test('maps http errors without retrying', () async {
      final adapter = _FakeAdapter([
        (401, '{"error":{"message":"Invalid API key"}}'),
      ]);
      await expectLater(
        _client(adapter).findBooks(_settings, 'x', 'free'),
        throwsA(
          isA<AiServiceException>().having(
            (e) => e.message,
            'message',
            contains('API Key 无效'),
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });

    test('rejects incomplete settings before any request', () async {
      final adapter = _FakeAdapter([]);
      await expectLater(
        _client(adapter).findBooks(
          const AiSettings(
            provider: 'x',
            baseUrl: 'https://x',
            model: '',
            apiKey: 'k',
          ),
          'x',
          'free',
        ),
        throwsA(isA<AiServiceException>()),
      );
      expect(adapter.requests, isEmpty);
    });
  });
}
