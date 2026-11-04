// Client cho Pronunciation API v1 (M4). Dựa trên client mẫu của repo
// LearnEnglish-vs-AI-pronun (examples/dart), bổ sung kiểu dữ liệu rõ ràng
// và cho phép thay http.Client / token để test.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/assessment.dart';

typedef IdTokenProvider = Future<String?> Function({bool forceRefresh});

class PronunciationApiException implements Exception {
  PronunciationApiException(
      this.statusCode, this.code, this.message, this.requestId);

  final int statusCode;

  /// Xử lý theo code, KHÔNG theo message.
  final String code;
  final String message;

  /// Gửi kèm khi báo lỗi cho người phụ trách backend.
  final String? requestId;

  bool get isRetryable =>
      statusCode == 429 || statusCode == 503 || statusCode == 0;

  /// Lỗi do người dùng (ghi âm) chứ không phải do hệ thống: không nên chuyển sang chấm dự phòng.
  bool get isUserError => const {
        'NO_SPEECH_DETECTED',
        'AUDIO_TOO_LONG',
        'AUDIO_TOO_LARGE',
        'AUDIO_UNSUPPORTED_FORMAT',
        'AUDIO_DECODE_FAILED',
        'TEXT_INVALID',
        'RATE_LIMITED',
      }.contains(code);

  String get userMessage => switch (code) {
        'NO_SPEECH_DETECTED' =>
          'Không nghe thấy giọng nói. Hãy nói to và rõ hơn nhé.',
        'AUDIO_TOO_LONG' => 'Bản ghi quá dài (tối đa 60 giây).',
        'AUDIO_TOO_LARGE' => 'File ghi âm quá lớn (tối đa 10 MB).',
        'AUDIO_UNSUPPORTED_FORMAT' ||
        'AUDIO_DECODE_FAILED' =>
          'Không đọc được file ghi âm, hãy thử ghi lại.',
        'TEXT_INVALID' => 'Câu mẫu không hợp lệ.',
        'RATE_LIMITED' => 'Bạn luyện nhanh quá! Nghỉ vài giây rồi thử lại.',
        'PROVIDER_UNAVAILABLE' =>
          'Hệ thống chấm điểm đang bận, thử lại sau ít phút.',
        'UNAUTHORIZED' => 'Phiên đăng nhập đã hết hạn, hãy đăng nhập lại.',
        'NETWORK' || 'TIMEOUT' => 'Không kết nối được máy chủ chấm điểm.',
        _ => 'Có lỗi xảy ra, vui lòng thử lại.',
      };

  @override
  String toString() =>
      'PronunciationApiException($statusCode $code: $message, requestId=$requestId)';
}

class PronunciationApi {
  PronunciationApi({
    required String baseUrl,
    required IdTokenProvider idToken,
    this.debugUid,
    http.Client? client,
    this.timeout = const Duration(seconds: 70),
    Duration Function(int attempt)? backoff,
  })  : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _idToken = idToken,
        _client = client ?? http.Client(),
        _backoff = backoff ?? ((attempt) => Duration(seconds: attempt * 2));

  final String baseUrl;

  /// Chỉ dùng với server chạy AUTH_MODE=dev (demo trên laptop, chế độ khách).
  final String? debugUid;
  final Duration timeout;
  final IdTokenProvider _idToken;
  final http.Client _client;
  final Duration Function(int attempt) _backoff;

  Future<Map<String, String>> _headers({bool forceRefresh = false}) async {
    final token = await _idToken(forceRefresh: forceRefresh);
    if (token != null) return {'Authorization': 'Bearer $token'};
    if (debugUid != null && debugUid!.isNotEmpty)
      return {'X-Debug-Uid': debugUid!};
    throw PronunciationApiException(
        401, 'UNAUTHORIZED', 'Chưa đăng nhập', null);
  }

  /// Chấm phát âm. Thử lại tối đa [maxAttempts] lần khi mạng lỗi / 503 / 429,
  /// luôn dùng cùng Idempotency-Key nên server không lưu trùng kết quả.
  Future<Assessment> assess(
    File audio,
    String referenceText, {
    String? exerciseId,
    String locale = 'en-US',
    int maxAttempts = 3,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? const Uuid().v4();
    final bytes = await audio.readAsBytes();
    final filename = audio.uri.pathSegments.isEmpty
        ? 'audio.wav'
        : audio.uri.pathSegments.last;
    var refreshed = false;
    for (var attempt = 1;; attempt++) {
      try {
        final req = http.MultipartRequest(
            'POST', Uri.parse('$baseUrl/api/v1/assessments'))
          ..headers.addAll(await _headers(forceRefresh: refreshed))
          ..headers['Idempotency-Key'] = key
          ..fields['reference_text'] = referenceText
          ..fields['locale'] = locale
          ..files.add(
              http.MultipartFile.fromBytes('audio', bytes, filename: filename));
        if (exerciseId != null && exerciseId.isNotEmpty)
          req.fields['exercise_id'] = exerciseId;

        final res = await http.Response.fromStream(
            await _client.send(req).timeout(timeout));
        if (res.statusCode == 200 || res.statusCode == 201) {
          return Assessment.fromJson(_decode(res));
        }
        final err = _parseError(res);
        if (err.statusCode == 401 && !refreshed) {
          refreshed = true; // token hết hạn → làm mới đúng 1 lần
          continue;
        }
        if (err.isRetryable && attempt < maxAttempts) {
          await Future.delayed(_retryDelay(res, attempt));
          continue;
        }
        throw err;
      } on SocketException catch (e) {
        if (attempt >= maxAttempts) {
          throw PronunciationApiException(0, 'NETWORK', e.message, null);
        }
        await Future.delayed(_backoff(attempt));
      } on http.ClientException catch (e) {
        if (attempt >= maxAttempts) {
          throw PronunciationApiException(0, 'NETWORK', e.message, null);
        }
        await Future.delayed(_backoff(attempt));
      } on TimeoutException {
        if (attempt >= maxAttempts) {
          throw PronunciationApiException(
              0, 'TIMEOUT', 'Hết thời gian chờ', null);
        }
      }
    }
  }

  Future<Assessment> getAssessment(String id) async => Assessment.fromJson(
      await _get('/api/v1/assessments/${Uri.encodeComponent(id)}'));

  Future<AssessmentPage> history({int limit = 20, String? cursor}) async {
    final q =
        'limit=$limit${cursor != null ? '&cursor=${Uri.encodeQueryComponent(cursor)}' : ''}';
    return AssessmentPage.fromJson(await _get('/api/v1/me/assessments?$q'));
  }

  Future<List<PhonemeStat>> weakPhonemes({int limit = 5}) async {
    final j = await _get('/api/v1/me/phoneme-stats?limit=$limit');
    return ((j['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => PhonemeStat.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<List<PhonemeInfo>> phonemeCatalog() async {
    final j = await _get('/api/v1/phonemes');
    return ((j['phonemes'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => PhonemeInfo.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  /// `true` nếu server đang chạy và sẵn sàng chấm.
  Future<bool> isReady() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/ready'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      var res = await _client
          .get(Uri.parse('$baseUrl$path'), headers: await _headers())
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 401) {
        res = await _client
            .get(Uri.parse('$baseUrl$path'),
                headers: await _headers(forceRefresh: true))
            .timeout(const Duration(seconds: 20));
      }
      if (res.statusCode != 200) throw _parseError(res);
      return _decode(res);
    } on SocketException catch (e) {
      throw PronunciationApiException(0, 'NETWORK', e.message, null);
    } on http.ClientException catch (e) {
      throw PronunciationApiException(0, 'NETWORK', e.message, null);
    } on TimeoutException {
      throw PronunciationApiException(0, 'TIMEOUT', 'Hết thời gian chờ', null);
    }
  }

  Map<String, dynamic> _decode(http.Response res) =>
      (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, dynamic>();

  PronunciationApiException _parseError(http.Response res) {
    try {
      final e = (_decode(res)['error'] as Map).cast<String, dynamic>();
      return PronunciationApiException(
        res.statusCode,
        e['code'] as String,
        (e['message'] as String?) ?? '',
        e['requestId'] as String? ?? res.headers['x-request-id'],
      );
    } catch (_) {
      return PronunciationApiException(
        res.statusCode,
        'HTTP_${res.statusCode}',
        res.reasonPhrase ?? '',
        res.headers['x-request-id'],
      );
    }
  }

  Duration _retryDelay(http.Response res, int attempt) {
    final ra = int.tryParse(res.headers['retry-after'] ?? '');
    return ra != null ? Duration(seconds: ra) : _backoff(attempt);
  }

  void close() => _client.close();
}
