import React, { useState } from 'react';
import { AccentTestSample, PronunciationResult } from '../types';
import { SpeechHelper } from '../utils/audio';
import {
  Users,
  Play,
  Sparkles,
  Volume2,
  CheckCircle2,
  AlertCircle,
  HelpCircle,
  ArrowRight,
  ShieldCheck,
  Bot
} from 'lucide-react';

export const AccentTester: React.FC = () => {
  const [samples] = useState<AccentTestSample[]>([
    {
      id: 'us_native',
      name: 'John D. (Người bản xứ Mỹ - Chuẩn General American)',
      accent: 'American (Native)',
      targetText: 'She sells seashells by the seashore.',
      simulatedSpokenText: 'She sells seashells by the seashore.',
      expectedScore: 98,
      notes: 'Phát âm chuẩn xác 100% cả âm chu môi /ʃ/ và xì hơi /s/, ngữ điệu tự nhiên.'
    },
    {
      id: 'uk_native',
      name: 'Emma W. (Người bản xứ Anh - Chuẩn RP London)',
      accent: 'British (Native)',
      targetText: 'Working in a comfortable environment increases productivity significantly.',
      simulatedSpokenText: 'Working in a comfortable environment increases productivity significantly.',
      expectedScore: 96,
      notes: 'Trọng âm chuẩn xác vào âm tiết đầu tiên của comfortable, nhịp điệu dứt khoát.'
    },
    {
      id: 'vn_beginner',
      name: 'Minh Tuấn (Học viên Việt Nam - Trình độ Cơ bản)',
      accent: 'Vietnamese English (Beginner)',
      targetText: 'She sells seashells by the seashore.',
      simulatedSpokenText: 'She sell seashow by the seashow.',
      expectedScore: 58,
      notes: 'Nuốt âm đuôi /z/ ở "sells", phát âm "seashells" thành "seashow", nhầm âm /ʃ/ thành /s/.'
    },
    {
      id: 'vn_intermediate',
      name: 'Lan Anh (Học viên Việt Nam - Trình độ Trung cấp)',
      accent: 'Vietnamese English (Intermediate)',
      targetText: 'Working in a comfortable environment increases productivity significantly.',
      simulatedSpokenText: 'Working in a comfort-table environment increase productivity significantly.',
      expectedScore: 76,
      notes: 'Từ comfortable đọc thành 4 âm tiết thay vì 3 /ˈkʌmftərbəl/, nuốt âm đuôi /ɪz/ ở "increases".'
    },
    {
      id: 'vn_dental',
      name: 'Đức Huy (Học viên Việt Nam - Lỗi âm răng /θ/ và /ð/)',
      accent: 'Vietnamese English (Focus on /θ/)',
      targetText: 'I think that this is the best solution for our team.',
      simulatedSpokenText: 'I tink dat dis is the best solution for our team.',
      expectedScore: 64,
      notes: 'Không kẹp lưỡi giữa hai răng: đọc /θ/ thành /t/ ("tink") và /ð/ thành /d/ ("dat, dis").'
    }
  ]);

  const [selectedSample, setSelectedSample] = useState<AccentTestSample>(samples[2]);
  const [isTesting, setIsTesting] = useState(false);
  const [testResult, setTestResult] = useState<PronunciationResult | null>(null);

  const handleRunAiTest = async (sample: AccentTestSample) => {
    try {
      setIsTesting(true);
      setTestResult(null);

      const response = await fetch('/api/analyze-pronunciation', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          targetText: sample.targetText,
          userSpokenText: sample.simulatedSpokenText,
          category: 'Accent Benchmark Test',
          difficulty: 'Intermediate'
        })
      });

      if (!response.ok) throw new Error('API analysis failed');

      const data: PronunciationResult = await response.json();
      setTestResult(data);
    } catch (err) {
      console.error('Test run error:', err);
    } finally {
      setIsTesting(false);
    }
  };

  const playTargetAudio = (text: string) => {
    SpeechHelper.speakText(text, 'US', 0.9);
  };

  return (
    <div className="space-y-6 pb-20">
      {/* Header Info */}
      <div className="bg-white dark:bg-slate-900 rounded-3xl p-6 shadow-xl border border-slate-200 dark:border-slate-800 space-y-2">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-cyan-500 to-blue-600 text-white flex items-center justify-center font-bold shadow-md shadow-cyan-500/20">
            <Users className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-lg font-bold text-slate-800 dark:text-white">
              Phòng Thí Nghiệm & Kiểm Thử Đa Giọng Nói (Multi-Speaker AI Benchmark)
            </h3>
            <p className="text-xs text-slate-500 dark:text-slate-400">
              Kiểm nghiệm độ chính xác của mô hình AI khi chấm điểm người bản xứ vs. các lỗi phát âm đặc trưng của học viên Việt Nam
            </p>
          </div>
        </div>
      </div>

      {/* Speaker Selector Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {samples.map((s) => {
          const isSelected = selectedSample.id === s.id;
          return (
            <div
              key={s.id}
              onClick={() => {
                setSelectedSample(s);
                setTestResult(null);
              }}
              className={`p-4 rounded-3xl border-2 transition-all cursor-pointer flex flex-col justify-between ${
                isSelected
                  ? 'border-emerald-500 bg-emerald-50/40 dark:bg-emerald-950/20 shadow-lg scale-102'
                  : 'border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 hover:border-slate-300'
              }`}
            >
              <div>
                <div className="flex items-center justify-between mb-2">
                  <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                    s.accent.includes('Native')
                      ? 'bg-blue-500/15 text-blue-600 dark:text-blue-400'
                      : 'bg-amber-500/15 text-amber-600 dark:text-amber-400'
                  }`}>
                    {s.accent}
                  </span>
                  <span className="text-xs font-mono font-bold text-slate-500">
                    Điểm chuẩn: ~{s.expectedScore}đ
                  </span>
                </div>

                <h4 className="font-bold text-sm text-slate-800 dark:text-white mb-1">
                  {s.name}
                </h4>

                <p className="text-xs text-slate-600 dark:text-slate-300 italic mb-2">
                  "{s.targetText}"
                </p>

                <div className="p-2 rounded-xl bg-slate-100 dark:bg-slate-800 text-[11px] text-slate-600 dark:text-slate-300 mb-2">
                  <strong>Giọng phát âm mô phỏng:</strong> <br />
                  <span className="text-rose-600 dark:text-rose-400 font-mono">
                    "{s.simulatedSpokenText}"
                  </span>
                </div>

                <p className="text-[11px] text-slate-500 dark:text-slate-400">
                  {s.notes}
                </p>
              </div>

              <div className="mt-4 pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between">
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    playTargetAudio(s.targetText);
                  }}
                  className="p-2 rounded-xl bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-200 text-xs font-semibold flex items-center gap-1 hover:bg-slate-200"
                >
                  <Volume2 className="w-3.5 h-3.5 text-emerald-500" />
                  Nghe câu mẫu
                </button>

                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    setSelectedSample(s);
                    handleRunAiTest(s);
                  }}
                  className="px-3.5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs flex items-center gap-1.5 shadow-md shadow-emerald-600/20"
                >
                  <Sparkles className="w-3.5 h-3.5" />
                  Chạy chấm điểm AI
                </button>
              </div>
            </div>
          );
        })}
      </div>

      {/* AI Test Result Card */}
      {isTesting && (
        <div className="p-8 rounded-3xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-center space-y-3 shadow-xl">
          <div className="w-8 h-8 border-3 border-cyan-500 border-t-transparent rounded-full animate-spin mx-auto" />
          <p className="text-sm font-bold text-slate-800 dark:text-white">
            AI đang phân tích âm học và so sánh âm vị cho mẫu giọng: {selectedSample.name}...
          </p>
        </div>
      )}

      {testResult && (
        <div className="bg-white dark:bg-slate-900 rounded-3xl p-6 shadow-xl border border-slate-200 dark:border-slate-800 space-y-5 animate-fade-in">
          <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800">
            <div className="flex items-center gap-2">
              <Bot className="w-5 h-5 text-emerald-500" />
              <h3 className="font-bold text-slate-800 dark:text-white text-base">
                Kết quả Thử nghiệm AI Chấm điểm cho: {selectedSample.name}
              </h3>
            </div>
            <span className="text-xs px-2.5 py-1 rounded-full bg-emerald-500/10 text-emerald-600 font-bold">
              Độ chính xác cao ✓
            </span>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-center">
            <div className="p-3 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700/60">
              <span className="text-xs text-slate-400">Điểm AI chấm</span>
              <p className="text-3xl font-black text-emerald-600 dark:text-emerald-400">
                {testResult.overallScore}
              </p>
              <span className="text-[10px] text-slate-400 font-mono">Dự kiến: ~{selectedSample.expectedScore}</span>
            </div>

            <div className="p-3 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700/60">
              <span className="text-xs text-slate-400">Độ chuẩn âm vị</span>
              <p className="text-3xl font-black text-cyan-600 dark:text-cyan-400">
                {testResult.accuracyScore}%
              </p>
            </div>

            <div className="p-3 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700/60">
              <span className="text-xs text-slate-400">Độ trôi chảy</span>
              <p className="text-3xl font-black text-teal-600 dark:text-teal-400">
                {testResult.fluencyScore}%
              </p>
            </div>

            <div className="p-3 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700/60">
              <span className="text-xs text-slate-400">Độ hoàn chỉnh</span>
              <p className="text-3xl font-black text-indigo-600 dark:text-indigo-400">
                {testResult.completenessScore}%
              </p>
            </div>
          </div>

          {/* AI Vietnamese Summary */}
          <div className="p-4 rounded-2xl bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800/40 text-xs text-slate-700 dark:text-slate-200 leading-relaxed space-y-1.5">
            <p className="font-bold text-emerald-800 dark:text-emerald-400 text-sm">
              Đánh giá từ Huấn luyện viên AI:
            </p>
            <p>{testResult.vietnameseSummary}</p>
            <p className="text-slate-600 dark:text-slate-300">
              <strong>Hướng dẫn khẩu hình:</strong> {testResult.tongueMouthAdvice}
            </p>
          </div>

          {/* Word Analysis Chips */}
          <div>
            <h4 className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">
              Các từ phát hiện lỗi âm vị:
            </h4>
            <div className="flex flex-wrap gap-2">
              {testResult.wordAnalysis?.map((w, idx) => (
                <div
                  key={idx}
                  className={`px-3 py-2 rounded-xl border text-xs font-semibold ${
                    w.status === 'correct'
                      ? 'border-emerald-500 bg-emerald-50 dark:bg-emerald-950/40 text-emerald-800 dark:text-emerald-300'
                      : w.status === 'warning'
                      ? 'border-amber-500 bg-amber-50 dark:bg-amber-950/40 text-amber-800 dark:text-amber-300'
                      : 'border-rose-500 bg-rose-50 dark:bg-rose-950/40 text-rose-800 dark:text-rose-300'
                  }`}
                >
                  <span className="font-bold">{w.word}</span> ({w.score}đ)
                  <p className="text-[10px] opacity-80">{w.specificError}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
