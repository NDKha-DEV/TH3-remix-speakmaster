import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:speakmaster_flutter/models/assessment.dart';
import 'package:speakmaster_flutter/models/models.dart';
import 'package:speakmaster_flutter/services/ai_pronunciation_service.dart';
import 'package:speakmaster_flutter/services/pronunciation_engine.dart';
import 'package:speakmaster_flutter/services/pronunciation_labels.dart';

Map<String, dynamic> loadFixture() =>
    jsonDecode(File('test/fixtures/assessment_think.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('Assessment.fromJson (API v1 contract)', () {
    test('parses scores, words, phonemes and level', () {
      final a = Assessment.fromJson(loadFixture());
      expect(a.id, '6f1c0b2e9a4d4c33a1f0d5e7b8c9a012');
      expect(a.createdAt.toUtc(), DateTime.utc(2026, 11, 4, 8, 30));
      expect(a.overallScore, 78);
      expect(a.scores.prosody, 81.0);
      expect(a.level, 'good');
      expect(a.isAcousticAssessment, isTrue);
      expect(a.words, hasLength(2));

      final th = a.words.first.phonemes.first;
      expect(th.expected, 'θ');
      expect(th.actual, 's');
      expect(th.errorKind, 'substitution');
      expect(th.pattern, 'th_substitution');
      expect(th.position, 'initial');
      expect(a.words.first.errorPhonemes, hasLength(1));
    });

    test('tolerates unknown fields and enum values', () {
      final a = Assessment.fromJson(loadFixture());
      final things = a.words[1];
      expect(things.errorType, 'SomeNewType');
      expect(
          PronunciationLabels.wordErrorType(things.errorType), 'SomeNewType');
      expect(PronunciationLabels.errorKind(things.phonemes[1].errorKind),
          'Lỗi phát âm');
      expect(PronunciationLabels.pattern('not_yet_known'), isNotNull);
      expect(things.phonemes.first.actual, isNull);
    });

    test('sorts feedback by priority and builds a summary', () {
      final a = Assessment.fromJson(loadFixture());
      expect(a.feedback.map((f) => f.priority), [1, 2]);
      expect(a.feedback.first.minimalPair, ['think', 'sink']);
      expect(a.summaryVi, contains('Tốt lắm'));
      expect(a.summaryVi, contains('/θ/'));
      expect(a.expectedIpa, '/θɪŋk θɪŋz/');
    });

    test('null prosody and missing level fall back safely', () {
      final j = loadFixture()
        ..['scores'] = {
          'pronunciation': 55,
          'accuracy': 50,
          'fluency': 60,
          'completeness': 90,
          'prosody': null
        }
        ..remove('level');
      final a = Assessment.fromJson(j);
      expect(a.scores.prosody, isNull);
      expect(a.level, 'needs_work');
    });

    test('round-trips through toJson', () {
      final a = Assessment.fromJson(loadFixture());
      final b = Assessment.fromJson(
          jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
      expect(b.words[0].phonemes[0].pattern, 'th_substitution');
      expect(b.feedback.first.practiceWords, ['think', 'three', 'mouth']);
      expect(b.scores.pronunciation, 78.4);
    });
  });

  test('levelOf uses the same thresholds as the server', () {
    expect(Assessment.levelOf(90), 'excellent');
    expect(Assessment.levelOf(89.9), 'good');
    expect(Assessment.levelOf(75), 'good');
    expect(Assessment.levelOf(60), 'fair');
    expect(Assessment.levelOf(59.9), 'needs_work');
  });

  test('history page and phoneme stats parse', () {
    final page = AssessmentPage.fromJson({
      'items': [
        {
          'id': 'a1',
          'createdAt': '2026-11-04T08:30:00Z',
          'referenceText': 'Think',
          'durationMs': 900,
          'scores': {
            'pronunciation': 91,
            'accuracy': 90,
            'fluency': 92,
            'completeness': 100,
            'prosody': null
          },
          'level': 'excellent',
        }
      ],
      'nextCursor': 'abc',
    });
    expect(page.items.single.level, 'excellent');
    expect(page.nextCursor, 'abc');

    final stat = PhonemeStat.fromJson({
      'phoneme': 'θ',
      'attempts': 18,
      'errorCount': 11,
      'avgAccuracy': 48.2,
      'lastAccuracy': 55.0,
      'updatedAt': '2026-11-04T08:30:00Z',
    });
    expect(stat.errorRate, closeTo(11 / 18, 1e-9));
  });

  group('fallback (transcript-based) results', () {
    final service = AIPronunciationService(apiKey: '');

    test('rule-based result maps into Assessment and is flagged as fallback',
        () async {
      final (r, usedGemini) = await service.analyzeWithSource(
        targetText: 'I think that',
        userSpokenText: 'I sink that',
      );
      expect(usedGemini, isFalse);
      final a = Assessment.fromLegacy(
        r,
        referenceText: 'I think that',
        recognizedText: 'I sink that',
        source: AssessmentSource.ruleBased,
        durationMs: 1500,
      );
      expect(a.isAcousticAssessment, isFalse);
      expect(a.provider, 'rule-based');
      expect(a.id, startsWith('local_'));
      expect(a.words.map((w) => w.word), ['I', 'think', 'that']);
      expect(a.words[1].isError, isTrue);
      expect(a.words[0].isError, isFalse);
      expect(a.feedback.any((f) => f.kind == 'praise'), isTrue);
      expect(a.feedback.firstWhere((f) => f.kind == 'phoneme').target, 'think');
      expect(a.level, Assessment.levelOf(r.overallScore.toDouble()));
    });
  });

  group('PronunciationEngine', () {
    test('without API uses transcript mode and session history', () async {
      final engine =
          PronunciationEngine(fallback: AIPronunciationService(apiKey: ''));
      expect(engine.mode, ScoringMode.transcript);
      expect(await engine.refreshAvailability(), ScoringMode.transcript);

      const sentence = LessonSentence(
        id: 's2',
        text: 'I think that',
        translation: '',
        ipa: '',
        category: 'Daily',
        difficulty: 'Beginner',
        focusSound: '',
        tips: '',
      );
      final a = await engine.assessTranscript(
          transcript: 'I sink that', sentence: sentence, durationMs: 1200);
      expect(a.exerciseId, 's2');
      expect(a.durationMs, 1200);
      expect((await engine.history()).items.single.id, a.id);
      expect(await engine.getAssessment(a.id), same(a));
      // Bản dự phòng không có âm vị thật → không tính âm yếu.
      expect(await engine.weakPhonemes(), isEmpty);
      expect(await engine.phonemeCatalog(), isEmpty);
    });

    test('computePhonemeStats aggregates acoustic results, weakest first', () {
      final a = Assessment.fromJson(loadFixture());
      final b = Assessment.fromJson(loadFixture()..['id'] = 'second');
      final stats = PronunciationEngine.computePhonemeStats([a, b]);
      expect(stats.map((s) => s.phoneme), ['z', 'θ']);
      final th = stats.firstWhere((s) => s.phoneme == 'θ');
      expect(th.attempts, 4);
      expect(th.errorCount, 2);
      expect(th.avgAccuracy, closeTo((8 + 80 + 8 + 80) / 4, 1e-9));
      expect(stats.any((s) => s.phoneme == 'ɪ'),
          isFalse); // không có lỗi → không phải âm yếu
    });
  });
}
