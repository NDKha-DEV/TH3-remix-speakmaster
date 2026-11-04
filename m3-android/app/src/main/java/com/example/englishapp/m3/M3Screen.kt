package com.example.englishapp.m3

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.englishapp.m3.audio.AudioImporter
import com.example.englishapp.m3.audio.MAX_AUDIO_SECONDS
import java.io.File

/**
 * Màn hình gốc của M3. Cách dùng ở nơi khác:
 *
 *   M3Screen(onAudioSubmitted = { file, exerciseId -> /* gọi M4 chấm điểm */ })
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun M3Screen(
    vm: M3ViewModel = viewModel(),
    onAudioSubmitted: (File, Int) -> Unit = { _, _ -> }
) {
    val ui by vm.ui.collectAsStateWithLifecycle()
    BackHandler(enabled = ui.selected != null) { vm.back() }

    Scaffold(topBar = {
        TopAppBar(
            title = { Text(ui.selected?.let { "Luyện phát âm" } ?: "Bài tập phát âm") },
            navigationIcon = { if (ui.selected != null) TextButton(onClick = vm::back) { Text("←") } }
        )
    }) { pad ->
        Box(Modifier.padding(pad)) {
            val ex = ui.selected
            if (ex == null) ExerciseList(ui.exercises, vm::open)
            else ExerciseDetail(ex, ui, vm, onAudioSubmitted)
        }
    }
}

/* ---------------- 1. Exercise List ---------------- */
@Composable
private fun ExerciseList(list: List<Exercise>, onClick: (Exercise) -> Unit) {
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        items(list, key = { it.id }) { e ->
            Card(Modifier.fillMaxWidth().clickable { onClick(e) }) {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(e.text, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Text(e.ipa, color = MaterialTheme.colorScheme.primary)
                    }
                    AssistChip(onClick = {}, label = { Text(e.level) })
                }
            }
        }
    }
}

/* ---------------- 2. Exercise Detail ---------------- */
@Composable
private fun ExerciseDetail(ex: Exercise, ui: M3UiState, vm: M3ViewModel, onSubmitted: (File, Int) -> Unit) {
    val ctx = LocalContext.current
    val activity = ctx.findActivity()

    // ---- Microphone permission ----
    var micGranted by remember { mutableStateOf(hasMic(ctx)) }
    var permBlocked by remember { mutableStateOf(false) }       // user chọn "Không hỏi lại"
    val askMic = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        micGranted = ok
        permBlocked = !ok && activity != null &&
            !androidx.core.app.ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.RECORD_AUDIO)
        if (ok) vm.info("Đã cấp quyền micro.")
    }

    // ---- Audio upload (Storage Access Framework, không cần quyền storage) ----
    val pickAudio = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        uri?.let { vm.onFilePicked(AudioImporter.import(ctx, it)) }
    }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {

        // IPA + Reference audio
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                AssistChip(onClick = {}, label = { Text(ex.level) })
                Text(ex.text, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Text(ex.ipa, fontSize = 20.sp, color = MaterialTheme.colorScheme.primary)
                Text("💡 ${ex.hint}", Modifier.padding(top = 6.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
                Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { vm.playReference(false) }) { Text("🔊 Nghe mẫu") }
                    FilledTonalButton(onClick = { vm.playReference(true) }) { Text("🐢 Nghe chậm") }
                }
            }
        }

        // Microphone permission
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Text("1. Quyền microphone", fontWeight = FontWeight.SemiBold)
                Text(
                    when {
                        micGranted -> "✔ Đã cấp quyền micro"
                        permBlocked -> "✖ Quyền micro bị chặn"
                        else -> "Chưa cấp quyền"
                    },
                    Modifier.padding(vertical = 6.dp),
                    color = if (micGranted) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (!micGranted) {
                    if (permBlocked) {
                        Text("Hãy mở Cài đặt → Quyền → Micro → Cho phép.", color = MaterialTheme.colorScheme.error, fontSize = 13.sp)
                        FilledTonalButton(onClick = {
                            ctx.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", ctx.packageName, null)))
                        }) { Text("Mở cài đặt ứng dụng") }
                    } else {
                        FilledTonalButton(onClick = { askMic.launch(Manifest.permission.RECORD_AUDIO) }) { Text("Cấp quyền micro") }
                    }
                }
            }
        }

        // Recording / Playback
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("2. Ghi âm", fontWeight = FontWeight.SemiBold)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (ui.recState != RecState.Recording) {
                        Button(
                            onClick = { if (micGranted) vm.startRecording() else askMic.launch(Manifest.permission.RECORD_AUDIO) },
                            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                            enabled = !ui.submitting
                        ) { Text(if (ui.recState == RecState.Recorded) "↺ Ghi lại" else "⏺ Bắt đầu ghi") }
                    } else {
                        Button(onClick = vm::stopRecording) { Text("⏹ Dừng") }
                    }
                    Text(formatTime(if (ui.recState == RecState.Recorded) ui.audioDurationMs else ui.elapsedMs), fontWeight = FontWeight.SemiBold)
                }
                if (ui.recState == RecState.Recording) LinearProgressIndicator(progress = { ui.level }, Modifier.fillMaxWidth())
                if (ui.recState == RecState.Recorded) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FilledTonalButton(onClick = vm::togglePlayback) { Text(if (ui.playing) "⏸ Dừng nghe" else "▶ Nghe lại") }
                        Button(onClick = { vm.submit(onSubmitted) }, enabled = !ui.submitting) {
                            if (ui.submitting) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp) else Text("Gửi để chấm điểm")
                        }
                    }
                }
            }
        }

        // Audio Upload
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Text("3. Hoặc tải file âm thanh lên", fontWeight = FontWeight.SemiBold)
                Text("mp3, wav, m4a… tối đa 10MB, dài tối đa ${MAX_AUDIO_SECONDS} giây.", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                FilledTonalButton(onClick = { pickAudio.launch("audio/*") }, Modifier.padding(top = 8.dp), enabled = ui.recState != RecState.Recording) {
                    Text("📁 Chọn file")
                }
            }
        }

        ui.message?.let {
            Text(it, color = if (ui.messageIsError) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary, fontSize = 14.sp)
        }
    }
}

private fun hasMic(ctx: Context) =
    ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

private fun Context.findActivity(): Activity? {
    var c = this
    while (c is ContextWrapper) { if (c is Activity) return c; c = c.baseContext }
    return null
}

private fun formatTime(ms: Long): String {
    val s = ms / 1000
    return "%02d:%02d".format(s / 60, s % 60)
}
