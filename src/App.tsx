import React, { useState, useEffect } from 'react';
import { User, onAuthStateChanged } from 'firebase/auth';
import { auth } from './firebase/config';
import {
  getOrCreateUserProfile,
  updateUserProfile,
  recordPracticeSession,
  fetchPracticeHistory,
  fetchRecentDailyStats
} from './firebase/service';
import { syncWebPushToken } from './firebase/messaging';
import { UserProfile, PracticeRecord, DailyStat, PronunciationResult, LessonSentence } from './types';
import { Navbar } from './components/Navbar';
import { PronunciationStudio } from './components/PronunciationStudio';
import { StreakDashboard } from './components/StreakDashboard';
import { AnalyticsView } from './components/AnalyticsView';
import { AccentTester } from './components/AccentTester';
import { AuthModal } from './components/AuthModal';
import {
  Mic,
  Flame,
  BarChart3,
  Users,
  UserCheck,
  Wifi,
  BatteryCharging
} from 'lucide-react';

export default function App() {
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [userProfile, setUserProfile] = useState<UserProfile | null>(null);
  const [history, setHistory] = useState<PracticeRecord[]>([]);
  const [dailyStats, setDailyStats] = useState<DailyStat[]>([]);
  const [loading, setLoading] = useState<boolean>(true);

  // Navigation tab
  const [activeTab, setActiveTab] = useState<'practice' | 'streak' | 'analytics' | 'benchmark'>('practice');

  // UI Modals
  const [isAuthModalOpen, setIsAuthModalOpen] = useState<boolean>(false);
  const [isMobileFrame, setIsMobileFrame] = useState<boolean>(false);

  // Initialize Firebase Auth listener
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (user) {
        setCurrentUser(user);
        try {
          const profile = await getOrCreateUserProfile(user);
          setUserProfile(profile);
          const userHistory = await fetchPracticeHistory(user.uid);
          setHistory(userHistory);
          const stats = await fetchRecentDailyStats(user.uid);
          setDailyStats(stats);
          // Refresh the push token silently if permission was granted earlier.
          if (profile.reminderEnabled) {
            void syncWebPushToken(user.uid, { prompt: false });
          }
        } catch (err) {
          console.warn('Error loading user data from Firestore:', err);
        }
      } else {
        setCurrentUser(null);
        initDemoProfile();
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const initDemoProfile = () => {
    const today = new Date().toISOString().substring(0, 10);
    const demoProfile: UserProfile = {
      id: 'student_demo_101',
      email: 'sinhvien@speakmaster.edu.vn',
      displayName: 'Sinh viên SpeakMaster',
      photoURL: '',
      dailyGoalMinutes: 15,
      dailyGoalSentences: 10,
      streakCount: 5,
      longestStreak: 12,
      lastActiveDate: today,
      totalXp: 480,
      level: 1,
      reminderTime: '20:00',
      reminderEnabled: true,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    setUserProfile(demoProfile);

    setHistory([
      {
        id: 'rec_init_1',
        userId: 'student_demo_101',
        targetText: 'She sells seashells by the seashore.',
        category: 'TongueTwister',
        difficulty: 'Intermediate',
        overallScore: 92,
        accuracyScore: 90,
        fluencyScore: 94,
        completenessScore: 100,
        expectedIpa: '/ʃiː sɛlz ˈsiːˌʃɛlz baɪ ðə ˈsiːˌʃɔːr/',
        feedback: 'Phát âm rất rõ ràng, phân biệt tốt âm /ʃ/ và /s/.',
        createdAt: new Date(Date.now() - 3600000 * 2).toISOString()
      },
      {
        id: 'rec_init_2',
        userId: 'student_demo_101',
        targetText: 'I think that this is the best solution for our team.',
        category: 'Daily',
        difficulty: 'Beginner',
        overallScore: 84,
        accuracyScore: 82,
        fluencyScore: 86,
        completenessScore: 100,
        expectedIpa: '/aɪ θɪŋk ðæt ðɪs ɪz ðə bɛst səˈluːʃən/',
        feedback: 'Cần chú ý đặt đầu lưỡi giữa hai răng cho âm /θ/ ở "think".',
        createdAt: new Date(Date.now() - 3600000 * 24).toISOString()
      }
    ]);

    setDailyStats([
      {
        id: today,
        userId: 'student_demo_101',
        date: today,
        minutesSpent: 10,
        sentencesPracticed: 4,
        averageScore: 88,
        goalAchieved: false,
        updatedAt: new Date().toISOString()
      }
    ]);
  };

  // Callback when a practice session is recorded
  const handleRecordPractice = async (
    minutes: number,
    score: number,
    result: PronunciationResult,
    sentence: LessonSentence
  ) => {
    if (!userProfile) return;

    const newRecord: PracticeRecord = {
      id: `rec_${Date.now()}`,
      userId: userProfile.id,
      targetText: sentence.text,
      category: sentence.category,
      difficulty: sentence.difficulty,
      overallScore: result.overallScore,
      accuracyScore: result.accuracyScore,
      fluencyScore: result.fluencyScore,
      completenessScore: result.completenessScore,
      expectedIpa: result.expectedIpa,
      feedback: result.vietnameseSummary,
      tongueMouthAdvice: result.tongueMouthAdvice,
      createdAt: new Date().toISOString()
    };

    setHistory((prev) => [newRecord, ...prev]);

    if (currentUser) {
      try {
        const { record, updatedProfile, todayStat } = await recordPracticeSession(
          currentUser.uid,
          userProfile,
          {
            targetText: newRecord.targetText,
            category: newRecord.category,
            difficulty: newRecord.difficulty,
            overallScore: newRecord.overallScore,
            accuracyScore: newRecord.accuracyScore,
            fluencyScore: newRecord.fluencyScore,
            completenessScore: newRecord.completenessScore,
            expectedIpa: newRecord.expectedIpa,
            feedback: newRecord.feedback,
            tongueMouthAdvice: newRecord.tongueMouthAdvice
          },
          minutes,
          score
        );
        setHistory((prev) => prev.map((r) => (r.id === newRecord.id ? record : r)));
        setUserProfile(updatedProfile);
        setDailyStats((prev) => {
          const idx = prev.findIndex((s) => s.date === todayStat.date);
          if (idx >= 0) {
            const copy = [...prev];
            copy[idx] = todayStat;
            return copy;
          }
          // Stats are kept oldest-first (see fetchRecentDailyStats).
          return [...prev, todayStat].slice(-7);
        });
      } catch (err) {
        console.warn('Could not save practice to Firestore:', err);
      }
    } else {
      const newXp = userProfile.totalXp + Math.round(score * 1.5) + 30;
      setUserProfile({
        ...userProfile,
        totalXp: newXp,
        level: Math.floor(newXp / 500) + 1,
        streakCount: userProfile.streakCount,
        lastActiveDate: new Date().toISOString().substring(0, 10)
      });
    }
  };

  const handleUpdateGoals = async (minutes: number, sentences: number) => {
    if (!userProfile) return;
    const updated = { ...userProfile, dailyGoalMinutes: minutes, dailyGoalSentences: sentences };
    setUserProfile(updated);
    if (currentUser) {
      await updateUserProfile(currentUser.uid, { dailyGoalMinutes: minutes, dailyGoalSentences: sentences });
    }
  };

  const handleUpdateReminder = async (enabled: boolean, time: string) => {
    if (!userProfile) return;
    const updated = { ...userProfile, reminderEnabled: enabled, reminderTime: time };
    setUserProfile(updated);
    if (currentUser) {
      await updateUserProfile(currentUser.uid, { reminderEnabled: enabled, reminderTime: time });
      if (enabled) {
        // Called from the "save settings" click, so the permission prompt is allowed here.
        const status = await syncWebPushToken(currentUser.uid, { prompt: true });
        if (status !== 'enabled') {
          console.info(`Web push reminder not active on this browser: ${status}`);
        }
      }
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 dark:bg-slate-950 text-slate-800 dark:text-slate-100 flex flex-col font-sans transition-colors">
      {/* Top Navbar */}
      <Navbar
        currentUser={currentUser}
        userProfile={userProfile}
        onOpenAuth={() => setIsAuthModalOpen(true)}
        isMobileFrame={isMobileFrame}
        onToggleMobileFrame={() => setIsMobileFrame(!isMobileFrame)}
      />

      {/* Main Container */}
      <main className="flex-1 max-w-5xl w-full mx-auto p-4 md:p-6 flex flex-col items-center">
        {isMobileFrame ? (
          <div className="relative w-full max-w-[410px] h-[820px] bg-slate-900 rounded-[50px] p-3 shadow-2xl border-4 border-slate-700/80 ring-1 ring-slate-800 flex flex-col overflow-hidden">
            <div className="h-6 w-full flex items-center justify-between px-6 pt-1 text-[11px] font-mono text-slate-400 select-none z-30">
              <span>9:41</span>
              <div className="w-24 h-4 bg-black rounded-full" />
              <div className="flex items-center gap-1.5">
                <Wifi className="w-3 h-3" />
                <BatteryCharging className="w-3.5 h-3.5" />
              </div>
            </div>

            <div className="flex-1 bg-slate-50 dark:bg-slate-950 rounded-[38px] overflow-y-auto p-4 relative no-scrollbar">
              {activeTab === 'practice' && (
                <PronunciationStudio
                  userProfile={userProfile}
                  onRecordPractice={handleRecordPractice}
                />
              )}
              {activeTab === 'streak' && (
                <StreakDashboard
                  userProfile={userProfile}
                  dailyStats={dailyStats}
                  onUpdateGoals={handleUpdateGoals}
                  onUpdateReminder={handleUpdateReminder}
                />
              )}
              {activeTab === 'analytics' && (
                <AnalyticsView
                  userProfile={userProfile}
                  history={history}
                  dailyStats={dailyStats}
                />
              )}
              {activeTab === 'benchmark' && <AccentTester />}
            </div>

            <div className="h-4 w-full flex items-center justify-center pt-1">
              <div className="w-32 h-1 bg-slate-600 rounded-full" />
            </div>
          </div>
        ) : (
          <div className="w-full">
            {activeTab === 'practice' && (
              <PronunciationStudio
                userProfile={userProfile}
                onRecordPractice={handleRecordPractice}
              />
            )}
            {activeTab === 'streak' && (
              <StreakDashboard
                userProfile={userProfile}
                dailyStats={dailyStats}
                onUpdateGoals={handleUpdateGoals}
                onUpdateReminder={handleUpdateReminder}
              />
            )}
            {activeTab === 'analytics' && (
              <AnalyticsView
                userProfile={userProfile}
                history={history}
                dailyStats={dailyStats}
              />
            )}
            {activeTab === 'benchmark' && <AccentTester />}
          </div>
        )}
      </main>

      {/* Bottom Navigation Bar */}
      <nav className="fixed bottom-0 left-0 right-0 z-40 bg-white/90 dark:bg-slate-900/90 backdrop-blur-lg border-t border-slate-200 dark:border-slate-800 shadow-xl transition-colors">
        <div className="max-w-lg mx-auto flex items-center justify-around py-2 px-3">
          <button
            onClick={() => setActiveTab('practice')}
            className={`flex flex-col items-center gap-1 py-1 px-3 rounded-2xl transition-all ${
              activeTab === 'practice'
                ? 'text-emerald-600 dark:text-emerald-400 font-bold scale-105'
                : 'text-slate-400 hover:text-slate-600 dark:hover:text-slate-300'
            }`}
          >
            <div className={`p-1 rounded-xl transition ${activeTab === 'practice' ? 'bg-emerald-500/15' : ''}`}>
              <Mic className="w-5 h-5" />
            </div>
            <span className="text-[11px]">Luyện phát âm</span>
          </button>

          <button
            onClick={() => setActiveTab('streak')}
            className={`flex flex-col items-center gap-1 py-1 px-3 rounded-2xl transition-all ${
              activeTab === 'streak'
                ? 'text-amber-500 font-bold scale-105'
                : 'text-slate-400 hover:text-slate-600 dark:hover:text-slate-300'
            }`}
          >
            <div className={`p-1 rounded-xl transition ${activeTab === 'streak' ? 'bg-amber-500/15' : ''}`}>
              <Flame className="w-5 h-5 fill-current" />
            </div>
            <span className="text-[11px]">Chuỗi Streak</span>
          </button>

          <button
            onClick={() => setActiveTab('analytics')}
            className={`flex flex-col items-center gap-1 py-1 px-3 rounded-2xl transition-all ${
              activeTab === 'analytics'
                ? 'text-teal-600 dark:text-teal-400 font-bold scale-105'
                : 'text-slate-400 hover:text-slate-600 dark:hover:text-slate-300'
            }`}
          >
            <div className={`p-1 rounded-xl transition ${activeTab === 'analytics' ? 'bg-teal-500/15' : ''}`}>
              <BarChart3 className="w-5 h-5" />
            </div>
            <span className="text-[11px]">Tiến độ & Điểm</span>
          </button>

          <button
            onClick={() => setActiveTab('benchmark')}
            className={`flex flex-col items-center gap-1 py-1 px-3 rounded-2xl transition-all ${
              activeTab === 'benchmark'
                ? 'text-cyan-600 dark:text-cyan-400 font-bold scale-105'
                : 'text-slate-400 hover:text-slate-600 dark:hover:text-slate-300'
            }`}
          >
            <div className={`p-1 rounded-xl transition ${activeTab === 'benchmark' ? 'bg-cyan-500/15' : ''}`}>
              <Users className="w-5 h-5" />
            </div>
            <span className="text-[11px]">Thử nghiệm giọng</span>
          </button>

          <button
            onClick={() => setIsAuthModalOpen(true)}
            className="flex flex-col items-center gap-1 py-1 px-3 rounded-2xl transition-all text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
          >
            <div className="p-1 rounded-xl transition">
              <UserCheck className="w-5 h-5" />
            </div>
            <span className="text-[11px]">Tài khoản</span>
          </button>
        </div>
      </nav>

      {/* Firebase Auth Modal */}
      <AuthModal
        isOpen={isAuthModalOpen}
        onClose={() => setIsAuthModalOpen(false)}
        currentUser={currentUser}
        userProfile={userProfile}
        onLoginAsDemoStudent={initDemoProfile}
      />
    </div>
  );
}
