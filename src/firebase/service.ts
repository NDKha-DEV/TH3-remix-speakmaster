import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  collection,
  query,
  where,
  orderBy,
  limit,
  getDocs,
  Timestamp
} from 'firebase/firestore';
import { User } from 'firebase/auth';
import { db, handleFirestoreError, OperationType } from './config';
import { UserProfile, PracticeRecord, DailyStat } from '../types';

export function getTodayDateString(): string {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function getYesterdayDateString(): string {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

// Fetch or create user profile
export async function getOrCreateUserProfile(user: User): Promise<UserProfile> {
  const userRef = doc(db, 'users', user.uid);
  try {
    const snap = await getDoc(userRef);
    if (snap.exists()) {
      return snap.data() as UserProfile;
    }

    const today = getTodayDateString();
    const newProfile: UserProfile = {
      id: user.uid,
      email: user.email || 'student@speakmaster.edu',
      displayName: user.displayName || 'Học viên SpeakMaster',
      photoURL: user.photoURL || '',
      dailyGoalMinutes: 15,
      dailyGoalSentences: 10,
      streakCount: 1,
      longestStreak: 1,
      lastActiveDate: today,
      totalXp: 150,
      level: 1,
      reminderTime: '20:00',
      reminderEnabled: true,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    await setDoc(userRef, newProfile);
    return newProfile;
  } catch (error) {
    handleFirestoreError(error, OperationType.GET, `users/${user.uid}`);
    throw error;
  }
}

// Update user settings/profile
export async function updateUserProfile(userId: string, updates: Partial<UserProfile>): Promise<void> {
  const userRef = doc(db, 'users', userId);
  try {
    await updateDoc(userRef, {
      ...updates,
      updatedAt: new Date().toISOString()
    });
  } catch (error) {
    handleFirestoreError(error, OperationType.UPDATE, `users/${userId}`);
    throw error;
  }
}

// Save practice record
export async function savePracticeRecord(userId: string, record: Omit<PracticeRecord, 'id' | 'userId' | 'createdAt'>): Promise<PracticeRecord> {
  const recordId = `rec_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
  const recordRef = doc(db, 'users', userId, 'practice_records', recordId);
  const fullRecord: PracticeRecord = {
    ...record,
    id: recordId,
    userId,
    createdAt: new Date().toISOString()
  };

  try {
    await setDoc(recordRef, fullRecord);
    return fullRecord;
  } catch (error) {
    handleFirestoreError(error, OperationType.CREATE, `users/${userId}/practice_records/${recordId}`);
    throw error;
  }
}

// Fetch practice records
export async function fetchPracticeHistory(userId: string, count = 20): Promise<PracticeRecord[]> {
  const recordsCol = collection(db, 'users', userId, 'practice_records');
  const q = query(recordsCol, orderBy('createdAt', 'desc'), limit(count));

  try {
    const snap = await getDocs(q);
    return snap.docs.map(doc => doc.data() as PracticeRecord);
  } catch (error) {
    handleFirestoreError(error, OperationType.LIST, `users/${userId}/practice_records`);
    return [];
  }
}

// Record daily stats and update streak
export async function recordPracticeActivity(
  userId: string,
  userProfile: UserProfile,
  minutesAdded: number,
  score: number
): Promise<{ updatedProfile: UserProfile; todayStat: DailyStat; streakIncreased: boolean }> {
  const today = getTodayDateString();
  const yesterday = getYesterdayDateString();
  const dateRef = doc(db, 'users', userId, 'daily_stats', today);

  let currentStat: DailyStat;
  try {
    const snap = await getDoc(dateRef);
    if (snap.exists()) {
      const data = snap.data() as DailyStat;
      const totalSentences = data.sentencesPracticed + 1;
      const newAvg = Math.round((data.averageScore * data.sentencesPracticed + score) / totalSentences);
      const newMinutes = data.minutesSpent + minutesAdded;
      currentStat = {
        id: today,
        userId,
        date: today,
        minutesSpent: newMinutes,
        sentencesPracticed: totalSentences,
        averageScore: newAvg,
        goalAchieved: newMinutes >= userProfile.dailyGoalMinutes || totalSentences >= userProfile.dailyGoalSentences,
        updatedAt: new Date().toISOString()
      };
      await setDoc(dateRef, currentStat);
    } else {
      currentStat = {
        id: today,
        userId,
        date: today,
        minutesSpent: Math.max(1, minutesAdded),
        sentencesPracticed: 1,
        averageScore: score,
        goalAchieved: minutesAdded >= userProfile.dailyGoalMinutes || 1 >= userProfile.dailyGoalSentences,
        updatedAt: new Date().toISOString()
      };
      await setDoc(dateRef, currentStat);
    }
  } catch (err) {
    handleFirestoreError(err, OperationType.WRITE, `users/${userId}/daily_stats/${today}`);
    throw err;
  }

  // Calculate streak update
  let newStreak = userProfile.streakCount;
  let streakIncreased = false;

  if (userProfile.lastActiveDate === today) {
    // Already counted today
  } else if (userProfile.lastActiveDate === yesterday) {
    // Practiced yesterday, consecutive!
    newStreak += 1;
    streakIncreased = true;
  } else {
    // Missed a day or more, restart streak at 1
    newStreak = 1;
    streakIncreased = true;
  }

  const longestStreak = Math.max(userProfile.longestStreak, newStreak);
  const addedXp = Math.round(score * 1.5) + (streakIncreased ? 50 : 20);
  const totalXp = userProfile.totalXp + addedXp;
  const level = Math.floor(totalXp / 500) + 1;

  const updatedProfile: UserProfile = {
    ...userProfile,
    streakCount: newStreak,
    longestStreak,
    lastActiveDate: today,
    totalXp,
    level,
    updatedAt: new Date().toISOString()
  };

  await updateUserProfile(userId, {
    streakCount: newStreak,
    longestStreak,
    lastActiveDate: today,
    totalXp,
    level
  });

  return { updatedProfile, todayStat: currentStat, streakIncreased };
}

// Fetch last 7 days of stats for graphs
export async function fetchRecentDailyStats(userId: string): Promise<DailyStat[]> {
  const statsCol = collection(db, 'users', userId, 'daily_stats');
  const q = query(statsCol, orderBy('date', 'desc'), limit(7));
  try {
    const snap = await getDocs(q);
    return snap.docs.map(doc => doc.data() as DailyStat).reverse();
  } catch (error) {
    handleFirestoreError(error, OperationType.LIST, `users/${userId}/daily_stats`);
    return [];
  }
}
