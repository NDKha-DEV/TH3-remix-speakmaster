package com.example.englishapp.m3.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.speech.tts.TextToSpeech
import java.io.File
import java.util.Locale

/**
 * Phát lại bản ghi của người dùng và phát âm mẫu.
 * - Có file/URL mẫu: dùng MediaPlayer.
 * - Không có: dùng TextToSpeech (en-US) của hệ thống.
 */
class AudioPlayer(context: Context) {

    private var player: MediaPlayer? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    init {
        tts = TextToSpeech(context.applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                ttsReady = tts?.setLanguage(Locale.US).let {
                    it != TextToSpeech.LANG_MISSING_DATA && it != TextToSpeech.LANG_NOT_SUPPORTED
                }
            }
        }
    }

    /** Phát file bản ghi (local). onDone gọi khi phát xong hoặc lỗi. */
    fun playFile(file: File, onDone: () -> Unit = {}) = playSource(file.absolutePath, 1f, onDone)

    /** Phát file/URL chuẩn nếu có, ngược lại đọc bằng TTS. */
    fun playReference(text: String, refUrl: String?, speed: Float = 1f, onDone: () -> Unit = {}) {
        stop()
        if (refUrl != null) playSource(refUrl, speed, onDone)
        else if (ttsReady) {
            tts?.setSpeechRate(speed)
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "ref")
        } else onDone()
    }

    private fun playSource(source: String, speed: Float, onDone: () -> Unit) {
        stop()
        try {
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .setUsage(AudioAttributes.USAGE_MEDIA).build()
                )
                setDataSource(source)
                setOnCompletionListener { onDone() }
                setOnErrorListener { _, _, _ -> onDone(); true }
                prepare()
                try { playbackParams = playbackParams.setSpeed(speed) } catch (_: Exception) {}
                start()
            }
        } catch (e: Exception) { onDone() }
    }

    fun stop() {
        tts?.stop()
        try { player?.stop() } catch (_: Exception) {}
        player?.release(); player = null
    }

    fun release() { stop(); tts?.shutdown(); tts = null }
}
