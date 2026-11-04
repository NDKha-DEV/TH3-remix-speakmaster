import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../models/models.dart';
import '../services/ai_pronunciation_service.dart';

class PronunciationScreen extends StatefulWidget {
  final AIPronunciationService aiService;
  final Function(int minutes, int score, PronunciationResult result, LessonSentence sentence) onPracticeCompleted;

  const PronunciationScreen({
    super.key,
    required this.aiService,
    required this.onPracticeCompleted,
  });

  @override
  State<PronunciationScreen> createState() => _PronunciationScreenState();
}

class _PronunciationScreenState extends State<PronunciationScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isRecording = false;
  bool _isAnalyzing = false;
  String _spokenTranscript = '';
  int _currentIndex = 0;
  PronunciationResult? _result;
  WordAnalysis? _selectedWord;

  final List<LessonSentence> _sentences = const [
    LessonSentence(
      id: 's1',
      text: 'She sells seashells by the seashore.',
      translation: 'Cô ấy bán vỏ sò bên bờ biển.',
      ipa: '/ʃiː sɛlz ˈsiːˌʃɛlz baɪ ðə ˈsiːˌʃɔːr/',
      category: 'TongueTwister',
      difficulty: 'Intermediate',
      focusSound: '/ʃ/ vs /s/',
      tips: 'Âm /ʃ/ cần chu môi tròn và đẩy luồng hơi dày; âm /s/ khóe miệng kéo ngang.',
    ),
    LessonSentence(
      id: 's2',
      text: 'I think that this is the best solution for our team.',
      translation: 'Tôi nghĩ rằng đây là giải pháp tốt nhất cho đội ngũ của chúng ta.',
      ipa: '/aɪ θɪŋk ðæt ðɪs ɪz ðə bɛst səˈluːʃən fɔːr ˈaʊər tiːm/',
      category: 'Daily',
      difficulty: 'Beginner',
      focusSound: '/θ/ & /ð/',
      tips: 'Đặt đầu lưỡi nhẹ nhàng giữa hai hàm răng khi phát âm "think" /θ/ và "this" /ð/.',
    ),
    LessonSentence(
      id: 's3',
      text: 'Working in a comfortable environment increases productivity significantly.',
      translation: 'Làm việc trong môi trường thoải mái giúp tăng năng suất đáng kể.',
      ipa: '/ˈwɜːrkɪŋ ɪn ə ˈkʌmftərbəl ɪnˈvaɪrənmənt ɪnˈkriːsɪz ˌproʊdʌkˈtɪvəti sɪɡˈnɪfɪkəntli/',
      category: 'Business',
      difficulty: 'Advanced',
      focusSound: 'Trọng âm & Âm đuôi',
      tips: '"Comfortable" chỉ có 3 âm tiết /ˈkʌmftərbəl/, chú ý âm đuôi /ɪz/ ở "increases".',
    ),
  ];

  LessonSentence get _currentSentence => _sentences[_currentIndex];

  Future<void> _speakSample(String text) async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
  }

  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      final available = await _speech.initialize();
      if (available) {
        setState(() {
          _isRecording = true;
          _spokenTranscript = '';
          _result = null;
          _selectedWord = null;
        });
        await _speech.listen(
          localeId: 'en_US',
          onResult: (val) {
            setState(() {
              _spokenTranscript = val.recognizedWords;
            });
          },
        );
      }
    } else {
      await _speech.stop();
      setState(() {
        _isRecording = false;
        _isAnalyzing = true;
      });

      final res = await widget.aiService.analyzePronunciation(
        targetText: _currentSentence.text,
        userSpokenText: _spokenTranscript,
        category: _currentSentence.category,
        difficulty: _currentSentence.difficulty,
      );

      setState(() {
        _result = res;
        _selectedWord = res.wordAnalysis.isNotEmpty ? res.wordAnalysis.first : null;
        _isAnalyzing = false;
      });

      widget.onPracticeCompleted(1, res.overallScore, res, _currentSentence);
    }
  }

  Color _statusColor(String status) {
    if (status == 'correct') return Colors.teal;
    if (status == 'warning') return Colors.amber.shade700;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
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
                      label: Text(_currentSentence.category),
                      backgroundColor: Colors.teal.withOpacity(0.15),
                    ),
                    Text(
                      'Câu ${_currentIndex + 1}/${_sentences.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _currentSentence.text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentSentence.ipa,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '"${_currentSentence.translation}"',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.amber),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mẹo khẩu hình (${_currentSentence.focusSound}): ${_currentSentence.tips}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isRecording) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Đang lắng nghe giọng nói của bạn...',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                  if (_spokenTranscript.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('"$_spokenTranscript"'),
                    ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _speakSample(_currentSentence.text),
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Nghe chuẩn'),
                    ),
                    FloatingActionButton.extended(
                      onPressed: _isAnalyzing ? null : _toggleRecording,
                      backgroundColor: _isRecording ? Colors.redAccent : Colors.teal,
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white),
                      label: Text(
                        _isRecording ? 'Chấm điểm' : 'Thu âm',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _currentIndex = (_currentIndex + 1) % _sentences.length;
                          _result = null;
                          _selectedWord = null;
                        });
                      },
                      icon: const Icon(Icons.arrow_forward_ios),
                      tooltip: 'Câu tiếp theo',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_isAnalyzing)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_result != null) ...[
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kết Quả Phân Tích Âm Vị AI',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.teal,
                        child: Text(
                          '${_result!.overallScore}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _result!.wordAnalysis.map((w) {
                      final color = _statusColor(w.status);
                      return ActionChip(
                        backgroundColor: color.withOpacity(0.12),
                        side: BorderSide(color: color),
                        label: Text(
                          '${w.word} (${w.score}%)',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => setState(() => _selectedWord = w),
                      );
                    }).toList(),
                  ),
                  if (_selectedWord != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Từ "${_selectedWord!.word}" - Chuẩn IPA: ${_selectedWord!.expectedIpa}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text('Chi tiết: ${_selectedWord!.specificError}'),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Nhận xét AI: ${_result!.vietnameseSummary}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text('Khẩu hình & Đặt lưỡi: ${_result!.tongueMouthAdvice}'),
                  const SizedBox(height: 12),
                  const Text(
                    'Bài tập đề xuất:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ..._result!.recommendedDrills.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• $d'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
