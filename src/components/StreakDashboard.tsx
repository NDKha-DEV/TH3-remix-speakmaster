import React, { useState } from 'react';
import { UserProfile, DailyStat } from '../types';
import {
  Flame,
  Award,
  Calendar,
  Clock,
  Target,
  Bell,
  BellRing,
  ShieldCheck,
  CheckCircle2,
  Sparkles,
  Zap,
  TrendingUp,
  Settings2,
  Volume2
} from 'lucide-react';
import confetti from 'canvas-confetti';

interface StreakDashboardProps {
  userProfile: UserProfile | null;
  dailyStats: DailyStat[];
  onUpdateGoals: (minutes: number, sentences: number) => Promise<void>;
  onUpdateReminder: (enabled: boolean, time: string) => Promise<void>;
}

export const StreakDashboard: React.FC<StreakDashboardProps> = ({
  userProfile,
  dailyStats,
  onUpdateGoals,
  onUpdateReminder
}) => {
  const [goalMinutes, setGoalMinutes] = useState<number>(userProfile?.dailyGoalMinutes || 15);
  const [goalSentences, setGoalSentences] = useState<number>(userProfile?.dailyGoalSentences || 10);
  const [reminderEnabled, setReminderEnabled] = useState<boolean>(userProfile?.reminderEnabled ?? true);
  const [reminderTime, setReminderTime] = useState<string>(userProfile?.reminderTime || '20:00');
  const [isSaving, setIsSaving] = useState(false);
  const [notificationTestMessage, setNotificationTestMessage] = useState<string | null>(null);

  const streakCount = userProfile?.streakCount || 1;
  const longestStreak = userProfile?.longestStreak || streakCount;

  // Find today's stat
  const now = new Date();
  const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
  const todayStat = dailyStats.find(s => s.date === todayStr);

  const minutesDone = todayStat?.minutesSpent || 0;
  const sentencesDone = todayStat?.sentencesPracticed || 0;
  const targetMinutes = userProfile?.dailyGoalMinutes || 15;
  const targetSentences = userProfile?.dailyGoalSentences || 10;

  const progressPercent = Math.min(
    100,
    Math.round(((minutesDone / targetMinutes) * 0.5 + (sentencesDone / targetSentences) * 0.5) * 100)
  );

  // Generate 7-day week array
  const weekDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  const dayOfWeekIndex = (now.getDay() + 6) % 7; // Monday = 0, Sunday = 6

  const handleSaveSettings = async () => {
    try {
      setIsSaving(true);
      await onUpdateGoals(goalMinutes, goalSentences);
      await onUpdateReminder(reminderEnabled, reminderTime);
      confetti({
        particleCount: 50,
        spread: 60,
        origin: { y: 0.7 }
      });
    } finally {
      setIsSaving(false);
    }
  };

  const testTriggerNotification = async () => {
    // Web Audio Chime sound
    try {
      const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(587.33, audioCtx.currentTime); // D5
      osc.frequency.exponentialRampToValueAtTime(880, audioCtx.currentTime + 0.2); // A5
      gain.gain.setValueAtTime(0.2, audioCtx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.6);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start();
      osc.stop(audioCtx.currentTime + 0.6);
    } catch (e) {
      // ignore
    }

    // Browser Notification API
    if ('Notification' in window) {
      if (Notification.permission === 'granted') {
        new Notification('🔥 SpeakMaster: Giữ vững chuỗi Streak!', {
          body: `Đã đến giờ luyện phát âm tiếng Anh (${reminderTime}). Chỉ cần 15 phút hôm nay để duy trì chuỗi ${streakCount} ngày!`,
          icon: '/favicon.ico'
        });
        setNotificationTestMessage('Đã phát âm thanh & hiển thị thông báo trình duyệt thành công!');
      } else if (Notification.permission !== 'denied') {
        const perm = await Notification.requestPermission();
        if (perm === 'granted') {
          new Notification('🔥 SpeakMaster: Nhắc nhở kỷ luật học tập!', {
            body: `Tuyệt vời! Bạn sẽ nhận được nhắc nhở lúc ${reminderTime} hằng ngày để không bỏ lỡ buổi học nào.`,
          });
          setNotificationTestMessage('Đã kích hoạt quyền thông báo!');
        } else {
          setNotificationTestMessage('Đã phát chuông nhắc nhở trong ứng dụng (quyền thông báo hệ thống bị từ chối).');
        }
      } else {
        setNotificationTestMessage('Đã phát chuông nhắc nhở trong ứng dụng.');
      }
    } else {
      setNotificationTestMessage('Đã phát chuông nhắc nhở trong ứng dụng.');
    }

    setTimeout(() => setNotificationTestMessage(null), 5000);
  };

  return (
    <div className="space-y-6 pb-20">
      {/* Top Banner: Streak Hero Card */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-amber-500 via-orange-500 to-rose-600 text-white p-6 shadow-2xl">
        <div className="absolute top-0 right-0 -mt-6 -mr-6 w-44 h-44 bg-white/10 rounded-full blur-2xl" />
        <div className="relative z-10 flex flex-col md:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-5 text-center md:text-left">
            <div className="relative flex items-center justify-center">
              <div className="w-20 h-20 rounded-3xl bg-white/20 backdrop-blur-md flex items-center justify-center shadow-inner border border-white/30 animate-bounce">
                <Flame className="w-12 h-12 text-amber-200 fill-amber-300 drop-shadow-lg" />
              </div>
              <span className="absolute -bottom-2 px-2.5 py-0.5 rounded-full bg-rose-900/80 text-[10px] font-black uppercase tracking-wider text-amber-200 border border-amber-300/40">
                ACTIVE STREAK
              </span>
            </div>

            <div>
              <div className="flex items-baseline gap-2 justify-center md:justify-start">
                <span className="text-5xl font-black tracking-tight">{streakCount}</span>
                <span className="text-2xl font-bold text-amber-100">Ngày liên tiếp!</span>
              </div>
              <p className="text-sm text-amber-100/90 mt-1">
                Kỷ lục cao nhất của bạn: <strong className="text-white">{longestStreak} ngày</strong>. Hãy tiếp tục duy trì!
              </p>
            </div>
          </div>

          <div className="flex items-center gap-3 bg-black/20 backdrop-blur-md p-3 rounded-2xl border border-white/20">
            <ShieldCheck className="w-6 h-6 text-emerald-300 shrink-0" />
            <div className="text-xs">
              <p className="font-bold text-white">Khiên bảo vệ Chuỗi (Streak Freeze)</p>
              <p className="text-amber-200/80 text-[11px]">Đang sẵn sàng 1 lần bảo lưu nếu bận đột xuất</p>
            </div>
          </div>
        </div>

        {/* 7-Day Weekly Streak Tracker */}
        <div className="mt-6 pt-5 border-t border-white/20">
          <p className="text-xs font-bold uppercase tracking-wider text-amber-100 mb-3 flex items-center gap-1.5">
            <Calendar className="w-4 h-4" />
            Tiến độ tuần này (Thứ 2 - Chủ Nhật)
          </p>

          <div className="grid grid-cols-7 gap-2">
            {weekDays.map((day, idx) => {
              const isPast = idx < dayOfWeekIndex;
              const isToday = idx === dayOfWeekIndex;
              const isFuture = idx > dayOfWeekIndex;
              const completed = isPast || (isToday && minutesDone > 0);

              return (
                <div
                  key={day}
                  className={`flex flex-col items-center py-2.5 px-1 rounded-2xl border transition ${
                    isToday
                      ? 'bg-white text-orange-600 font-bold border-white shadow-lg scale-105'
                      : completed
                      ? 'bg-white/25 border-white/40 text-white'
                      : 'bg-black/15 border-white/10 text-white/50'
                  }`}
                >
                  <span className="text-xs font-semibold">{day}</span>
                  <div className="mt-1.5">
                    {completed ? (
                      <Flame className={`w-5 h-5 ${isToday ? 'text-orange-500 fill-orange-500' : 'text-amber-200 fill-amber-200'}`} />
                    ) : (
                      <div className="w-5 h-5 rounded-full border-2 border-white/30 flex items-center justify-center text-[10px]">
                        •
                      </div>
                    )}
                  </div>
                  <span className="text-[10px] mt-1 font-mono">
                    {isToday ? 'Hôm nay' : completed ? '✓' : '-'}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Daily Target Progress Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Today's Goal Card */}
        <div className="bg-white dark:bg-slate-900 rounded-3xl p-6 shadow-xl border border-slate-200 dark:border-slate-800 space-y-4">
          <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800">
            <div className="flex items-center gap-2.5">
              <div className="w-9 h-9 rounded-2xl bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 flex items-center justify-center font-bold">
                <Target className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-slate-800 dark:text-white text-base">
                  Mục tiêu luyện tập hôm nay
                </h3>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  Hoàn thành để giữ vững lửa chuỗi streak
                </p>
              </div>
            </div>

            <span className={`px-2.5 py-1 rounded-full text-xs font-bold ${
              progressPercent >= 100
                ? 'bg-emerald-500/15 text-emerald-600 dark:text-emerald-400'
                : 'bg-amber-500/15 text-amber-600 dark:text-amber-400'
            }`}>
              {progressPercent >= 100 ? 'Đã đạt mục tiêu 🎉' : `${progressPercent}%`}
            </span>
          </div>

          <div className="space-y-4">
            {/* Time metric */}
            <div>
              <div className="flex justify-between text-xs font-semibold mb-1">
                <span className="text-slate-600 dark:text-slate-300 flex items-center gap-1">
                  <Clock className="w-3.5 h-3.5 text-emerald-500" /> Thời gian luyện phát âm
                </span>
                <span className="font-bold text-slate-800 dark:text-white">
                  {minutesDone} / {targetMinutes} phút
                </span>
              </div>
              <div className="w-full bg-slate-100 dark:bg-slate-800 h-2.5 rounded-full overflow-hidden">
                <div
                  className="bg-gradient-to-r from-emerald-500 to-teal-500 h-full rounded-full transition-all duration-700"
                  style={{ width: `${Math.min(100, (minutesDone / targetMinutes) * 100)}%` }}
                />
              </div>
            </div>

            {/* Sentences metric */}
            <div>
              <div className="flex justify-between text-xs font-semibold mb-1">
                <span className="text-slate-600 dark:text-slate-300 flex items-center gap-1">
                  <Sparkles className="w-3.5 h-3.5 text-teal-500" /> Số câu đã hoàn thành
                </span>
                <span className="font-bold text-slate-800 dark:text-white">
                  {sentencesDone} / {targetSentences} câu
                </span>
              </div>
              <div className="w-full bg-slate-100 dark:bg-slate-800 h-2.5 rounded-full overflow-hidden">
                <div
                  className="bg-gradient-to-r from-teal-500 to-cyan-500 h-full rounded-full transition-all duration-700"
                  style={{ width: `${Math.min(100, (sentencesDone / targetSentences) * 100)}%` }}
                />
              </div>
            </div>

            <div className="p-3.5 rounded-2xl bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800/40 text-xs text-emerald-800 dark:text-emerald-300 flex items-center gap-3">
              <Zap className="w-5 h-5 text-emerald-600 shrink-0" />
              <span>
                {progressPercent >= 100
                  ? 'Tuyệt vời! Bạn đã hoàn thành xuất sắc chỉ tiêu hôm nay và tích lũy thêm XP!'
                  : `Bạn chỉ cần luyện thêm ${Math.max(0, targetSentences - sentencesDone)} câu để đạt mốc kỷ luật!`}
              </span>
            </div>
          </div>
        </div>

        {/* Practice Reminder System Card */}
        <div className="bg-white dark:bg-slate-900 rounded-3xl p-6 shadow-xl border border-slate-200 dark:border-slate-800 space-y-4">
          <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800">
            <div className="flex items-center gap-2.5">
              <div className="w-9 h-9 rounded-2xl bg-amber-500/10 text-amber-600 dark:text-amber-400 flex items-center justify-center font-bold">
                <BellRing className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-slate-800 dark:text-white text-base">
                  Nhắc nhở Kỷ luật Hằng ngày
                </h3>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  Thông báo tự động để không bao giờ quên
                </p>
              </div>
            </div>

            {/* Switch toggle */}
            <label className="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                checked={reminderEnabled}
                onChange={(e) => setReminderEnabled(e.target.checked)}
                className="sr-only peer"
              />
              <div className="w-11 h-6 bg-slate-200 peer-focus:outline-none rounded-full peer dark:bg-slate-700 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-600" />
            </label>
          </div>

          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <label className="text-xs font-semibold text-slate-700 dark:text-slate-300">
                Thời gian nhắc nhở mỗi ngày:
              </label>
              <input
                type="time"
                value={reminderTime}
                onChange={(e) => setReminderTime(e.target.value)}
                disabled={!reminderEnabled}
                className="px-3 py-1.5 rounded-xl border border-slate-300 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 text-slate-800 dark:text-white text-sm font-bold disabled:opacity-50"
              />
            </div>

            <div className="flex gap-2">
              <button
                onClick={testTriggerNotification}
                className="flex-1 py-2.5 px-3 rounded-2xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 text-xs font-semibold flex items-center justify-center gap-1.5 transition"
              >
                <Volume2 className="w-4 h-4 text-amber-500" />
                Thử nghiệm chuông nhắc nhở
              </button>
            </div>

            {notificationTestMessage && (
              <div className="p-2.5 rounded-xl bg-teal-500/10 border border-teal-500/20 text-teal-700 dark:text-teal-300 text-xs">
                {notificationTestMessage}
              </div>
            )}

            <p className="text-[11px] text-slate-400">
              * Hệ thống hỗ trợ cả âm thanh báo thức trong ứng dụng lẫn Web Push Notification của trình duyệt.
            </p>
          </div>
        </div>
      </div>

      {/* Goal Customization Panel */}
      <div className="bg-white dark:bg-slate-900 rounded-3xl p-6 shadow-xl border border-slate-200 dark:border-slate-800 space-y-4">
        <div className="flex items-center gap-2 pb-2 border-b border-slate-100 dark:border-slate-800">
          <Settings2 className="w-5 h-5 text-emerald-500" />
          <h3 className="font-bold text-slate-800 dark:text-white text-base">
            Tùy chỉnh Mục tiêu & Kỷ luật Học tập
          </h3>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label className="text-xs font-bold text-slate-700 dark:text-slate-300 mb-2 block">
              Mục tiêu thời gian mỗi ngày: <strong className="text-emerald-600 dark:text-emerald-400">{goalMinutes} phút</strong>
            </label>
            <div className="flex items-center gap-2">
              {[5, 10, 15, 20, 30].map((mins) => (
                <button
                  key={mins}
                  onClick={() => setGoalMinutes(mins)}
                  className={`flex-1 py-2 rounded-xl text-xs font-bold border transition ${
                    goalMinutes === mins
                      ? 'bg-emerald-600 text-white border-emerald-600 shadow-md shadow-emerald-600/20'
                      : 'bg-slate-50 dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-100'
                  }`}
                >
                  {mins}p
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="text-xs font-bold text-slate-700 dark:text-slate-300 mb-2 block">
              Mục tiêu số câu/từ phát âm: <strong className="text-teal-600 dark:text-teal-400">{goalSentences} câu</strong>
            </label>
            <div className="flex items-center gap-2">
              {[5, 10, 15, 20, 25].map((cnt) => (
                <button
                  key={cnt}
                  onClick={() => setGoalSentences(cnt)}
                  className={`flex-1 py-2 rounded-xl text-xs font-bold border transition ${
                    goalSentences === cnt
                      ? 'bg-teal-600 text-white border-teal-600 shadow-md shadow-teal-600/20'
                      : 'bg-slate-50 dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-100'
                  }`}
                >
                  {cnt} câu
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="flex justify-end pt-3">
          <button
            onClick={handleSaveSettings}
            disabled={isSaving}
            className="px-6 py-2.5 rounded-2xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs flex items-center gap-2 shadow-lg shadow-emerald-600/20 transition active:scale-95"
          >
            {isSaving ? 'Đang lưu vào Firestore...' : 'Lưu cài đặt kỷ luật'}
          </button>
        </div>
      </div>
    </div>
  );
};
