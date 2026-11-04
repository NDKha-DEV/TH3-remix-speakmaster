import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/models.dart';

class AIPronunciationService {
  final String apiKey;
  late final GenerativeModel _model;

  AIPronunciationService({required this.apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.2,
      ),
    );
  }

  Future<PronunciationResult> analyzePronunciation({
    required String targetText,
    required String userSpokenText,
    String category = 'General',
    String difficulty = 'Intermediate',
  }) async {
    if (apiKey.isEmpty) {
      return fallbackPhoneticAnalysis(targetText, userSpokenText);
    }

    try {
      final prompt = '''
Bạn là chuyên gia ngữ âm tiếng Anh (Phonetician & Speech Coach) chuyên hướng dẫn sinh viên Việt Nam phát âm chuẩn bản xứ.
Hãy phân tích phát âm của người dùng so với câu mẫu:
- Câu mục tiêu: "$targetText"
- Văn bản nhận diện giọng nói: "$userSpokenText"
- Chủ đề: "$category" ($difficulty)

Yêu cầu phân tích:
1. Chấm điểm (0-100): overallScore, accuracyScore (độ chuẩn âm vị IPA), fluencyScore (độ trôi chảy), completenessScore (độ đầy đủ từ).
2. Phân tích từng từ (wordAnalysis): chỉ rõ từ nào phát âm đúng ('correct'), cảnh báo thiếu âm đuôi/trọng âm ('warning'), hoặc phát âm sai nguyên âm/phụ âm ('incorrect').
3. Đưa ra nhận xét tổng quan bằng tiếng Việt (vietnameseSummary) và hướng dẫn chi tiết khẩu hình miệng, vị trí đặt đầu lưỡi (tongueMouthAdvice).
4. Đề xuất 3 bài tập luyện âm cụ thể (recommendedDrills).

Trả về đúng định dạng JSON khớp schema của ứng dụng.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      if (response.text != null) {
        final Map<String, dynamic> jsonMap = jsonDecode(response.text!);
        return PronunciationResult.fromJson(jsonMap);
      }
      return fallbackPhoneticAnalysis(targetText, userSpokenText);
    } catch (e) {
      return fallbackPhoneticAnalysis(targetText, userSpokenText);
    }
  }

  // Thuật toán so sánh âm vị dự phòng (Phoneme Comparison Fallback)
  PronunciationResult fallbackPhoneticAnalysis(String targetText, String spokenText) {
    final targetWords = targetText.trim().split(RegExp(r'\s+'));
    final spokenWords = spokenText.trim().isEmpty ? <String>[] : spokenText.trim().split(RegExp(r'\s+'));

    int totalScore = 0;
    final List<WordAnalysis> wordAnalysisList = [];

    for (int i = 0; i < targetWords.length; i++) {
      final tWord = targetWords[i];
      final cleanT = tWord.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
      final cleanS = i < spokenWords.length
          ? spokenWords[i].replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase()
          : '';

      int score = 95;
      String status = 'correct';
      String errorType = 'none';
      String specificError = 'Phát âm chuẩn xác';

      if (cleanS.isEmpty) {
        score = 25;
        status = 'incorrect';
        errorType = 'omitted';
        specificError = 'Chưa nghe rõ từ này, hãy phát âm to hơn';
      } else if (cleanT != cleanS) {
        if (cleanT.length > 3 && cleanT.substring(0, cleanT.length - 1) == cleanS) {
          score = 68;
          status = 'warning';
          errorType = 'missing_ending_sound';
          specificError = 'Thiếu âm đuôi /${cleanT.substring(cleanT.length - 1)}/';
        } else {
          score = 48;
          status = 'incorrect';
          errorType = 'sound_distortion';
          specificError = 'Phát âm thành "$cleanS", cần chỉnh lại khẩu hình nguyên âm/phụ âm';
        }
      }

      totalScore += score;
      wordAnalysisList.add(
        WordAnalysis(
          word: tWord,
          expectedIpa: '/$cleanT/',
          detectedIpa: status == 'correct' ? '/$cleanT/' : '/${cleanS.isEmpty ? '...' : cleanS}/',
          score: score,
          status: status,
          errorType: errorType,
          phonemes: cleanT
              .split('')
              .map((ch) => PhonemeBreakdown(symbol: ch, status: status))
              .toList(),
          specificError: specificError,
        ),
      );
    }

    final overall = (totalScore / (targetWords.isEmpty ? 1 : targetWords.length)).round().clamp(20, 100);
    final completeness = ((spokenWords.length / (targetWords.isEmpty ? 1 : targetWords.length)) * 100)
        .round()
        .clamp(30, 100);

    return PronunciationResult(
      overallScore: overall,
      accuracyScore: (overall - 2).clamp(15, 100),
      fluencyScore: (overall + 3).clamp(25, 100),
      completenessScore: completeness,
      expectedIpa: wordAnalysisList.map((w) => w.expectedIpa).join(' '),
      vietnameseSummary: overall >= 85
          ? 'Tuyệt vời! Phát âm của bạn rất tự nhiên, âm vị rõ ràng và ngữ điệu chuẩn.'
          : overall >= 70
              ? 'Khá tốt! Bạn phát âm đúng phần lớn các từ, cần chú ý bật rõ âm đuôi (ending sounds).'
              : 'Cần luyện tập thêm! Một số từ bị nuốt âm đuôi hoặc sai khẩu hình.',
      tongueMouthAdvice:
          'Mở rộng khẩu hình khi phát âm nguyên âm dài, đặt đầu lưỡi chạm nhẹ giữa hai răng đối với âm /θ/ và /ð/.',
      wordAnalysis: wordAnalysisList,
      recommendedDrills: [
        'Đọc chậm từng âm tiết và giữ hơi ở phụ âm cuối',
        'Nghe mẫu US/UK và nhại lại theo phương pháp Shadowing',
        'Tập trung sửa các từ được đánh dấu màu đỏ và vàng',
      ],
    );
  }
}
