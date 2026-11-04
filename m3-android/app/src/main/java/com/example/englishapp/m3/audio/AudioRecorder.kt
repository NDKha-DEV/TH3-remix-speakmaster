package com.example.englishapp.m3.audio

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import java.io.File

/**
 * Ghi âm bằng MediaRecorder -> file .m4a (AAC). Định dạng này phát được trên mọi Android
 * và hầu hết các dịch vụ speech/AI đều đọc được.
 * Cần quyền RECORD_AUDIO đã được cấp trước khi gọi start().
 */
class AudioRecorder(private val context: Context) {

    private var recorder: MediaRecorder? = null
    var outputFile: File? = null
        private set
    private var startTime = 0L

    val isRecording: Boolean get() = recorder != null

    fun start(): File {
        stopQuietly()
        val file = File(context.cacheDir, "rec_${System.currentTimeMillis()}.m4a")
        val r = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) MediaRecorder(context)
        else @Suppress("DEPRECATION") MediaRecorder()
        r.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioSamplingRate(44100)
            setAudioEncodingBitRate(128_000)
            setOutputFile(file.absolutePath)
            prepare()
            start()
        }
        recorder = r
        outputFile = file
        startTime = System.currentTimeMillis()
        return file
    }

    /** Dừng ghi. Trả về (file, thời lượng ms) hoặc null nếu ghi quá ngắn / lỗi. */
    fun stop(): Pair<File, Long>? {
        val r = recorder ?: return null
        val file = outputFile
        val duration = System.currentTimeMillis() - startTime
        recorder = null
        return try {
            r.stop(); r.release()
            if (file != null && duration >= 500) file to duration else { file?.delete(); null }
        } catch (e: RuntimeException) {   // stop() ném lỗi nếu ghi quá ngắn
            r.release(); file?.delete(); null
        }
    }

    /** Mức âm lượng 0f..1f để vẽ thanh meter. */
    fun level(): Float = try {
        ((recorder?.maxAmplitude ?: 0) / 32767f).coerceIn(0f, 1f)
    } catch (e: Exception) { 0f }

    fun release() = stopQuietly()

    private fun stopQuietly() {
        try { recorder?.stop() } catch (_: Exception) {}
        try { recorder?.release() } catch (_: Exception) {}
        recorder = null
    }
}
