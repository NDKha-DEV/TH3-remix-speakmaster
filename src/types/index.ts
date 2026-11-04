export interface UserProfile {
  id: string;
  email: string;
  displayName: string;
  photoURL?: string;
  dailyGoalMinutes: number;
  dailyGoalSentences: number;
  streakCount: number;
  longestStreak: number;
  lastActiveDate: string; // YYYY-MM-DD
  totalXp: number;
  level: number;
  reminderTime: string; // e.g. "20:00"
  reminderEnabled: boolean;
  timezone?: string; // IANA timezone, e.g. "Asia/Ho_Chi_Minh"
  lastReminderSentDate?: string; // YYYY-MM-DD in user's timezone, written by Cloud Functions only
  createdAt: string;
  updatedAt: string;
}

export interface FcmTokenDoc {
  token: string;
  platform: 'web' | 'android' | 'ios' | 'macos' | 'windows' | 'linux' | 'unknown';
  timezone?: string;
  createdAt?: string;
  updatedAt: string;
}

export interface PhonemeBreakdown {
  symbol: string;
  status: 'correct' | 'warning' | 'incorrect';
  tip?: string;
}

export interface WordAnalysis {
  word: string;
  expectedIpa: string;
  detectedIpa: string;
  score: number;
  status: 'correct' | 'warning' | 'incorrect';
  errorType: 'none' | 'missing_ending_sound' | 'vowel_distortion' | 'consonant_substitution' | 'stress_error' | 'omitted';
  phonemes: PhonemeBreakdown[];
  specificError: string;
}

export interface PronunciationResult {
  overallScore: number;
  accuracyScore: number;
  fluencyScore: number;
  completenessScore: number;
  expectedIpa: string;
  detectedIpa?: string;
  vietnameseSummary: string;
  tongueMouthAdvice: string;
  wordAnalysis: WordAnalysis[];
  recommendedDrills: string[];
  engine?: string;
}

export interface PracticeRecord {
  id: string;
  userId: string;
  targetText: string;
  category: string;
  difficulty: string;
  overallScore: number;
  accuracyScore: number;
  fluencyScore: number;
  completenessScore: number;
  expectedIpa: string;
  detectedText?: string;
  feedback: string;
  mispronouncedWords?: string;
  tongueMouthAdvice?: string;
  createdAt: string;
}

export interface DailyStat {
  id: string; // YYYY-MM-DD
  userId: string;
  date: string;
  minutesSpent: number;
  sentencesPracticed: number;
  averageScore: number;
  goalAchieved: boolean;
  updatedAt: string;
}

export interface LessonSentence {
  id: string;
  text: string;
  translation: string;
  ipa: string;
  category: 'Daily' | 'Business' | 'IELTS' | 'TongueTwister' | 'JobInterview' | 'Academic';
  difficulty: 'Beginner' | 'Intermediate' | 'Advanced';
  focusSound: string;
  tips: string;
}

export interface AccentTestSample {
  id: string;
  name: string;
  accent: string;
  targetText: string;
  simulatedSpokenText: string;
  expectedScore: number;
  notes: string;
}
