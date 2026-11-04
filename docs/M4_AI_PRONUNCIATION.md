# M4 – AI Pronunciation (app Flutter)

App Flutter chấm phát âm bằng **Pronunciation API** của repo
[LearnEnglish-vs-AI-pronun](https://github.com/tugduong57/LearnEnglish-vs-AI-pronun):
một server FastAPI chấm trên **audio thật**, dùng mô hình wav2vec2 chạy cục bộ (hoặc Azure nếu có khóa).
Gemini và bộ luật cục bộ chỉ còn là **dự phòng** khi không kết nối được API.

| Hạng mục | Làm ở đâu |
|---|---|
| Pronunciation Scoring | `POST /api/v1/assessments`: điểm phát âm, độ chính xác, trôi chảy, đầy đủ, ngữ điệu (Azure), kèm xếp loại `excellent/good/fair/needs_work` |
| Phoneme Analysis | Từng từ → từng âm vị IPA: âm chuẩn → âm đã đọc, `errorKind` (thay/bỏ/thừa/chưa chuẩn), vị trí trong từ, 22 mẫu lỗi đặc trưng của người Việt |
| Improvement Feedback | `feedback[]` song ngữ theo mức ưu tiên, cặp từ đối lập, từ luyện tập (bấm để nghe bằng TTS), mẹo khẩu hình lấy từ danh mục `GET /api/v1/phonemes` |
| Result History | `GET /api/v1/me/assessments` (phân trang), `GET /api/v1/assessments/{id}` (xem lại chi tiết), `GET /api/v1/me/phoneme-stats` (âm hay sai) |

## Luồng hoạt động

```
Thu âm (record, WAV 16 kHz mono, ≤ 60 s)
  → PronunciationEngine.assessAudio
  → PronunciationApi.assess  (Bearer Firebase ID token, Idempotency-Key, tự thử lại khi 429/503/mất mạng)
  → server chấm, lưu users/{uid}/pronunciation_attempts + phoneme_stats (Admin SDK)
  → AssessmentResultView hiển thị điểm, từ, âm vị, gợi ý
  → MainShell ghi practice_records (kèm assessmentId) + daily_stats (cho M2: streak, mục tiêu, thống kê)
```

Khi không có API (chưa cấu hình, server tắt, hoặc người dùng chọn "Dùng dự phòng"):
`speech_to_text` → Gemini (có JSON schema trong prompt) → bộ luật so khớp chữ.
Kết quả được chuyển sang cùng mô hình `Assessment`, nhưng **được đánh dấu là dự phòng** trên UI.
Ở chế độ này, phần phân tích âm vị chỉ là ước lượng, và lịch sử chỉ lưu trong phiên.

## Chạy

1. Chạy server (xem README của repo API):

   ```bash
   uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```

2. Chạy app và trỏ tới server:

   ```bash
   flutter run --dart-define=PRONUN_API_BASE=http://10.0.2.2:8000
   ```

   - Android emulator dùng `10.0.2.2`; máy thật dùng IP LAN của laptop.
   - Khi server chạy `AUTH_MODE=dev` (demo, chế độ khách không có Firebase user), thêm
     `--dart-define=PRONUN_DEBUG_UID=demo`. Ở prod, app luôn gửi Firebase ID token.
   - Có thể thêm `--dart-define=GEMINI_API_KEY=...` để dùng chấm dự phòng bằng Gemini.

### Cấu hình nền tảng (khi tạo thư mục `android/` và `ios/`)

- Android `AndroidManifest.xml`: `RECORD_AUDIO`, `INTERNET`; với server `http://` trong mạng LAN
  thì thêm `android:usesCleartextTraffic="true"` (chỉ dùng cho bản debug).
- iOS `Info.plist`: `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`; với
  `http://` thì thêm ngoại lệ ATS cho bản debug.

## Firestore

Server ghi bằng Admin SDK. Client **chỉ được đọc** dữ liệu của chính mình (`firestore.rules`):

```
users/{uid}/pronunciation_attempts/{attemptId}   read: owner · write: false
users/{uid}/phoneme_stats/{ARPABET}              read: owner · write: false
users/{uid}/pronunciation_idempotency/{key}      không cho client truy cập
```

`practice_records` có thêm `assessmentId` (để mở lại chi tiết) và `scoringSource` (`api | gemini | ruleBased`).

## Mã nguồn

| File | Vai trò |
|---|---|
| `lib/models/assessment.dart` | Mô hình hợp đồng API v1 (bỏ qua field lạ, chấp nhận enum mới), bộ chuyển đổi kết quả dự phòng |
| `lib/services/pronunciation_api.dart` | Client HTTP: token và làm mới token, idempotency, thử lại, mã lỗi → thông báo tiếng Việt |
| `lib/services/pronunciation_engine.dart` | Chọn chế độ chấm, cache kết quả, lịch sử/âm yếu (từ server hoặc trong phiên) |
| `lib/services/audio_recorder_service.dart` | Quyền micro, thu WAV 16 kHz, phát lại bản ghi |
| `lib/services/pronunciation_labels.dart` | Nhãn tiếng Việt và màu cho level, errorKind, pattern, feedback |
| `lib/widgets/assessment_result_view.dart` | UI kết quả dùng chung |
| `lib/screens/assessment_history_screen.dart` | Lịch sử, âm hay sai, chi tiết một lần chấm |

## Kiểm thử

```bash
flutter test
```

- `test/assessment_model_test.dart`: parse response mẫu của API, enum lạ, chuyển đổi kết quả dự phòng, thống kê âm yếu.
- `test/pronunciation_api_test.dart`: multipart, Idempotency-Key giữ nguyên khi thử lại, làm mới token khi 401, mã lỗi, phân trang.
