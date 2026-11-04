import React, { useState, useRef, useEffect } from 'react';
import { LessonSentence, PronunciationResult, UserProfile, WordAnalysis } from '../types';
import { LESSON_SENTENCES, LESSON_CATEGORIES, COMMON_PHONEMES_GUIDE } from '../data/lessons';
import { AudioRecorder, SpeechHelper } from '../utils/audio';
import { AudioVisualizer } from './AudioVisualizer';
import {
  Mic,
  Square,
  Volume2,
  RotateCcw,
  Sparkles,
  ChevronRight,
  Info,
  CheckCircle2,
  AlertTriangle,
  XCircle,
  HelpCircle,
  Play,
  ArrowRight,
  Award,
  Zap,
  BookOpen
} from 'lucide-react';
import confetti from 'canvas-confetti';

interface PronunciationStudioProps {
  userProfile: UserProfile | null;
  onRecordPractice: (minutes: number, score: number, result: PronunciationResult, sentence: LessonSentence) => void;
  selectedSentenceId?: string;
}

export const PronunciationStudio: React.FC<PronunciationStudioProps> = ({
  userProfile,
  onRecordPractice,
  selectedSentenceId
}) => {
  const [selectedCategory, setSelectedCategory] = useState<string>('All');
  const [currentSentenceIndex, setCurrentSentenceIndex] = useState<number>(0);
  const [voiceAccent, setVoiceAccent] = useState<'US' | 'UK'>('US');
  const [voiceRate, setVoiceRate] = useState<number>(0.9);

  // Recording states
  const [isRecording, setIsRecording] = useState<boolean>(false);
  const [recordingSeconds, setRecordingSeconds] = useState<number>(0);
  const [liveTranscript, setLiveTranscript] = useState<string>('');
  const [audioStream, setAudioStream] = useState<MediaStream | null>(null);
  const [recordedAudioUrl, setRecordedAudioUrl] = useState<string | null>(null);
  const [isAnalyzing, setIsAnalyzing] = useState<boolean>(false);

  // Result state
  const [analysisResult, setAnalysisResult] = useState<PronunciationResult | null>(null);
  const [selectedWord, setSelectedWord] = useState<WordAnalysis | null>(null);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const recorderRef = useRef<AudioRecorder | null>(null);
  const timerRef = useRef<any>(null);
  const userAudioPlayerRef = useRef<HTMLAudioElement | null>(null);

  const filteredSentences = LESSON_SENTENCES.filter(
    s => selectedCategory === 'All' || s.category === selectedCategory
  );
  const currentSentence = filteredSentences[currentSentenceIndex] || LESSON_SENTENCES[0];

  useEffect(() => {
    if (selectedSentenceId) {
      const idx = filteredSentences.findIndex(s => s.id === selectedSentenceId);
      if (idx !== -1) setCurrentSentenceIndex(idx);
    }
  }, [selectedSentenceId]);

  // Clean up on unmount
  useEffect(() => {
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
      if (recorderRef.current) recorderRef.current.cleanup();
      SpeechHelper.stopSpeechRecognition();
    };
  }, []);

  const handleStartRecording = async () => {
    try {
      setErrorMsg(null);
      setLiveTranscript('');
      setAnalysisResult(null);
      setSelectedWord(null);
      setRecordedAudioUrl(null);
      setRecordingSeconds(0);

      const recorder = new AudioRecorder();
      recorderRef.current = recorder;
      const stream = await recorder.start();
      setAudioStream(stream);
      setIsRecording(true);

      // Start recognition in parallel
      SpeechHelper.startSpeechRecognition(
        (transcript) => {
          setLiveTranscript(transcript);
        },
        (err) => {
          console.warn('Speech recognition warning:', err);
        },
        () => {
          // Ended
        }
      );

      timerRef.current = setInterval(() => {
        setRecordingSeconds((prev) => prev + 1);
      }, 1000);
    } catch (err: any) {
      console.error('Microphone error:', err);
      setErrorMsg(
        'Không thể truy cập Microphone. Vui lòng cho phép quyền ghi âm trong trình duyệt để luyện phát âm.'
      );
      setIsRecording(false);
    }
  };

  const handleStopRecording = async () => {
    if (!recorderRef.current) return;
    if (timerRef.current) clearInterval(timerRef.current);
    SpeechHelper.stopSpeechRecognition();
    setIsRecording(false);
    setAudioStream(null);

    try {
      setIsAnalyzing(true);
      const audioData = await recorderRef.current.stop();
      setRecordedAudioUrl(audioData.url);

      // Send to server-side Gemini AI for acoustic & phoneme analysis
      const response = await fetch('/api/analyze-pronunciation', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          targetText: currentSentence.text,
          userSpokenText: liveTranscript,
          audioBase64: audioData.base64,
          mimeType: audioData.mimeType,
          category: currentSentence.category,
          difficulty: currentSentence.difficulty
        })
      });

      if (!response.ok) {
        throw new Error('Máy chủ phân tích phản hồi lỗi');
      }

      const result: PronunciationResult = await response.json();
      setAnalysisResult(result);
      if (result.wordAnalysis?.length > 0) {
        setSelectedWord(result.wordAnalysis[0]);
      }

      // Celebrate high scores with confetti!
      if (result.overallScore >= 80) {
        confetti({
          particleCount: 80,
          spread: 70,
          origin: { y: 0.6 }
        });
      }

      // Save to Firebase and update streak
      const practiceMinutes = Math.max(1, Math.round(recordingSeconds / 60) || 1);
      onRecordPractice(practiceMinutes, result.overallScore, result, currentSentence);
    } catch (err: any) {
      console.error('Analysis error:', err);
      setErrorMsg('Không thể hoàn tất phân tích âm vị. Đang thử lại chế độ dự phòng.');
    } finally {
      setIsAnalyzing(false);
    }
  };

  const playNativeSentence = () => {
    SpeechHelper.speakText(currentSentence.text, voiceAccent, voiceRate);
  };

  const playWordAudio = (word: string) => {
    SpeechHelper.speakText(word, voiceAccent, 0.85);
  };

  const playUserVoice = () => {
    if (userAudioPlayerRef.current && recordedAudioUrl) {
      userAudioPlayerRef.current.currentTime = 0;
      userAudioPlayerRef.current.play();
    }
  };

  const nextSentence = () => {
    setAnalysisResult(null);
    setSelectedWord(null);
    setRecordedAudioUrl(null);
    setCurrentSentenceIndex((prev) => (prev + 1) % filteredSentences.length);
  };

  const prevSentence = () => {
    setAnalysisResult(null);
    setSelectedWord(null);
    setRecordedAudioUrl(null);
    setCurrentSentenceIndex((prev) => (prev - 1 + filteredSentences.length) % filteredSentences.length);
  };

  return (
    <div className="space-y-6 pb-20">
      {/* Category selector pills */}
      <div className="flex items-center gap-2 overflow-x-auto pb-1 no-scrollbar">
        {LESSON_CATEGORIES.map((cat) => (
          <button
            key={cat.id}
            onClick={() => {
              setSelectedCategory(cat.id);
              setCurrentSentenceIndex(0);
              setAnalysisResult(null);
              setSelectedWord(null);
            }}
            className={`px-3.5 py-1.5 rounded-full text-xs font-semibold whitespace-nowrap transition-all flex items-center gap-1.5 ${
              selectedCategory === cat.id
                ? 'bg-emerald-600 text-white shadow-md shadow-emerald-600/20'
                : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-700/60 hover:bg-slate-50 dark:hover:bg-slate-750'
            }`}
          >
            <span>{cat.label}</span>
          </button>
        ))}
      </div>

      {/* Main Pronunciation Card */}
      <div className="bg-white dark:bg-slate-900 rounded-3xl p-6 shadow-xl border border-slate-200 dark:border-slate-800 relative overflow-hidden transition-all">
        {/* Card Header */}
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <span className="px-2.5 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-emerald-500/15 text-emerald-600 dark:text-emerald-400">
              {currentSentence.category}
            </span>
            <span className={`px-2.5 py-1 rounded-full text-xs font-semibold ${
              currentSentence.difficulty === 'Beginner'
                ? 'bg-blue-500/15 text-blue-600 dark:text-blue-400'
                : currentSentence.difficulty === 'Intermediate'
                ? 'bg-amber-500/15 text-amber-600 dark:text-amber-400'
                : 'bg-purple-500/15 text-purple-600 dark:text-purple-400'
            }`}>
              {currentSentence.difficulty === 'Beginner' ? 'Cơ bản' : currentSentence.difficulty === 'Intermediate' ? 'Trung cấp' : 'Nâng cao'}
            </span>
          </div>

          <div className="flex items-center gap-2">
            {/* Accent toggle */}
            <div className="flex bg-slate-100 dark:bg-slate-800 p-0.5 rounded-xl text-xs font-semibold">
              <button
                onClick={() => setVoiceAccent('US')}
                className={`px-2 py-1 rounded-lg transition ${
                  voiceAccent === 'US' ? 'bg-white dark:bg-slate-700 text-emerald-600 shadow-sm' : 'text-slate-400'
                }`}
              >
                US (Mỹ)
              </button>
              <button
                onClick={() => setVoiceAccent('UK')}
                className={`px-2 py-1 rounded-lg transition ${
                  voiceAccent === 'UK' ? 'bg-white dark:bg-slate-700 text-emerald-600 shadow-sm' : 'text-slate-400'
                }`}
              >
                UK (Anh)
              </button>
            </div>

            <span className="text-xs text-slate-400 font-mono">
              {currentSentenceIndex + 1}/{filteredSentences.length}
            </span>
          </div>
        </div>

        {/* Target Sentence Display */}
        <div className="my-4 text-center">
          <h2 className="text-2xl md:text-3xl font-extrabold text-slate-800 dark:text-white tracking-tight leading-snug">
            {currentSentence.text}
          </h2>
          <p className="text-sm font-mono text-emerald-600 dark:text-emerald-400 mt-2 font-medium">
            {currentSentence.ipa}
          </p>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1 italic">
            "{currentSentence.translation}"
          </p>

          <div className="inline-flex items-center gap-1.5 mt-3 px-3 py-1 rounded-full bg-slate-100 dark:bg-slate-800/80 text-xs text-slate-600 dark:text-slate-300">
            <Zap className="w-3.5 h-3.5 text-amber-500" />
            <span>Âm trọng tâm: <strong className="text-amber-500">{currentSentence.focusSound}</strong></span>
          </div>
        </div>

        {/* Tip Box */}
        <div className="mt-4 p-3 rounded-2xl bg-amber-500/10 border border-amber-500/20 text-xs text-amber-800 dark:text-amber-300 flex items-start gap-2.5 text-left">
          <Info className="w-4 h-4 text-amber-500 shrink-0 mt-0.5" />
          <p className="leading-relaxed">
            <strong>Mẹo phát âm:</strong> {currentSentence.tips}
          </p>
        </div>

        {/* Audio Visualizer / Live Transcript while recording */}
        {isRecording && (
          <div className="mt-5 p-4 rounded-2xl bg-slate-950 text-white border border-slate-800 flex flex-col items-center">
            <div className="flex items-center gap-2 mb-2 text-rose-500 text-xs font-bold tracking-wide uppercase animate-pulse">
              <span className="w-2.5 h-2.5 rounded-full bg-rose-500" />
              Đang thu âm phát âm ({recordingSeconds}s)...
            </div>

            <AudioVisualizer isRecording={isRecording} stream={audioStream} />

            <div className="text-xs text-slate-300 mt-2 max-w-sm text-center italic">
              {liveTranscript ? `"${liveTranscript}"` : 'Đang lắng nghe giọng nói tiếng Anh của bạn...'}
            </div>
          </div>
        )}

        {/* Analyzing Spinner */}
        {isAnalyzing && (
          <div className="mt-5 p-5 rounded-2xl bg-emerald-500/10 border border-emerald-500/30 flex flex-col items-center justify-center text-center">
            <div className="w-8 h-8 border-3 border-emerald-500 border-t-transparent rounded-full animate-spin mb-2" />
            <p className="text-sm font-bold text-emerald-700 dark:text-emerald-400">
              AI đang phân tích âm vị & so sánh với chuẩn bản xứ...
            </p>
            <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">
              Đánh giá khẩu hình, âm đuôi, độ trôi chảy và ngữ điệu
            </p>
          </div>
        )}

        {/* Error notice */}
        {errorMsg && (
          <div className="mt-4 p-3 rounded-2xl bg-rose-500/10 border border-rose-500/20 text-xs text-rose-600 dark:text-rose-400">
            {errorMsg}
          </div>
        )}

        {/* Action Controls */}
        <div className="mt-6 pt-5 border-t border-slate-100 dark:border-slate-800 flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <button
              onClick={playNativeSentence}
              className="px-3.5 py-2.5 rounded-2xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 text-xs font-bold flex items-center gap-1.5 transition active:scale-95 shadow-sm"
              title="Nghe phát âm chuẩn người bản xứ"
            >
              <Volume2 className="w-4 h-4 text-emerald-500" />
              Nghe âm chuẩn ({voiceAccent})
            </button>

            {recordedAudioUrl && (
              <button
                onClick={playUserVoice}
                className="px-3.5 py-2.5 rounded-2xl bg-teal-50 dark:bg-teal-950/40 border border-teal-200 dark:border-teal-800 hover:bg-teal-100 text-teal-700 dark:text-teal-300 text-xs font-bold flex items-center gap-1.5 transition active:scale-95"
                title="Nghe lại giọng thu của bạn"
              >
                <Play className="w-4 h-4 text-teal-500" />
                Nghe lại giọng bạn
              </button>
            )}
          </div>

          {/* Big Record Button (Floating style) */}
          <div className="flex items-center gap-2">
            {!isRecording ? (
              <button
                onClick={handleStartRecording}
                disabled={isAnalyzing}
                className="px-6 py-3.5 rounded-full bg-gradient-to-r from-emerald-500 via-teal-500 to-emerald-600 hover:from-emerald-600 hover:to-teal-600 text-white font-bold text-sm flex items-center gap-2.5 shadow-lg shadow-emerald-500/30 transition transform active:scale-95"
              >
                <Mic className="w-5 h-5" />
                Bắt đầu Đọc & Thu âm
              </button>
            ) : (
              <button
                onClick={handleStopRecording}
                className="px-6 py-3.5 rounded-full bg-rose-600 hover:bg-rose-700 text-white font-bold text-sm flex items-center gap-2.5 shadow-lg shadow-rose-600/30 transition transform active:scale-95 animate-pulse"
              >
                <Square className="w-5 h-5 fill-current" />
                Hoàn tất & Chấm điểm
              </button>
            )}
          </div>

          <div className="flex items-center gap-1">
            <button
              onClick={prevSentence}
              className="p-2.5 rounded-2xl border border-slate-200 dark:border-slate-800 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-500 dark:text-slate-400 transition"
              title="Câu trước"
            >
              ←
            </button>
            <button
              onClick={nextSentence}
              className="p-2.5 rounded-2xl border border-slate-200 dark:border-slate-800 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-500 dark:text-slate-400 transition"
              title="Câu tiếp theo"
            >
              →
            </button>
          </div>
        </div>

        {recordedAudioUrl && (
          <audio ref={userAudioPlayerRef} src={recordedAudioUrl} className="hidden" />
        )}
      </div>

      {/* AI Analysis & Phoneme Feedback Section */}
      {analysisResult && (
        <div className="bg-white dark:bg-slate-900 rounded-3xl p-6 shadow-xl border border-slate-200 dark:border-slate-800 space-y-6 animate-fade-in">
          {/* Section Header */}
          <div className="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-emerald-500 to-teal-400 text-white flex items-center justify-center font-bold shadow-md shadow-emerald-500/20">
                <Sparkles className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-lg font-bold text-slate-800 dark:text-white">
                  Kết quả Chấm điểm AI Âm vị
                </h3>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  {analysisResult.engine === 'gemini-3.8-flash'
                    ? 'Phân tích đa chiều bởi Gemini 3.8 Flash'
                    : 'Động cơ âm vị học chuẩn quốc tế IPA'}
                </p>
              </div>
            </div>

            <div className="text-right">
              <span className="text-xs font-semibold px-2.5 py-1 rounded-full bg-emerald-500/10 text-emerald-600 dark:text-emerald-400">
                Đã lưu vào Firestore ✓
              </span>
            </div>
          </div>

          {/* Scores Overview Row */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            {/* Overall Circular Score */}
            <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700/60 flex flex-col items-center justify-center text-center">
              <div className="relative w-24 h-24 flex items-center justify-center">
                <svg className="w-full h-full transform -rotate-90" viewBox="0 0 36 36">
                  <path
                    className="text-slate-200 dark:text-slate-700 stroke-current"
                    strokeWidth="3.5"
                    fill="none"
                    d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                  />
                  <path
                    className={`${
                      analysisResult.overallScore >= 80
                        ? 'text-emerald-500'
                        : analysisResult.overallScore >= 65
                        ? 'text-amber-500'
                        : 'text-rose-500'
                    } stroke-current transition-all duration-1000 ease-out`}
                    strokeDasharray={`${analysisResult.overallScore}, 100`}
                    strokeWidth="3.5"
                    strokeLinecap="round"
                    fill="none"
                    d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                  />
                </svg>
                <div className="absolute flex flex-col items-center justify-center">
                  <span className="text-2xl font-black text-slate-800 dark:text-white">
                    {analysisResult.overallScore}
                  </span>
                  <span className="text-[10px] text-slate-400 font-semibold uppercase">Điểm tổng</span>
                </div>
              </div>
              <p className="mt-2 text-xs font-bold text-slate-700 dark:text-slate-200">
                {analysisResult.overallScore >= 85
                  ? 'Xuất sắc! Chuẩn bản xứ'
                  : analysisResult.overallScore >= 70
                  ? 'Rất tốt! Cần chú ý âm đuôi'
                  : 'Cần luyện thêm khẩu hình'}
              </p>
            </div>

            {/* Sub-scores */}
            <div className="md:col-span-3 grid grid-cols-3 gap-3">
              <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700/60 flex flex-col justify-between">
                <div>
                  <span className="text-xs text-slate-500 dark:text-slate-400 font-semibold">Độ chuẩn âm vị</span>
                  <p className="text-2xl font-black text-emerald-600 dark:text-emerald-400 mt-1">
                    {analysisResult.accuracyScore}%
                  </p>
                </div>
                <div className="w-full bg-slate-200 dark:bg-slate-700 h-2 rounded-full overflow-hidden mt-2">
                  <div
                    className="bg-emerald-500 h-full rounded-full transition-all duration-700"
                    style={{ width: `${analysisResult.accuracyScore}%` }}
                  />
                </div>
                <span className="text-[11px] text-slate-400 mt-1">Nguyên âm & Phụ âm</span>
              </div>

              <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700/60 flex flex-col justify-between">
                <div>
                  <span className="text-xs text-slate-500 dark:text-slate-400 font-semibold">Độ trôi chảy</span>
                  <p className="text-2xl font-black text-cyan-600 dark:text-cyan-400 mt-1">
                    {analysisResult.fluencyScore}%
                  </p>
                </div>
                <div className="w-full bg-slate-200 dark:bg-slate-700 h-2 rounded-full overflow-hidden mt-2">
                  <div
                    className="bg-cyan-500 h-full rounded-full transition-all duration-700"
                    style={{ width: `${analysisResult.fluencyScore}%` }}
                  />
                </div>
                <span className="text-[11px] text-slate-400 mt-1">Ngữ điệu & Nhịp điệu</span>
              </div>

              <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700/60 flex flex-col justify-between">
                <div>
                  <span className="text-xs text-slate-500 dark:text-slate-400 font-semibold">Độ hoàn chỉnh</span>
                  <p className="text-2xl font-black text-indigo-600 dark:text-indigo-400 mt-1">
                    {analysisResult.completenessScore}%
                  </p>
                </div>
                <div className="w-full bg-slate-200 dark:bg-slate-700 h-2 rounded-full overflow-hidden mt-2">
                  <div
                    className="bg-indigo-500 h-full rounded-full transition-all duration-700"
                    style={{ width: `${analysisResult.completenessScore}%` }}
                  />
                </div>
                <span className="text-[11px] text-slate-400 mt-1">Đủ từ trong câu</span>
              </div>
            </div>
          </div>

          {/* Interactive Word Breakdown */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <h4 className="text-sm font-bold text-slate-800 dark:text-white flex items-center gap-1.5">
                <span>Phân tích từng từ (Bấm vào từ để xem âm vị & khẩu hình):</span>
              </h4>
              <div className="flex items-center gap-3 text-[11px] font-semibold text-slate-500">
                <span className="flex items-center gap-1">
                  <span className="w-2.5 h-2.5 rounded-full bg-emerald-500" /> Đúng chuẩn (≥85)
                </span>
                <span className="flex items-center gap-1">
                  <span className="w-2.5 h-2.5 rounded-full bg-amber-500" /> Cần chú ý (60-84)
                </span>
                <span className="flex items-center gap-1">
                  <span className="w-2.5 h-2.5 rounded-full bg-rose-500" /> Lệch âm (&lt;60)
                </span>
              </div>
            </div>

            {/* Word Chips */}
            <div className="flex flex-wrap gap-2.5 p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/40 border border-slate-200 dark:border-slate-800">
              {analysisResult.wordAnalysis?.map((wordItem, idx) => {
                const isSelected = selectedWord?.word === wordItem.word;
                const statusColor =
                  wordItem.status === 'correct'
                    ? 'border-emerald-500 bg-emerald-50 dark:bg-emerald-950/40 text-emerald-800 dark:text-emerald-300'
                    : wordItem.status === 'warning'
                    ? 'border-amber-500 bg-amber-50 dark:bg-amber-950/40 text-amber-800 dark:text-amber-300'
                    : 'border-rose-500 bg-rose-50 dark:bg-rose-950/40 text-rose-800 dark:text-rose-300';

                return (
                  <button
                    key={idx}
                    onClick={() => setSelectedWord(wordItem)}
                    className={`px-3 py-2 rounded-xl border-2 text-sm font-bold transition flex flex-col items-center gap-0.5 cursor-pointer shadow-sm hover:scale-105 active:scale-95 ${statusColor} ${
                      isSelected ? 'ring-2 ring-emerald-500 ring-offset-2 dark:ring-offset-slate-900 scale-105' : ''
                    }`}
                  >
                    <span>{wordItem.word}</span>
                    <span className="text-[10px] font-mono opacity-80">{wordItem.expectedIpa}</span>
                    <span className="text-[10px] font-bold mt-0.5">{wordItem.score}%</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Selected Word Detail Drawer */}
          {selectedWord && (
            <div className="p-4 rounded-2xl bg-gradient-to-r from-emerald-500/10 via-teal-500/10 to-transparent border border-emerald-500/20 space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="text-lg font-black text-slate-800 dark:text-white">
                    "{selectedWord.word}"
                  </span>
                  <span className="text-sm font-mono text-emerald-600 dark:text-emerald-400 font-bold">
                    {selectedWord.expectedIpa}
                  </span>
                  <button
                    onClick={() => playWordAudio(selectedWord.word)}
                    className="p-1.5 rounded-lg bg-emerald-600 text-white hover:bg-emerald-500 transition"
                    title="Nghe riêng từ này"
                  >
                    <Volume2 className="w-3.5 h-3.5" />
                  </button>
                </div>

                <div className="text-xs font-bold">
                  {selectedWord.status === 'correct' ? (
                    <span className="text-emerald-600 flex items-center gap-1">
                      <CheckCircle2 className="w-4 h-4" /> Phát âm chính xác
                    </span>
                  ) : selectedWord.status === 'warning' ? (
                    <span className="text-amber-600 flex items-center gap-1">
                      <AlertTriangle className="w-4 h-4" /> Có cảnh báo âm vị
                    </span>
                  ) : (
                    <span className="text-rose-600 flex items-center gap-1">
                      <XCircle className="w-4 h-4" /> Cần chỉnh sửa khẩu hình
                    </span>
                  )}
                </div>
              </div>

              {/* Phoneme breakdown pills */}
              {selectedWord.phonemes && selectedWord.phonemes.length > 0 && (
                <div className="flex items-center gap-1.5 flex-wrap">
                  <span className="text-xs font-semibold text-slate-500 mr-1">Các âm vị:</span>
                  {selectedWord.phonemes.map((p, pIdx) => (
                    <span
                      key={pIdx}
                      className={`px-2 py-0.5 rounded-lg font-mono text-xs font-bold border ${
                        p.status === 'correct'
                          ? 'bg-emerald-500/20 text-emerald-700 dark:text-emerald-300 border-emerald-500/30'
                          : p.status === 'warning'
                          ? 'bg-amber-500/20 text-amber-700 dark:text-amber-300 border-amber-500/30'
                          : 'bg-rose-500/20 text-rose-700 dark:text-rose-300 border-rose-500/30'
                      }`}
                      title={p.tip || ''}
                    >
                      {p.symbol}
                    </span>
                  ))}
                </div>
              )}

              <p className="text-xs text-slate-700 dark:text-slate-300 leading-relaxed">
                <strong>Nhận xét:</strong> {selectedWord.specificError}
              </p>
            </div>
          )}

          {/* AI Coach Vietnamese Feedback & Mouth Guide */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700/60 space-y-2">
              <h4 className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider flex items-center gap-1.5">
                <Sparkles className="w-3.5 h-3.5 text-emerald-500" />
                Nhận xét của Huấn luyện viên AI
              </h4>
              <p className="text-sm text-slate-700 dark:text-slate-200 leading-relaxed font-medium">
                {analysisResult.vietnameseSummary}
              </p>
            </div>

            <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700/60 space-y-2">
              <h4 className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider flex items-center gap-1.5">
                <BookOpen className="w-3.5 h-3.5 text-teal-500" />
                Hướng dẫn Khẩu hình & Vị trí Lưỡi
              </h4>
              <p className="text-sm text-slate-700 dark:text-slate-200 leading-relaxed">
                {analysisResult.tongueMouthAdvice}
              </p>
            </div>
          </div>

          {/* Recommended Next Drills */}
          {analysisResult.recommendedDrills?.length > 0 && (
            <div className="p-4 rounded-2xl bg-amber-500/5 dark:bg-amber-500/10 border border-amber-500/20">
              <h4 className="text-xs font-bold text-amber-700 dark:text-amber-400 uppercase tracking-wider mb-2">
                Bài tập cải thiện đề xuất ngay:
              </h4>
              <ul className="space-y-1.5">
                {analysisResult.recommendedDrills.map((drill, dIdx) => (
                  <li key={dIdx} className="text-xs text-slate-700 dark:text-slate-300 flex items-center gap-2">
                    <span className="w-1.5 h-1.5 rounded-full bg-amber-500 shrink-0" />
                    <span>{drill}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* Practice Again / Next Button */}
          <div className="flex items-center justify-end gap-3 pt-2">
            <button
              onClick={() => {
                setAnalysisResult(null);
                handleStartRecording();
              }}
              className="px-4 py-2.5 rounded-2xl border border-slate-300 dark:border-slate-700 font-semibold text-xs text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition flex items-center gap-1.5"
            >
              <RotateCcw className="w-3.5 h-3.5" />
              Luyện lại câu này
            </button>
            <button
              onClick={nextSentence}
              className="px-5 py-2.5 rounded-2xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs flex items-center gap-1.5 shadow-md shadow-emerald-600/20 transition active:scale-95"
            >
              Sang câu tiếp theo
              <ArrowRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      {/* Quick IPA reference guide drawer */}
      <div className="bg-white dark:bg-slate-900 rounded-3xl p-5 border border-slate-200 dark:border-slate-800">
        <h4 className="text-sm font-bold text-slate-800 dark:text-white mb-3 flex items-center gap-2">
          <BookOpen className="w-4 h-4 text-emerald-500" />
          Bảng tra cứu nhanh các âm vị người Việt hay phát âm sai
        </h4>
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3">
          {COMMON_PHONEMES_GUIDE.map((ph, idx) => (
            <div key={idx} className="p-3 rounded-2xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700/50">
              <div className="flex items-center justify-between mb-1">
                <span className="text-sm font-black font-mono text-emerald-600 dark:text-emerald-400">
                  {ph.symbol}
                </span>
                <span className="text-[10px] text-slate-400 italic">VD: {ph.example}</span>
              </div>
              <p className="text-[11px] text-slate-600 dark:text-slate-300 leading-snug">
                {ph.guide}
              </p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
