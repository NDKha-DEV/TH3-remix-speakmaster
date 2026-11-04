// Nhãn tiếng Việt và màu cho kết quả chấm. Giá trị enum lạ (server có thể
// thêm sau) luôn có nhãn mặc định, không làm hỏng UI.

import 'package:flutter/material.dart';

import '../models/assessment.dart';

class PronunciationLabels {
  static String level(String level) => switch (level) {
        'excellent' => 'Xuất sắc',
        'good' => 'Tốt',
        'fair' => 'Khá',
        'needs_work' => 'Cần luyện thêm',
        _ => level,
      };

  static Color levelColor(String level) => switch (level) {
        'excellent' => Colors.teal,
        'good' => Colors.green,
        'fair' => Colors.amber.shade800,
        _ => Colors.redAccent,
      };

  static Color scoreColor(double score) =>
      levelColor(Assessment.levelOf(score));

  static String errorKind(String? kind) => switch (kind) {
        null => 'Chuẩn',
        'substitution' => 'Đọc thành âm khác',
        'deletion' => 'Bỏ âm',
        'insertion' => 'Thừa âm',
        'distortion' => 'Chưa chuẩn',
        _ => 'Lỗi phát âm',
      };

  /// Màu một âm vị: xanh = đúng, cam = chưa chuẩn, đỏ = sai/bỏ.
  static Color phonemeColor(PhonemeResult p) {
    if (!p.isError) return Colors.teal;
    if (p.errorKind == 'distortion') return Colors.orange.shade700;
    return Colors.redAccent;
  }

  static Color wordColor(WordResult w) {
    if (!w.isError) return Colors.teal;
    if (w.errorType == 'Omission' || w.accuracy < 45) return Colors.redAccent;
    return Colors.amber.shade800;
  }

  static String wordErrorType(String type) => switch (type) {
        'None' => 'Đúng',
        'Mispronunciation' => 'Phát âm sai',
        'Omission' => 'Bỏ sót từ',
        'Insertion' => 'Thừa từ',
        'UnexpectedBreak' => 'Ngắt nghỉ sai chỗ',
        'MissingBreak' => 'Thiếu ngắt nghỉ',
        'Monotone' => 'Giọng đều đều',
        _ => type,
      };

  static String position(String? p) => switch (p) {
        'initial' => 'đầu từ',
        'medial' => 'giữa từ',
        'final' => 'cuối từ',
        _ => '',
      };

  /// 22 mẫu lỗi đặc trưng của người Việt (Pronunciation API `pattern`).
  static String? pattern(String? p) => switch (p) {
        null => null,
        'th_substitution' => '/θ/ đọc thành /t/ hoặc /s/',
        'dh_substitution' => '/ð/ đọc thành /d/ hoặc /z/',
        'sh_s_merge' => 'Nhầm /ʃ/ với /s/',
        'zh_substitution' => '/ʒ/ đọc thành /z/ hoặc /ʃ/',
        'j_substitution' => '/dʒ/ đọc như "gi"/"ch" tiếng Việt',
        'ch_substitution' => '/tʃ/ đọc như "ch" tiếng Việt',
        'v_substitution' => '/v/ đọc thành /b/ hoặc /f/',
        'p_voicing' => '/p/ đọc thành /b/',
        'r_substitution' => '/r/ đọc như "r"/"z" tiếng Việt',
        'l_n_confusion' => 'Nhầm /l/ và /n/',
        'l_vocalization' => '/l/ cuối từ bị nuốt',
        'ng_n_confusion' => 'Nhầm /ŋ/ và /n/',
        'vowel_length' => 'Sai độ dài nguyên âm (dài/ngắn)',
        'diphthong_simplification' => 'Nguyên âm đôi bị đọc thành đơn',
        'ae_e_merge' => 'Nhầm /æ/ với /e/',
        'r_colored_vowel' => 'Thiếu âm /r/ trong nguyên âm',
        'final_consonant_drop' => 'Nuốt phụ âm cuối',
        'final_devoicing' => 'Phụ âm cuối hữu thanh bị đọc vô thanh',
        'ending_s_drop' => 'Thiếu âm đuôi -s/-es',
        'ending_ed_drop' => 'Thiếu âm đuôi -ed',
        'cluster_reduction' => 'Rút gọn cụm phụ âm',
        'epenthesis' => 'Chèn thêm nguyên âm vào cụm phụ âm',
        _ => 'Lỗi đặc trưng người Việt',
      };

  static IconData feedbackIcon(String kind) => switch (kind) {
        'phoneme' => Icons.record_voice_over,
        'rule' => Icons.rule,
        'completeness' => Icons.playlist_add_check,
        'insertion' => Icons.add_comment_outlined,
        'fluency' => Icons.speed,
        'prosody' => Icons.graphic_eq,
        'praise' => Icons.emoji_events_outlined,
        _ => Icons.lightbulb_outline,
      };

  static String source(AssessmentSource s, String provider) => switch (s) {
        AssessmentSource.api => 'Chấm trên audio · $provider',
        AssessmentSource.gemini => 'Dự phòng: Gemini (dựa trên transcript)',
        AssessmentSource.ruleBased => 'Dự phòng: so khớp chữ cục bộ',
      };
}
