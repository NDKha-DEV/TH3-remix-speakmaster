# M3 – Audio & Exercise (Android, Kotlin + Jetpack Compose)

## Cấu trúc
```
app/src/main/
├─ AndroidManifest.xml                  (quyền RECORD_AUDIO, INTERNET)
└─ java/com/example/englishapp/
   ├─ MainActivity.kt                   (activity mẫu chạy thử M3)
   └─ m3/
      ├─ Exercise.kt                    data class + dữ liệu mẫu
      ├─ M3ViewModel.kt                 state + logic
      ├─ M3Screen.kt                    UI: List / Detail / Permission / Record / Upload
      └─ audio/
         ├─ AudioRecorder.kt            ghi âm (MediaRecorder -> .m4a)
         ├─ AudioPlayer.kt              phát lại + phát âm mẫu (MediaPlayer / TextToSpeech)
         ├─ AudioImporter.kt            chọn & kiểm tra file âm thanh
         └─ AudioSubmitter.kt           mock + upload HTTP (điểm bàn giao cho M4)
```

## Đối chiếu checklist
| Checklist                | File chính                                  |
|--------------------------|---------------------------------------------|
| Exercise List / Detail   | `M3Screen.kt` (ExerciseList, ExerciseDetail), `Exercise.kt` |
| IPA + Reference Audio    | `M3Screen.kt`, `AudioPlayer.playReference`  |
| Microphone Permission    | `M3Screen.kt` (launcher RECORD_AUDIO, xử lý "không hỏi lại" -> mở Cài đặt) |
| Recording / Playback     | `AudioRecorder.kt`, `AudioPlayer.kt`, `M3ViewModel.kt` |
| Audio Upload             | `AudioImporter.kt` (GetContent, kiểm tra loại/size/độ dài) |

## Cách chạy
1. Android Studio -> New Project -> Empty Activity (Compose), package `com.example.englishapp`.
2. Chép thư mục `app/src/main/...` đè vào project (hoặc chỉ chép thư mục `m3/` + thêm quyền vào Manifest).
3. Thêm dependency như trong `app/build.gradle.kts` (OkHttp là phần thêm).
4. Chạy trên **máy thật** hoặc emulator đã bật micro (Extended controls -> Microphone).

## Ghép với module khác
- **M1 (database):** thay `ExerciseRepository.sample` bằng dữ liệu từ DB/API.
- **M4 (AI chấm điểm):** `M3Screen(onAudioSubmitted = { file, exerciseId -> ... })` trả về file `.m4a` vừa ghi.
  Nếu backend nhận upload: `vm.submitter = HttpAudioSubmitter("https://.../api/recordings")`
  (multipart: `audio`, `exerciseId`, `duration`).
- **Âm thanh mẫu chuẩn:** điền `refAudioUrl` trong `Exercise` (URL hoặc đường dẫn file); để null thì dùng TextToSpeech en-US.

## Lưu ý
- Một số máy Xiaomi/Oppo hỏi quyền micro khác thường; đã xử lý trường hợp bị chặn bằng nút mở Cài đặt.
- File ghi âm lưu ở cache, tự xoá khi ghi lại / thoát bài.
