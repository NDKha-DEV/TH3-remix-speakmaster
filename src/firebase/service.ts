import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  query,
  orderBy,
  limit,
  getDocs,
  writeBatch
} from 'firebase/firestore';
import { User } from 'firebase/auth';
import { db, handleFirestoreError, OperationType } from './config';
import { UserProfile, PracticeRecord, DailyStat, FcmTokenDoc } from '../types';

function toDateKey(d: Date): string {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function getTodayDateString(): string {
  return toDateKey(new Date());
}

export function getYesterdayDateString(): string {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  return toDateKey(d);
}

// IANA timezone of this device, used by the server to send reminders at local time.
export function getDeviceTimezone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Ho_Chi_Minh';
  } catch {
    return 'Asia/Ho_Chi_Minh';
  }
}

// Fetch or create user profile
export async function getOrCreateUserProfile(user: User): Promise<UserProfile> {
  const userRef = doc(db, 'users', user.uid);
  const timezone = getDeviceTimezone();
  try {
    const snap = await getDoc(userRef);
    if (snap.exists()) {
      const profile = snap.data() as UserProfile;
      // Keep the stored timezone in sync so the daily reminder fires at local time.
      if (profile.timezone !== timezone) {
        await updateUserProfile(user.uid, { timezone });
        return { ...profile, timezone };
      }
      return profile;
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
      timezone,
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

export type PracticeRecordInput = Omit<PracticeRecord, 'id' | 'userId' | 'createdAt'>;

// Save a practice record, today's stat and the streak/XP update in one atomic batch.
// Batches (unlike transactions) are queued by the offline cache and synced later.
export async function recordPracticeSession(
  userId: string,
  userProfile: UserProfile,
  recordInput: PracticeRecordInput,
  minutesAdded: number,
  score: number
): Promise<{ record: PracticeRecord; updatedProfile: UserProfile; todayStat: DailyStat; streakIncreased: boolean }> {
  const today = getTodayDateString();
  const yesterday = getYesterdayDateString();
  const now = new Date().toISOString();
  const userRef = doc(db, 'users', userId);
  const statRef = doc(db, 'users', userId, 'daily_stats', today);
  const recordId = `rec_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
  const recordRef = doc(db, 'users', userId, 'practice_records', recordId);

  const record: PracticeRecord = {
    ...recordInput,
    id: recordId,
    userId,
    createdAt: now
  };

  let existingStat: DailyStat | null = null;
  try {
    const snap = await getDoc(statRef);
    existingStat = snap.exists() ? (snap.data() as DailyStat) : null;
  } catch (err) {
    handleFirestoreError(err, OperationType.GET, `users/${userId}/daily_stats/${today}`);
    throw err;
  }

  const minutes = Math.max(0, Math.round(minutesAdded));
  const sentencesPracticed = (existingStat?.sentencesPracticed ?? 0) + 1;
  const minutesSpent = (existingStat?.minutesSpent ?? 0) + Math.max(1, minutes);
  const averageScore = Math.round(
    ((existingStat?.averageScore ?? 0) * (existingStat?.sentencesPracticed ?? 0) + score) / sentencesPracticed
  );
  const todayStat: DailyStat = {
    id: today,
    userId,
    date: today,
    minutesSpent,
    sentencesPracticed,
    averageScore,
    goalAchieved: minutesSpent >= userProfile.dailyGoalMinutes || sentencesPracticed >= userProfile.dailyGoalSentences,
    updatedAt: now
  };

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

  const profileUpdates = {
    streakCount: newStreak,
    longestStreak,
    lastActiveDate: today,
    totalXp,
    level,
    updatedAt: now
  };

  const batch = writeBatch(db);
  batch.set(recordRef, record);
  batch.set(statRef, todayStat);
  batch.update(userRef, profileUpdates);

  try {
    await batch.commit();
  } catch (err) {
    handleFirestoreError(err, OperationType.WRITE, `users/${userId}`);
    throw err;
  }

  return {
    record,
    updatedProfile: { ...userProfile, ...profileUpdates },
    todayStat,
    streakIncreased
  };
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

// Register this device for FCM push (doc id = token so re-saving is idempotent).
export async function saveFcmToken(userId: string, token: string, platform: FcmTokenDoc['platform']): Promise<void> {
  const tokenRef = doc(db, 'users', userId, 'fcm_tokens', token);
  const now = new Date().toISOString();
  const data: FcmTokenDoc = {
    token,
    platform,
    timezone: getDeviceTimezone(),
    createdAt: now,
    updatedAt: now
  };
  try {
    await setDoc(tokenRef, data);
  } catch (error) {
    handleFirestoreError(error, OperationType.WRITE, `users/${userId}/fcm_tokens/${token}`);
  }
}

export async function deleteFcmToken(userId: string, token: string): Promise<void> {
  try {
    await deleteDoc(doc(db, 'users', userId, 'fcm_tokens', token));
  } catch (error) {
    handleFirestoreError(error, OperationType.DELETE, `users/${userId}/fcm_tokens/${token}`);
  }
}
