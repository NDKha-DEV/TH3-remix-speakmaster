package com.example.englishapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import com.example.englishapp.m3.M3Screen

/** Activity mẫu để chạy thử riêng M3. Khi ghép app thật, chỉ cần gọi M3Screen() trong navigation. */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                M3Screen(onAudioSubmitted = { file, exerciseId ->
                    // TODO (M4): gửi file này cho module AI chấm phát âm
                })
            }
        }
    }
}
