import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/assessment.dart';
import '../models/models.dart';
import '../services/audio_recorder_service.dart';
import '../services/pronunciation_api.dart';
import '../services/pronunciation_engine.dart';
import '../widgets/assessment_result_view.dart';

class PronunciationScreen extends StatefulWidget {
  final PronunciationEngine engine;
  final Future<void> Function(Assessment assessment, LessonSentence sentence)
      onPracticeCompleted;

  const PronunciationScreen({
    super.key,
    required this.engine,
    required this.onPracticeCompleted,
  });

  @override
  State<PronunciationScreen> createState() => _PronunciationScreenState();
}

class _PronunciationScreenState extends State<PronunciationScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioRecorderService _recorder = AudioRecorderService();

  late ScoringMode _mode = widget.engine.mode;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  String _spokenTranscript = '';
  int _currentIndex = 0;
  Assessment? _result;
  RecordingResult? _lastRecording;
  String? _error;
  Map<String, PhonemeInfo> _catalog = const {};
  DateTime? _recordStartedAt;
  Timer? _ticker;
  int _elapsedSeconds = 0;

  static const List<LessonSentence> _sentences = [
    LessonSentence(
      id: 's1',
      text: 'She sells seashells by the seashore.',
      translation: 'Cô ấy bán vỏ sò bên bờ biển.',
      ipa: '/ʃiː sɛlz ˈsiːˌʃɛlz baɪ ðə ˈsiːˌʃɔːr/',
      category: 'TongueTwister',
      difficulty: 'Intermediate',
      focusSound: '/ʃ/ vs /s/',
      tips:
          'Âm /ʃ/ cần chu môi tròn và đẩy luồng hơi dày; âm /s/ khóe miệng kéo ngang.',
    ),
    LessonSentence(
      id: 's2',
      text: 'I think that this is the best solution for our team.',
      translation:
          'Tôi nghĩ rằng đây là giải pháp tốt nhất cho đội ngũ của chúng ta.',
      ipa: '/aɪ θɪŋk ðæt ðɪs ɪz ðə bɛst səˈluːʃən fɔːr ˈaʊər tiːm/',
      category: 'Daily',
      difficulty: 'Beginner',
      focusSound: '/θ/ & /ð/',
      tips:
          'Đặt đầu lưỡi nhẹ nhàng giữa hai hàm răng khi phát âm "think" /θ/ và "this" /ð/.',
    ),
    LessonSentence(
      id: 's3',
      text:
          'Working in a comfortable environment increases productivity significantly.',
      translation:
          'Làm việc trong môi trường thoải mái giúp tăng năng suất đáng kể.',
      ipa:
          '/ˈwɜːrkɪŋ ɪn ə ˈkʌmftərbəl ɪnˈvaɪrənmənt ɪnˈkriːsɪz ˌproʊdʌkˈtɪvəti sɪɡˈnɪfɪkəntli/',
      category: 'Business',
      difficulty: 'Advanced',
      focusSound: 'Trọng âm & Âm đuôi',
      tips:
          '"Comfortable" chỉ có 3 âm tiết /ˈkʌmftərbəl/, chú ý âm đuôi /ɪz/ ở "increases".',
    ),
  ];

  LessonSentence get _currentSentence => _sentences[_currentIndex];

  @override
  void initState() {
    super.initState();
    _checkEngine();
  }

  Future<void> _checkEngine() async {
    final mode = await widget.engine.refreshAvailability();
    final catalog = await widget.engine.phonemeCatalog();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _catalog = catalog;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    _speech.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
  }

  void _resetResult() {
    _result = null;
    _error = null;
    _lastRecording = null;
    _spokenTranscript = '';
  }

  void _startTicker() {
    _elapsedSeconds = 0;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds >= AudioRecorderService.maxDuration.inSeconds)
        _toggleRecording();
    });
  }

  Future<void> _toggleRecording() async {
    if (_isAnalyzing) return;
    if (!_isRecording) {
      await _startRecording();
    } else {
      await _stopAndAnalyze();
    }
  }

  Future<void> _startRecording() async {
    setState(_resetResult);
    if (_mode == ScoringMode.audio) {
      final granted = await _recorder.ensurePermission();
      if (!granted) {
        _showPermissionDenied();
        return;
      }
      await _recorder.start();
    } else {
      final available = await _speech.initialize();
      if (!available) {
        _showPermissionDenied();
        return;
      }
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: 'en_US',
          listenFor: AudioRecorderService.maxDuration,
        ),
        onResult: (val) =>
            setState(() => _spokenTranscript = val.recognizedWords),
      );
    }
    _recordStartedAt = DateTime.now();
    _startTicker();
    setState(() => _isRecording = true);
  }

  Future<void> _stopAndAnalyze() async {
    _ticker?.cancel();
    setState(() {
      _isRecording = false;
      _isAnalyzing = true;
    });
    final sentence = _currentSentence;
    try {
      final Assessment result;
      if (_mode == ScoringMode.audio) {
        final rec = await _recorder.stop();
        if (rec == null) {
          setState(() {
            _isAnalyzing = false;
            _error = 'Không ghi được âm thanh, hãy thử lại.';
          });
          return;
        }
        _lastRecording = rec;
        result = await widget.engine
            .assessAudio(audio: rec.file, sentence: sentence);
      } else {
        await _speech.stop();
        final started = _recordStartedAt ?? DateTime.now();
        result = await widget.engine.assessTranscript(
          transcript: _spokenTranscript,
          sentence: sentence,
          durationMs: DateTime.now().difference(started).inMilliseconds,
        );
      }
      if (!mounted) return;
      setState(() {
        _result = result;
        _isAnalyzing = false;
      });
      await widget.onPracticeCompleted(result, sentence);
    } on PronunciationApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _error = e.requestId == null
            ? e.userMessage
            : '${e.userMessage}\n(Mã yêu cầu: ${e.requestId})';
      });
      if (!e.isUserError) _offerFallback();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _error = 'Có lỗi khi chấm điểm: $e';
      });
    }
  }

  void _showPermissionDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Cần quyền sử dụng micro để thu âm. Hãy bật quyền Micro cho SpeakMaster trong Cài đặt.'),
      ),
    );
  }

  void _offerFallback() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: const Text('Máy chủ chấm điểm chưa sẵn sàng.'),
        action: SnackBarAction(
          label: 'Chấm dự phòng',
          onPressed: () => setState(() => _mode = ScoringMode.transcript),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _modeBanner(),
        const SizedBox(height: 12),
        _sentenceCard(context),
        if (_isAnalyzing)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('AI đang phân tích phát âm...'),
              ],
            ),
          ),
        if (_error != null)
          Card(
            color: Colors.red.withValues(alpha: 0.08),
            child: ListTile(
              leading: const Icon(Icons.error_outline, color: Colors.redAccent),
              title: Text(_error!),
            ),
          ),
        if (_result != null) ...[
          const SizedBox(height: 16),
          AssessmentResultView(
              assessment: _result!, onSpeak: _speak, catalog: _catalog),
        ],
      ],
    );
  }

  Widget _modeBanner() {
    final audio = _mode == ScoringMode.audio;
    return Row(
      children: [
        Icon(audio ? Icons.graphic_eq : Icons.text_fields,
            size: 18, color: audio ? Colors.teal : Colors.amber.shade800),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            audio
                ? 'Chấm trên audio (Pronunciation API)'
                : 'Chế độ dự phòng: chấm theo chữ nhận dạng',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
        if (widget.engine.hasApi && !_isRecording && !_isAnalyzing)
          TextButton(
            onPressed: () async {
              if (audio) {
                setState(() => _mode = ScoringMode.transcript);
              } else {
                await _checkEngine();
                if (mounted && _mode != ScoringMode.audio) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Chưa kết nối được Pronunciation API.')),
                  );
                }
              }
            },
            child: Text(audio ? 'Dùng dự phòng' : 'Thử lại API'),
          ),
      ],
    );
  }

  Widget _sentenceCard(BuildContext context) {
    final s = _currentSentence;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                    label: Text(s.category),
                    backgroundColor: Colors.teal.withValues(alpha: 0.15)),
                Text(
                  'Câu ${_currentIndex + 1}/${_sentences.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              s.text,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              s.ipa,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.teal,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              '"${s.translation}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontStyle: FontStyle.italic, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Mẹo khẩu hình (${s.focusSound}): ${s.tips}',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
            if (_isRecording) ...[
              const SizedBox(height: 16),
              Text(
                'Đang thu âm... ${_elapsedSeconds}s / ${AudioRecorderService.maxDuration.inSeconds}s',
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              if (_spokenTranscript.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('"$_spokenTranscript"')),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _speak(s.text),
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Nghe chuẩn'),
                ),
                FloatingActionButton.extended(
                  heroTag: 'record',
                  onPressed: _isAnalyzing ? null : _toggleRecording,
                  backgroundColor:
                      _isRecording ? Colors.redAccent : Colors.teal,
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white),
                  label: Text(
                    _isRecording ? 'Chấm điểm' : 'Thu âm',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: _isRecording || _isAnalyzing
                      ? null
                      : () => setState(() {
                            _currentIndex =
                                (_currentIndex + 1) % _sentences.length;
                            _resetResult();
                          }),
                  icon: const Icon(Icons.arrow_forward_ios),
                  tooltip: 'Câu tiếp theo',
                ),
              ],
            ),
            if (_lastRecording != null && !_isRecording)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextButton.icon(
                  onPressed: () => _recorder.play(_lastRecording!.file),
                  icon: const Icon(Icons.play_circle_outline),
                  label: Text(
                      'Nghe lại giọng của bạn (${(_lastRecording!.duration.inMilliseconds / 1000).toStringAsFixed(1)}s)'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
