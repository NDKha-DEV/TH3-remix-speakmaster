// Kiểm thử hợp đồng với Pronunciation API thật (repo LearnEnglish-vs-AI-pronun).
// Mặc định bị bỏ qua. Cách chạy:
//   (server)  APP_ENV=dev AUTH_MODE=dev PRONUN_PROVIDER=mock uvicorn app.main:app --port 8765
//   (app)     PRONUN_IT_BASE=http://127.0.0.1:8765 flutter test test/integration

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:speakmaster_flutter/services/pronunciation_api.dart';

final _base = Platform.environment['PRONUN_IT_BASE'];

/// WAV 16 kHz mono 16-bit, 1.5 giây âm thanh (không im lặng).
Uint8List _wav({double seconds = 1.5, double freq = 220}) {
  const rate = 16000;
  final n = (rate * seconds).round();
  final data = ByteData(44 + n * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    data.setInt16(44 + i * 2, (sin(2 * pi * freq * i / rate) * 12000).round(),
        Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  final skip =
      _base == null ? 'Đặt PRONUN_IT_BASE để chạy với server thật' : null;
  final uid = 'it_${DateTime.now().millisecondsSinceEpoch}';
  late PronunciationApi api;
  late File audio;

  setUpAll(() async {
    if (_base == null) return;
    api = PronunciationApi(
      baseUrl: _base!,
      debugUid: uid,
      idToken: ({bool forceRefresh = false}) async => null,
    );
    audio = File('${Directory.systemTemp.path}/speakmaster_it_$uid.wav');
    await audio.writeAsBytes(_wav());
  });

  tearDownAll(() async {
    if (_base != null && await audio.exists()) await audio.delete();
  });

  test('server is ready', () async {
    expect(await api.isReady(), isTrue);
  }, skip: skip);

  test('assess → getAssessment → history → phoneme stats → catalog', () async {
    final a = await api.assess(audio, 'I think that this is the best solution',
        exerciseId: 's2');
    expect(a.id, isNotEmpty);
    expect(a.referenceText, 'I think that this is the best solution');
    expect(a.exerciseId, 's2');
    expect(a.scores.pronunciation, inInclusiveRange(0, 100));
    expect(['excellent', 'good', 'fair', 'needs_work'], contains(a.level));
    expect(a.words, isNotEmpty);
    expect(a.words.expand((w) => w.phonemes), isNotEmpty);
    expect(a.feedback.any((f) => f.kind == 'praise'), isTrue);
    expect(a.durationMs, greaterThan(1000));

    final again = await api.getAssessment(a.id);
    expect(again.id, a.id);
    expect(again.words.length, a.words.length);

    final page = await api.history(limit: 5);
    expect(page.items.map((s) => s.id), contains(a.id));

    final weak = await api.weakPhonemes(limit: 10);
    for (final s in weak) {
      expect(s.attempts, greaterThanOrEqualTo(s.errorCount));
    }

    final catalog = await api.phonemeCatalog();
    expect(catalog.map((p) => p.symbol), contains('θ'));
  }, skip: skip);

  test('same Idempotency-Key returns the same attempt', () async {
    const key = 'speakmaster-it-key-1';
    final first = await api.assess(audio, 'Think about three things',
        idempotencyKey: '$key-$uid');
    final second = await api.assess(audio, 'Think about three things',
        idempotencyKey: '$key-$uid');
    expect(second.id, first.id);
  }, skip: skip);

  test('maps server error codes', () async {
    await expectLater(
      api.assess(audio, '12345 !!!'),
      throwsA(isA<PronunciationApiException>()
          .having((e) => e.code, 'code', 'TEXT_INVALID')),
    );
    final silent =
        File('${Directory.systemTemp.path}/speakmaster_it_silent_$uid.wav');
    final bytes = _wav();
    bytes.fillRange(44, bytes.length, 0);
    await silent.writeAsBytes(bytes);
    try {
      await expectLater(
        api.assess(silent, 'Think about three things'),
        throwsA(isA<PronunciationApiException>()
            .having((e) => e.code, 'code', 'NO_SPEECH_DETECTED')
            .having((e) => e.isUserError, 'isUserError', isTrue)),
      );
    } finally {
      await silent.delete();
    }
    await expectLater(
      api.getAssessment('does-not-exist'),
      throwsA(isA<PronunciationApiException>()
          .having((e) => e.statusCode, 'status', 404)),
    );
  }, skip: skip);
}
