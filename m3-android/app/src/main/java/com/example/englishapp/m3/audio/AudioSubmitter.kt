package com.example.englishapp.m3.audio

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File

/**
 * Điểm bàn giao cho M4 (AI chấm phát âm) và backend.
 * Mọi nơi khác chỉ phụ thuộc interface này nên dễ thay thế.
 */
interface AudioSubmitter {
    suspend fun submit(file: File, exerciseId: Int, durationMs: Long): Result<String>
}

/** Chế độ mock: dùng khi backend chưa sẵn sàng. */
class MockAudioSubmitter : AudioSubmitter {
    override suspend fun submit(file: File, exerciseId: Int, durationMs: Long): Result<String> {
        delay(600)
        return Result.success("mock: đã nhận ${file.length() / 1024}KB cho bài $exerciseId")
    }
}

/** Upload multipart lên server: POST {uploadUrl} với field audio, exerciseId, duration. */
class HttpAudioSubmitter(
    private val uploadUrl: String,                // vd: "https://api.example.com/api/recordings"
    private val client: OkHttpClient = OkHttpClient()
) : AudioSubmitter {
    override suspend fun submit(file: File, exerciseId: Int, durationMs: Long): Result<String> =
        withContext(Dispatchers.IO) {
            runCatching {
                val body = MultipartBody.Builder().setType(MultipartBody.FORM)
                    .addFormDataPart("exerciseId", exerciseId.toString())
                    .addFormDataPart("duration", durationMs.toString())
                    .addFormDataPart("audio", file.name, file.asRequestBody("audio/mp4".toMediaType()))
                    .build()
                client.newCall(Request.Builder().url(uploadUrl).post(body).build()).execute().use { res ->
                    if (!res.isSuccessful) error("HTTP ${res.code}")
                    res.body?.string().orEmpty()
                }
            }
        }
}
