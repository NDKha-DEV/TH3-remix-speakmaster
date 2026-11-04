package com.example.englishapp.m3

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.englishapp.m3.audio.*
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File

enum class RecState { Idle, Recording, Recorded }

data class M3UiState(
    val exercises: List<Exercise> = ExerciseRepository.sample,
    val selected: Exercise? = null,
    val recState: RecState = RecState.Idle,
    val elapsedMs: Long = 0,
    val level: Float = 0f,
    val audioFile: File? = null,
    val audioDurationMs: Long = 0,
    val playing: Boolean = false,
    val submitting: Boolean = false,
    val message: String? = null,
    val messageIsError: Boolean = false
)

class M3ViewModel(app: Application) : AndroidViewModel(app) {

    /** Đổi sang HttpAudioSubmitter("https://.../api/recordings") khi backend sẵn sàng. */
    var submitter: AudioSubmitter = MockAudioSubmitter()

    private val recorder = AudioRecorder(app)
    private val player = AudioPlayer(app)
    private var tickJob: Job? = null

    private val _ui = MutableStateFlow(M3UiState())
    val ui: StateFlow<M3UiState> = _ui.asStateFlow()

    // ----- Exercise List / Detail -----
    fun open(ex: Exercise) { resetRecording(); _ui.update { it.copy(selected = ex, message = null) } }
    fun back() { resetRecording(); player.stop(); _ui.update { it.copy(selected = null, message = null) } }

    // ----- Reference audio -----
    fun playReference(slow: Boolean) {
        val ex = _ui.value.selected ?: return
        player.playReference(ex.text, ex.refAudioUrl, if (slow) 0.6f else 1f)
    }

    // ----- Recording (UI phải đảm bảo đã có quyền RECORD_AUDIO) -----
    fun startRecording() {
        try {
            player.stop(); resetRecording()
            recorder.start()
            _ui.update { it.copy(recState = RecState.Recording, elapsedMs = 0, message = "🎙 Đang ghi… hãy đọc to và rõ.", messageIsError = false) }
            tickJob = viewModelScope.launch {
                val t0 = System.currentTimeMillis()
                while (true) {
                    val e = System.currentTimeMillis() - t0
                    _ui.update { it.copy(elapsedMs = e, level = recorder.level()) }
                    if (e >= MAX_AUDIO_SECONDS * 1000L) { stopRecording(); break }
                    delay(80)
                }
            }
        } catch (e: Exception) {
            error("Không thể bắt đầu ghi âm: ${e.message}")
        }
    }

    fun stopRecording() {
        tickJob?.cancel()
        val result = recorder.stop()
        if (result == null) {
            _ui.update { it.copy(recState = RecState.Idle, level = 0f) }
            error("Bản ghi quá ngắn, hãy thử lại.")
        } else {
            _ui.update {
                it.copy(recState = RecState.Recorded, audioFile = result.first, audioDurationMs = result.second,
                    level = 0f, message = "Ghi xong. Nghe lại rồi gửi, hoặc ghi lại.", messageIsError = false)
            }
        }
    }

    // ----- Playback -----
    fun togglePlayback() {
        val f = _ui.value.audioFile ?: return
        if (_ui.value.playing) { player.stop(); _ui.update { it.copy(playing = false) } }
        else { _ui.update { it.copy(playing = true) }; player.playFile(f) { _ui.update { s -> s.copy(playing = false) } } }
    }

    // ----- Audio Upload -----
    fun onFilePicked(result: PickResult) {
        when (result) {
            is PickResult.Error -> error(result.message)
            is PickResult.Ok -> {
                resetRecording()
                _ui.update {
                    it.copy(recState = RecState.Recorded, audioFile = result.file, audioDurationMs = result.durationMs,
                        message = "Đã chọn: ${result.name} (${"%.1f".format(result.durationMs / 1000.0)}s)", messageIsError = false)
                }
            }
        }
    }

    // ----- Submit -> bàn giao cho M4 -----
    fun submit(onSubmitted: (File, Int) -> Unit = { _, _ -> }) {
        val s = _ui.value
        val file = s.audioFile ?: return
        val ex = s.selected ?: return
        _ui.update { it.copy(submitting = true, message = "Đang gửi…", messageIsError = false) }
        viewModelScope.launch {
            submitter.submit(file, ex.id, s.audioDurationMs)
                .onSuccess { msg ->
                    _ui.update { it.copy(submitting = false, message = "Đã gửi thành công ✔ ($msg)", messageIsError = false) }
                    onSubmitted(file, ex.id)
                }
                .onFailure { e ->
                    _ui.update { it.copy(submitting = false, message = "Gửi thất bại: ${e.message}", messageIsError = true) }
                }
        }
    }

    fun resetRecording() {
        tickJob?.cancel(); player.stop()
        if (recorder.isRecording) recorder.stop()
        _ui.value.audioFile?.delete()
        _ui.update { it.copy(recState = RecState.Idle, elapsedMs = 0, level = 0f, audioFile = null, audioDurationMs = 0, playing = false, message = null) }
    }

    fun error(msg: String) = _ui.update { it.copy(message = msg, messageIsError = true) }
    fun info(msg: String) = _ui.update { it.copy(message = msg, messageIsError = false) }

    override fun onCleared() { recorder.release(); player.release() }
}
