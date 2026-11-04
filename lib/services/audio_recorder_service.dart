// Thu âm cho Pronunciation API: WAV 16 kHz mono (định dạng server khuyên dùng),
// kèm phát lại bản ghi để người học tự nghe.

import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordingResult {
  final File file;
  final Duration duration;

  const RecordingResult(this.file, this.duration);
}

class AudioRecorderService {
  AudioRecorderService({AudioRecorder? recorder, AudioPlayer? player})
      : _recorder = recorder ?? AudioRecorder(),
        _player = player ?? AudioPlayer();

  static const maxDuration = Duration(seconds: 60);

  final AudioRecorder _recorder;
  final AudioPlayer _player;
  DateTime? _startedAt;

  /// Hỏi quyền micro (hiện hộp thoại hệ thống lần đầu).
  Future<bool> ensurePermission() => _recorder.hasPermission();

  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/speakmaster_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
          encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: path,
    );
    _startedAt = DateTime.now();
  }

  Future<RecordingResult?> stop() async {
    final path = await _recorder.stop();
    final started = _startedAt;
    _startedAt = null;
    if (path == null || started == null) return null;
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) return null;
    return RecordingResult(file, DateTime.now().difference(started));
  }

  Future<void> cancel() async {
    _startedAt = null;
    await _recorder.cancel();
  }

  Future<void> play(File file) async {
    await _player.stop();
    await _player.play(DeviceFileSource(file.path));
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _recorder.dispose();
  }
}
