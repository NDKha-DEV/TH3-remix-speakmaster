// Điều phối M4: chọn bộ chấm, lưu tạm kết quả, cung cấp lịch sử và âm yếu.
//
// - Chế độ "audio" (khuyên dùng): có Pronunciation API → thu âm WAV 16 kHz,
//   chấm trên âm thanh thật, phân tích tới từng âm vị IPA, lưu lịch sử phía server.
// - Chế độ "transcript" (dự phòng): không cấu hình hoặc không kết nối được API →
//   dùng speech_to_text + Gemini (hoặc bộ luật cục bộ), lịch sử chỉ giữ trong phiên.

import 'dart:io';

import '../models/assessment.dart';
import '../models/models.dart';
import 'ai_pronunciation_service.dart';
import 'pronunciation_api.dart';

enum ScoringMode { audio, transcript }

class PronunciationEngine {
  PronunciationEngine({this.api, required this.fallback});

  final PronunciationApi? api;
  final AIPronunciationService fallback;

  final List<Assessment> _session = [];
  final Map<String, Assessment> _cache = {};
  bool? _apiReady;

  /// Đã cấu hình PRONUN_API_BASE hay chưa.
  bool get hasApi => api != null;

  /// Chế độ chấm hiện tại; gọi [refreshAvailability] để kiểm tra lại server.
  ScoringMode get mode => hasApi && (_apiReady ?? true)
      ? ScoringMode.audio
      : ScoringMode.transcript;

  /// Lịch sử có lưu bền vững trên server hay chỉ trong phiên.
  bool get hasRemoteHistory => mode == ScoringMode.audio;

  Future<ScoringMode> refreshAvailability() async {
    if (api == null) return ScoringMode.transcript;
    _apiReady = await api!.isReady();
    return mode;
  }

  /// Chấm bằng Pronunciation API trên file audio đã ghi.
  Future<Assessment> assessAudio({
    required File audio,
    required LessonSentence sentence,
  }) async {
    final a = await api!.assess(audio, sentence.text, exerciseId: sentence.id);
    _remember(a);
    return a;
  }

  /// Chấm dự phòng dựa trên transcript (speech_to_text).
  Future<Assessment> assessTranscript({
    required String transcript,
    required LessonSentence sentence,
    int durationMs = 0,
  }) async {
    final (result, usedGemini) = await fallback.analyzeWithSource(
      targetText: sentence.text,
      userSpokenText: transcript,
      category: sentence.category,
      difficulty: sentence.difficulty,
    );
    final a = Assessment.fromLegacy(
      result,
      referenceText: sentence.text,
      recognizedText: transcript,
      source: usedGemini ? AssessmentSource.gemini : AssessmentSource.ruleBased,
      durationMs: durationMs,
      exerciseId: sentence.id,
    );
    _remember(a);
    return a;
  }

  void _remember(Assessment a) {
    _cache[a.id] = a;
    _session.removeWhere((x) => x.id == a.id);
    _session.insert(0, a);
  }

  /// Kết quả chấm trong phiên hiện tại (mới nhất trước).
  List<Assessment> get sessionResults => List.unmodifiable(_session);

  Future<Assessment?> getAssessment(String id) async {
    final cached = _cache[id];
    if (cached != null) return cached;
    if (api == null || id.startsWith('local_')) return null;
    final a = await api!.getAssessment(id);
    _cache[a.id] = a;
    return a;
  }

  Future<AssessmentPage> history({int limit = 20, String? cursor}) async {
    if (hasRemoteHistory) return api!.history(limit: limit, cursor: cursor);
    return AssessmentPage(items: _session.map(AssessmentSummary.of).toList());
  }

  Future<List<PhonemeStat>> weakPhonemes({int limit = 5}) async {
    if (hasRemoteHistory) return api!.weakPhonemes(limit: limit);
    return computePhonemeStats(_session, limit: limit);
  }

  List<PhonemeInfo>? _catalog;

  Future<Map<String, PhonemeInfo>> phonemeCatalog() async {
    if (api == null) return const {};
    try {
      _catalog ??= await api!.phonemeCatalog();
    } on PronunciationApiException {
      return const {};
    }
    return {for (final p in _catalog!) p.symbol: p};
  }

  /// Gộp thống kê âm vị từ các lần chấm trên audio (bản dự phòng chỉ có chữ cái nên bỏ qua).
  static List<PhonemeStat> computePhonemeStats(Iterable<Assessment> results,
      {int limit = 5}) {
    final acc = <String, List<double>>{};
    final errors = <String, int>{};
    final last = <String, double>{};
    final updated = <String, DateTime>{};
    final ordered = results.where((a) => a.isAcousticAssessment).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final a in ordered) {
      for (final w in a.words) {
        for (final p in w.phonemes) {
          if (p.expected.isEmpty) continue;
          acc.putIfAbsent(p.expected, () => []).add(p.accuracy);
          if (p.isError) errors[p.expected] = (errors[p.expected] ?? 0) + 1;
          last[p.expected] = p.accuracy;
          updated[p.expected] = a.createdAt;
        }
      }
    }
    final stats = acc.entries
        .map((e) => PhonemeStat(
              phoneme: e.key,
              attempts: e.value.length,
              errorCount: errors[e.key] ?? 0,
              avgAccuracy: e.value.reduce((x, y) => x + y) / e.value.length,
              lastAccuracy: last[e.key]!,
              updatedAt: updated[e.key],
            ))
        .where((s) => s.errorCount > 0)
        .toList()
      ..sort((a, b) => a.avgAccuracy.compareTo(b.avgAccuracy));
    return stats.take(limit).toList();
  }
}
