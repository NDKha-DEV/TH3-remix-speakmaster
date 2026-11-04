import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:speakmaster_flutter/services/pronunciation_api.dart';

String fixture() =>
    File('test/fixtures/assessment_think.json').readAsStringSync();

http.Response jsonResponse(Object body, int status,
        {Map<String, String> headers = const {}}) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {
      'content-type': 'application/json; charset=utf-8',
      ...headers
    });

http.Response errorResponse(int status, String code,
        {Map<String, String> headers = const {}}) =>
    jsonResponse({
      'error': {
        'code': code,
        'message': code.toLowerCase(),
        'details': {},
        'requestId': 'req-$status'
      }
    }, status, headers: headers);

void main() {
  late File audio;
  late List<http.Request> requests;
  late List<bool> tokenRefreshes;

  setUp(() async {
    audio = File(
        '${Directory.systemTemp.path}/speakmaster_test_${DateTime.now().microsecondsSinceEpoch}.wav');
    await audio.writeAsBytes(List<int>.generate(64, (i) => i));
    requests = [];
    tokenRefreshes = [];
  });

  tearDown(() async {
    if (await audio.exists()) await audio.delete();
  });

  PronunciationApi apiWith(
    Future<http.Response> Function(http.Request req, int call) handler, {
    String? token = 'tok',
    String? debugUid,
  }) {
    var call = 0;
    return PronunciationApi(
      baseUrl: 'http://api.test/',
      debugUid: debugUid,
      idToken: ({bool forceRefresh = false}) async {
        tokenRefreshes.add(forceRefresh);
        return token == null ? null : (forceRefresh ? '$token-fresh' : token);
      },
      backoff: (_) => Duration.zero,
      client: MockClient((req) {
        requests.add(req);
        return handler(req, call++);
      }),
    );
  }

  test('assess sends multipart with auth, idempotency key and fields',
      () async {
    final api = apiWith((req, _) async => http.Response.bytes(
        utf8.encode(fixture()), 201,
        headers: {'content-type': 'application/json; charset=utf-8'}));

    final a =
        await api.assess(audio, 'Think about three things', exerciseId: 's2');

    expect(a.overallScore, 78);
    final req = requests.single;
    expect(req.method, 'POST');
    expect(req.url.toString(), 'http://api.test/api/v1/assessments');
    expect(req.headers['Authorization'], 'Bearer tok');
    expect(req.headers['Idempotency-Key'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(req.headers['content-type'], startsWith('multipart/form-data'));
    final body = latin1.decode(req.bodyBytes);
    expect(body, contains('name="reference_text"'));
    expect(body, contains('Think about three things'));
    expect(body, contains('name="exercise_id"'));
    expect(body, contains('name="locale"'));
    expect(body, contains('name="audio"; filename="'));
  });

  test('retries 503 with the same Idempotency-Key, honouring Retry-After',
      () async {
    final api = apiWith((req, call) async => call == 0
        ? errorResponse(503, 'PROVIDER_UNAVAILABLE',
            headers: {'retry-after': '0'})
        : http.Response.bytes(utf8.encode(fixture()), 200, headers: {
            'content-type': 'application/json',
            'idempotent-replayed': 'true'
          }));

    final a = await api.assess(audio, 'Think about three things');

    expect(a.id, '6f1c0b2e9a4d4c33a1f0d5e7b8c9a012');
    expect(requests, hasLength(2));
    expect(requests[0].headers['Idempotency-Key'],
        requests[1].headers['Idempotency-Key']);
  });

  test('refreshes the token once on 401', () async {
    final api = apiWith((req, call) async =>
        req.headers['Authorization'] == 'Bearer tok-fresh'
            ? http.Response.bytes(utf8.encode(fixture()), 201,
                headers: {'content-type': 'application/json'})
            : errorResponse(401, 'UNAUTHORIZED'));

    await api.assess(audio, 'Think');

    expect(requests, hasLength(2));
    expect(tokenRefreshes, [false, true]);
  });

  test('gives up after a second 401', () async {
    final api =
        apiWith((req, call) async => errorResponse(401, 'UNAUTHORIZED'));
    await expectLater(
      api.assess(audio, 'Think'),
      throwsA(isA<PronunciationApiException>()
          .having((e) => e.code, 'code', 'UNAUTHORIZED')),
    );
    expect(requests, hasLength(2));
  });

  test('user errors are not retried and carry a Vietnamese message', () async {
    final api =
        apiWith((req, call) async => errorResponse(422, 'NO_SPEECH_DETECTED'));
    try {
      await api.assess(audio, 'Think');
      fail('should throw');
    } on PronunciationApiException catch (e) {
      expect(e.statusCode, 422);
      expect(e.code, 'NO_SPEECH_DETECTED');
      expect(e.requestId, 'req-422');
      expect(e.isUserError, isTrue);
      expect(e.isRetryable, isFalse);
      expect(e.userMessage, contains('Không nghe thấy'));
    }
    expect(requests, hasLength(1));
  });

  test('stops retrying after maxAttempts', () async {
    final api = apiWith(
        (req, call) async => errorResponse(503, 'PROVIDER_UNAVAILABLE'));
    await expectLater(
      api.assess(audio, 'Think', maxAttempts: 3),
      throwsA(isA<PronunciationApiException>()
          .having((e) => e.isUserError, 'isUserError', isFalse)),
    );
    expect(requests, hasLength(3));
  });

  test('non-JSON error bodies still produce an exception', () async {
    final api = apiWith((req, call) async => http.Response('Bad gateway', 502));
    await expectLater(
      api.assess(audio, 'Think', maxAttempts: 1),
      throwsA(isA<PronunciationApiException>()
          .having((e) => e.code, 'code', 'HTTP_502')),
    );
  });

  test('uses X-Debug-Uid when there is no Firebase user', () async {
    final api = apiWith(
      (req, call) async => jsonResponse({'items': [], 'nextCursor': null}, 200),
      token: null,
      debugUid: 'demo',
    );
    await api.history();
    expect(requests.single.headers['X-Debug-Uid'], 'demo');
    expect(requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('without token or debug uid fails fast with UNAUTHORIZED', () async {
    final api =
        apiWith((req, call) async => jsonResponse({}, 200), token: null);
    await expectLater(
      api.history(),
      throwsA(isA<PronunciationApiException>()
          .having((e) => e.code, 'code', 'UNAUTHORIZED')),
    );
    expect(requests, isEmpty);
  });

  test('history encodes the cursor and parses the page', () async {
    final api = apiWith((req, call) async => jsonResponse({
          'items': [
            {
              'id': 'a1',
              'createdAt': '2026-11-04T08:30:00Z',
              'referenceText': 'Think',
              'durationMs': 900,
              'scores': {
                'pronunciation': 70,
                'accuracy': 70,
                'fluency': 70,
                'completeness': 100
              },
              'level': 'fair',
            }
          ],
          'nextCursor': 'next+1',
        }, 200));

    final page = await api.history(limit: 10, cursor: 'a b/=');

    expect(requests.single.url.path, '/api/v1/me/assessments');
    expect(requests.single.url.queryParameters,
        {'limit': '10', 'cursor': 'a b/='});
    expect(page.items.single.level, 'fair');
    expect(page.nextCursor, 'next+1');
  });

  test('weakPhonemes, getAssessment and phonemeCatalog', () async {
    final api = apiWith((req, call) async {
      switch (req.url.path) {
        case '/api/v1/me/phoneme-stats':
          return jsonResponse({
            'items': [
              {
                'phoneme': 'θ',
                'attempts': 3,
                'errorCount': 2,
                'avgAccuracy': 40,
                'lastAccuracy': 30,
                'updatedAt': '2026-11-04T08:30:00Z'
              }
            ]
          }, 200);
        case '/api/v1/phonemes':
          return jsonResponse({
            'version': 1,
            'phonemes': [
              {
                'symbol': 'θ',
                'arpabet': 'TH',
                'type': 'consonant',
                'aliases': [],
                'examples': ['think'],
                'vnDifficulty': 3,
                'confusions': ['t', 's'],
                'minimalPairs': [
                  ['think', 'sink']
                ],
                'tipVi': 'Đặt lưỡi giữa hai răng',
                'tipEn': 'Tongue between teeth',
                'vnNote': ''
              }
            ],
            'generalRules': [],
          }, 200);
        default:
          return http.Response.bytes(utf8.encode(fixture()), 200,
              headers: {'content-type': 'application/json'});
      }
    });

    expect((await api.weakPhonemes(limit: 3)).single.phoneme, 'θ');
    expect(requests.last.url.queryParameters['limit'], '3');
    expect((await api.getAssessment('6f1c')).referenceText,
        'Think about three things');
    expect(requests.last.url.path, '/api/v1/assessments/6f1c');
    final catalog = await api.phonemeCatalog();
    expect(catalog.single.minimalPairs.single, ['think', 'sink']);
    expect(catalog.single.vnDifficulty, 3);
  });

  test('isReady reflects /ready status', () async {
    var status = 200;
    final api = apiWith((req, call) async => http.Response('{}', status));
    expect(await api.isReady(), isTrue);
    status = 503;
    expect(await api.isReady(), isFalse);
    expect(requests.last.url.path, '/ready');
  });
}
