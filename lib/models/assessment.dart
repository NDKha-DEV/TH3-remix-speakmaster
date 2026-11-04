// Hợp đồng dữ liệu M4 – AI Pronunciation (khớp Pronunciation API v1,
// xem docs/M4_AI_PRONUNCIATION.md). Quy ước: bỏ qua field lạ, chấp nhận
// giá trị enum mới (errorType, errorKind, pattern, kind) mà không lỗi.

import 'models.dart';

double _d(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : fallback;
int? _i(Object? v) => v is num ? v.toInt() : null;
String? _s(Object? v) => v is String ? v : null;
List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? v.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
    : const [];
List<String> _strings(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

/// Nguồn chấm điểm của một lần đánh giá.
enum AssessmentSource {
  /// Pronunciation API (wav2vec2 / Azure) chấm trên audio thật.
  api,

  /// Gemini chấm dựa trên transcript (dự phòng khi không có API).
  gemini,

  /// Bộ luật so khớp chữ cục bộ (dự phòng cuối cùng).
  ruleBased,
}

class AssessmentScores {
  final double pronunciation;
  final double accuracy;
  final double fluency;
  final double completeness;
  final double? prosody;

  const AssessmentScores({
    required this.pronunciation,
    required this.accuracy,
    required this.fluency,
    required this.completeness,
    this.prosody,
  });

  factory AssessmentScores.fromJson(Map<String, dynamic> j) => AssessmentScores(
        pronunciation: _d(j['pronunciation']),
        accuracy: _d(j['accuracy']),
        fluency: _d(j['fluency']),
        completeness: _d(j['completeness']),
        prosody: j['prosody'] is num ? _d(j['prosody']) : null,
      );

  Map<String, dynamic> toJson() => {
        'pronunciation': pronunciation,
        'accuracy': accuracy,
        'fluency': fluency,
        'completeness': completeness,
        'prosody': prosody,
      };
}

class PhonemeResult {
  final String expected;
  final String? actual;
  final double accuracy;
  final bool isError;

  /// substitution | deletion | insertion | distortion | null (có thể thêm).
  final String? errorKind;

  /// Lỗi đặc trưng người Việt, vd th_substitution, final_consonant_drop.
  final String? pattern;

  /// initial | medial | final.
  final String? position;
  final int? offsetMs;
  final int? durationMs;

  const PhonemeResult({
    required this.expected,
    this.actual,
    required this.accuracy,
    required this.isError,
    this.errorKind,
    this.pattern,
    this.position,
    this.offsetMs,
    this.durationMs,
  });

  factory PhonemeResult.fromJson(Map<String, dynamic> j) => PhonemeResult(
        expected: _s(j['expected']) ?? '',
        actual: _s(j['actual']),
        accuracy: _d(j['accuracy']),
        isError: j['isError'] == true,
        errorKind: _s(j['errorKind']),
        pattern: _s(j['pattern']),
        position: _s(j['position']),
        offsetMs: _i(j['offsetMs']),
        durationMs: _i(j['durationMs']),
      );

  Map<String, dynamic> toJson() => {
        'expected': expected,
        'actual': actual,
        'accuracy': accuracy,
        'isError': isError,
        'errorKind': errorKind,
        'pattern': pattern,
        'position': position,
        'offsetMs': offsetMs,
        'durationMs': durationMs,
      };
}

class WordResult {
  final String word;
  final String? ipa;
  final double accuracy;

  /// None | Mispronunciation | Omission | Insertion | UnexpectedBreak | ...
  final String errorType;
  final bool isError;
  final int? offsetMs;
  final int? durationMs;
  final List<PhonemeResult> phonemes;

  const WordResult({
    required this.word,
    this.ipa,
    required this.accuracy,
    required this.errorType,
    required this.isError,
    this.offsetMs,
    this.durationMs,
    this.phonemes = const [],
  });

  factory WordResult.fromJson(Map<String, dynamic> j) => WordResult(
        word: _s(j['word']) ?? '',
        ipa: _s(j['ipa']),
        accuracy: _d(j['accuracy']),
        errorType: _s(j['errorType']) ?? 'None',
        isError: j['isError'] == true,
        offsetMs: _i(j['offsetMs']),
        durationMs: _i(j['durationMs']),
        phonemes: _maps(j['phonemes']).map(PhonemeResult.fromJson).toList(),
      );

  List<PhonemeResult> get errorPhonemes =>
      phonemes.where((p) => p.isError).toList();

  Map<String, dynamic> toJson() => {
        'word': word,
        'ipa': ipa,
        'accuracy': accuracy,
        'errorType': errorType,
        'isError': isError,
        'offsetMs': offsetMs,
        'durationMs': durationMs,
        'phonemes': phonemes.map((p) => p.toJson()).toList(),
      };
}

class FeedbackItem {
  final int priority;

  /// phoneme | rule | completeness | insertion | fluency | prosody | praise.
  final String kind;
  final String? target;
  final String messageVi;
  final String messageEn;
  final List<String>? minimalPair;
  final List<String> practiceWords;
  final List<String> exerciseIds;

  const FeedbackItem({
    required this.priority,
    required this.kind,
    this.target,
    required this.messageVi,
    required this.messageEn,
    this.minimalPair,
    this.practiceWords = const [],
    this.exerciseIds = const [],
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> j) => FeedbackItem(
        priority: _i(j['priority']) ?? 99,
        kind: _s(j['kind']) ?? 'rule',
        target: _s(j['target']),
        messageVi: _s(j['messageVi']) ?? '',
        messageEn: _s(j['messageEn']) ?? '',
        minimalPair:
            j['minimalPair'] is List ? _strings(j['minimalPair']) : null,
        practiceWords: _strings(j['practiceWords']),
        exerciseIds: _strings(j['exerciseIds']),
      );

  Map<String, dynamic> toJson() => {
        'priority': priority,
        'kind': kind,
        'target': target,
        'messageVi': messageVi,
        'messageEn': messageEn,
        'minimalPair': minimalPair,
        'practiceWords': practiceWords,
        'exerciseIds': exerciseIds,
      };
}

/// Kết quả một lần chấm phát âm (`Attempt` của API).
class Assessment {
  final String id;
  final DateTime createdAt;
  final String referenceText;
  final String recognizedText;
  final String locale;
  final String? exerciseId;

  /// local | azure | mock | gemini | rule-based.
  final String provider;
  final int durationMs;
  final AssessmentScores scores;

  /// excellent | good | fair | needs_work.
  final String level;
  final List<WordResult> words;
  final List<FeedbackItem> feedback;
  final AssessmentSource source;

  const Assessment({
    required this.id,
    required this.createdAt,
    required this.referenceText,
    required this.recognizedText,
    this.locale = 'en-US',
    this.exerciseId,
    required this.provider,
    required this.durationMs,
    required this.scores,
    required this.level,
    required this.words,
    required this.feedback,
    this.source = AssessmentSource.api,
  });

  factory Assessment.fromJson(
    Map<String, dynamic> j, {
    AssessmentSource source = AssessmentSource.api,
  }) {
    final scores = AssessmentScores.fromJson(
      (j['scores'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    return Assessment(
      id: _s(j['id']) ?? '',
      createdAt: DateTime.tryParse(_s(j['createdAt']) ?? '') ?? DateTime.now(),
      referenceText: _s(j['referenceText']) ?? '',
      recognizedText: _s(j['recognizedText']) ?? '',
      locale: _s(j['locale']) ?? 'en-US',
      exerciseId: _s(j['exerciseId']),
      provider: _s(j['provider']) ?? 'unknown',
      durationMs: _i(j['durationMs']) ?? 0,
      scores: scores,
      level: _s(j['level']) ?? levelOf(scores.pronunciation),
      words: _maps(j['words']).map(WordResult.fromJson).toList(),
      feedback: _maps(j['feedback']).map(FeedbackItem.fromJson).toList()
        ..sort((a, b) => a.priority.compareTo(b.priority)),
      source: source,
    );
  }

  /// Chuyển kết quả dự phòng (Gemini / bộ luật, chấm trên transcript)
  /// sang cùng mô hình để UI và lịch sử dùng chung.
  factory Assessment.fromLegacy(
    PronunciationResult r, {
    required String referenceText,
    required String recognizedText,
    required AssessmentSource source,
    int durationMs = 0,
    String? exerciseId,
    DateTime? now,
  }) {
    final created = now ?? DateTime.now();
    final words = r.wordAnalysis.map((w) {
      final isError = w.status != 'correct';
      return WordResult(
        word: w.word,
        ipa: _stripSlashes(w.expectedIpa),
        accuracy: w.score.toDouble(),
        errorType: switch (w.errorType) {
          'none' => 'None',
          'omitted' => 'Omission',
          _ => 'Mispronunciation',
        },
        isError: isError,
        phonemes: w.phonemes
            .map((p) => PhonemeResult(
                  expected: p.symbol,
                  accuracy: switch (p.status) {
                    'correct' => 95,
                    'warning' => 65,
                    _ => 35,
                  },
                  isError: p.status != 'correct',
                  errorKind: switch (p.status) {
                    'correct' => null,
                    'warning' => 'distortion',
                    _ => 'substitution',
                  },
                ))
            .toList(),
      );
    }).toList();

    final feedback = <FeedbackItem>[
      for (final w
          in r.wordAnalysis.where((w) => w.status != 'correct').take(3))
        FeedbackItem(
          priority: 1,
          kind: 'phoneme',
          target: w.word,
          messageVi: '"${w.word}": ${w.specificError}',
          messageEn: '"${w.word}" needs attention.',
          practiceWords: [w.word.replaceAll(RegExp(r'[^A-Za-z\x27-]'), '')],
        ),
      if (r.tongueMouthAdvice.isNotEmpty)
        FeedbackItem(
          priority: 2,
          kind: 'rule',
          target: 'mouth',
          messageVi: r.tongueMouthAdvice,
          messageEn: 'Mouth and tongue placement advice.',
        ),
      for (final d in r.recommendedDrills)
        FeedbackItem(
            priority: 3,
            kind: 'rule',
            target: 'drill',
            messageVi: d,
            messageEn: d),
      FeedbackItem(
        priority: 4,
        kind: 'praise',
        target: levelOf(r.overallScore.toDouble()),
        messageVi: r.vietnameseSummary,
        messageEn: '',
      ),
    ];

    return Assessment(
      id: 'local_${created.microsecondsSinceEpoch}',
      createdAt: created,
      referenceText: referenceText,
      recognizedText: recognizedText,
      exerciseId: exerciseId,
      provider: source == AssessmentSource.gemini ? 'gemini' : 'rule-based',
      durationMs: durationMs,
      scores: AssessmentScores(
        pronunciation: r.overallScore.toDouble(),
        accuracy: r.accuracyScore.toDouble(),
        fluency: r.fluencyScore.toDouble(),
        completeness: r.completenessScore.toDouble(),
      ),
      level: levelOf(r.overallScore.toDouble()),
      words: words,
      feedback: feedback,
      source: source,
    );
  }

  /// Ngưỡng xếp loại giống server: ≥90 excellent, ≥75 good, ≥60 fair.
  static String levelOf(double score) {
    if (score >= 90) return 'excellent';
    if (score >= 75) return 'good';
    if (score >= 60) return 'fair';
    return 'needs_work';
  }

  int get overallScore => scores.pronunciation.round();

  /// Chấm trên audio thật (có phân tích âm vị đáng tin cậy) hay chỉ là dự phòng.
  bool get isAcousticAssessment => source == AssessmentSource.api;

  /// IPA chuẩn của cả câu ghép từ từng từ.
  String get expectedIpa {
    final parts =
        words.map((w) => w.ipa).whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? '' : '/${parts.join(' ')}/';
  }

  /// Lời nhận xét ưu tiên cao nhất để lưu tóm tắt vào lịch sử.
  String get summaryVi {
    final praise = feedback.where((f) => f.kind == 'praise');
    final top = feedback.where((f) => f.kind != 'praise');
    final parts = <String>[
      if (praise.isNotEmpty) praise.first.messageVi,
      if (top.isNotEmpty) top.first.messageVi,
    ];
    return parts.join(' ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'referenceText': referenceText,
        'recognizedText': recognizedText,
        'locale': locale,
        'exerciseId': exerciseId,
        'provider': provider,
        'durationMs': durationMs,
        'scores': scores.toJson(),
        'level': level,
        'words': words.map((w) => w.toJson()).toList(),
        'feedback': feedback.map((f) => f.toJson()).toList(),
      };

  static String _stripSlashes(String s) => s.replaceAll('/', '').trim();
}

/// Một dòng trong lịch sử (`GET /api/v1/me/assessments`).
class AssessmentSummary {
  final String id;
  final DateTime createdAt;
  final String referenceText;
  final String? exerciseId;
  final int durationMs;
  final AssessmentScores scores;
  final String level;

  const AssessmentSummary({
    required this.id,
    required this.createdAt,
    required this.referenceText,
    this.exerciseId,
    required this.durationMs,
    required this.scores,
    required this.level,
  });

  factory AssessmentSummary.fromJson(Map<String, dynamic> j) {
    final scores = AssessmentScores.fromJson(
      (j['scores'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    return AssessmentSummary(
      id: _s(j['id']) ?? '',
      createdAt: DateTime.tryParse(_s(j['createdAt']) ?? '') ?? DateTime.now(),
      referenceText: _s(j['referenceText']) ?? '',
      exerciseId: _s(j['exerciseId']),
      durationMs: _i(j['durationMs']) ?? 0,
      scores: scores,
      level: _s(j['level']) ?? Assessment.levelOf(scores.pronunciation),
    );
  }

  factory AssessmentSummary.of(Assessment a) => AssessmentSummary(
        id: a.id,
        createdAt: a.createdAt,
        referenceText: a.referenceText,
        exerciseId: a.exerciseId,
        durationMs: a.durationMs,
        scores: a.scores,
        level: a.level,
      );
}

class AssessmentPage {
  final List<AssessmentSummary> items;
  final String? nextCursor;

  const AssessmentPage({required this.items, this.nextCursor});

  factory AssessmentPage.fromJson(Map<String, dynamic> j) => AssessmentPage(
        items: _maps(j['items']).map(AssessmentSummary.fromJson).toList(),
        nextCursor: _s(j['nextCursor']),
      );
}

/// Âm vị yếu (`GET /api/v1/me/phoneme-stats`), sắp theo điểm tăng dần.
class PhonemeStat {
  final String phoneme;
  final int attempts;
  final int errorCount;
  final double avgAccuracy;
  final double lastAccuracy;
  final DateTime? updatedAt;

  const PhonemeStat({
    required this.phoneme,
    required this.attempts,
    required this.errorCount,
    required this.avgAccuracy,
    required this.lastAccuracy,
    this.updatedAt,
  });

  factory PhonemeStat.fromJson(Map<String, dynamic> j) => PhonemeStat(
        phoneme: _s(j['phoneme']) ?? '',
        attempts: _i(j['attempts']) ?? 0,
        errorCount: _i(j['errorCount']) ?? 0,
        avgAccuracy: _d(j['avgAccuracy']),
        lastAccuracy: _d(j['lastAccuracy']),
        updatedAt: DateTime.tryParse(_s(j['updatedAt']) ?? ''),
      );

  double get errorRate => attempts == 0 ? 0 : errorCount / attempts;
}

/// Mục trong danh mục âm vị (`GET /api/v1/phonemes`).
class PhonemeInfo {
  final String symbol;
  final String arpabet;
  final String type;
  final List<String> examples;
  final int vnDifficulty;
  final List<String> confusions;
  final List<List<String>> minimalPairs;
  final String tipVi;
  final String tipEn;
  final String vnNote;

  const PhonemeInfo({
    required this.symbol,
    required this.arpabet,
    required this.type,
    required this.examples,
    required this.vnDifficulty,
    required this.confusions,
    required this.minimalPairs,
    required this.tipVi,
    required this.tipEn,
    required this.vnNote,
  });

  factory PhonemeInfo.fromJson(Map<String, dynamic> j) => PhonemeInfo(
        symbol: _s(j['symbol']) ?? '',
        arpabet: _s(j['arpabet']) ?? '',
        type: _s(j['type']) ?? '',
        examples: _strings(j['examples']),
        vnDifficulty: _i(j['vnDifficulty']) ?? 1,
        confusions: _strings(j['confusions']),
        minimalPairs: j['minimalPairs'] is List
            ? (j['minimalPairs'] as List).map(_strings).toList()
            : const [],
        tipVi: _s(j['tipVi']) ?? '',
        tipEn: _s(j['tipEn']) ?? '',
        vnNote: _s(j['vnNote']) ?? '',
      );
}
