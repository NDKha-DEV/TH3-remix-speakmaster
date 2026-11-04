package com.example.englishapp.m3

/** Một bài tập phát âm. Sau này thay dữ liệu mẫu bằng dữ liệu từ DB/API của M1. */
data class Exercise(
    val id: Int,
    val level: String,
    val text: String,
    val ipa: String,
    val hint: String,
    /** URL hoặc đường dẫn file âm thanh chuẩn. null => dùng TextToSpeech của máy. */
    val refAudioUrl: String? = null
)

object ExerciseRepository {
    val sample = listOf(
        Exercise(1, "A1", "Hello", "/həˈloʊ/", "Nhấn âm 2: he-LLO"),
        Exercise(2, "A1", "Thank you", "/θæŋk juː/", "Âm /θ/: đặt lưỡi giữa hai hàm răng"),
        Exercise(3, "A2", "Beautiful", "/ˈbjuːtɪfl/", "Nhấn âm 1: BEAU-ti-ful"),
        Exercise(4, "A2", "Three birds", "/θriː bɜːrdz/", "Phân biệt /θ/ và /s/, âm /ɜːr/"),
        Exercise(
            5, "B1", "I would like a cup of coffee.",
            "/aɪ wʊd laɪk ə kʌp əv ˈkɔːfi/", "\"would\" đọc nhẹ, nối âm \"cup of\""
        )
    )
}
