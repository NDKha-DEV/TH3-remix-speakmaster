package com.example.englishapp.m3.audio

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File

const val MAX_AUDIO_SECONDS = 60
const val MAX_AUDIO_BYTES = 10L * 1024 * 1024

sealed class PickResult {
    data class Ok(val file: File, val durationMs: Long, val name: String) : PickResult()
    data class Error(val message: String) : PickResult()
}

/**
 * Xử lý file âm thanh người dùng chọn từ bộ nhớ (Audio Upload):
 * kiểm tra loại file, dung lượng, độ dài rồi sao chép vào cache để upload/phát lại.
 * Không cần quyền READ_STORAGE vì dùng Storage Access Framework (GetContent).
 */
object AudioImporter {

    fun import(context: Context, uri: Uri): PickResult {
        val resolver = context.contentResolver
        val mime = resolver.getType(uri) ?: ""
        if (!mime.startsWith("audio/")) return PickResult.Error("File không phải âm thanh.")

        var name = "audio"
        var size = -1L
        resolver.query(uri, null, null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                c.getColumnIndex(OpenableColumns.DISPLAY_NAME).takeIf { it >= 0 }?.let { name = c.getString(it) }
                c.getColumnIndex(OpenableColumns.SIZE).takeIf { it >= 0 }?.let { size = c.getLong(it) }
            }
        }
        if (size > MAX_AUDIO_BYTES) return PickResult.Error("File quá lớn (tối đa 10MB).")

        val ext = name.substringAfterLast('.', "m4a")
        val dest = File(context.cacheDir, "import_${System.currentTimeMillis()}.$ext")
        try {
            resolver.openInputStream(uri)?.use { input -> dest.outputStream().use { input.copyTo(it) } }
                ?: return PickResult.Error("Không mở được file.")
        } catch (e: Exception) {
            return PickResult.Error("Không đọc được file: ${e.message}")
        }

        val duration = try {
            MediaMetadataRetriever().run {
                setDataSource(dest.absolutePath)
                val d = extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
                release(); d
            }
        } catch (e: Exception) { null }

        if (duration == null) { dest.delete(); return PickResult.Error("Không đọc được file âm thanh này.") }
        if (duration > MAX_AUDIO_SECONDS * 1000L) {
            dest.delete()
            return PickResult.Error("File dài ${duration / 1000}s, tối đa ${MAX_AUDIO_SECONDS}s.")
        }
        return PickResult.Ok(dest, duration, name)
    }
}
