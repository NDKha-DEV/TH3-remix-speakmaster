// Run with: npm test (from firestore-tests/, starts the Firestore emulator; needs JDK 21+).
import test, { after, before, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment
} from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

const ALICE = 'alice_uid';
const BOB = 'bob_uid';
const NOW = '2026-11-04T13:00:00.000Z';

let env: RulesTestEnvironment;

const webProfile = (overrides: Record<string, unknown> = {}) => ({
  id: ALICE,
  email: 'alice@example.com',
  displayName: 'Alice',
  photoURL: '',
  dailyGoalMinutes: 15,
  dailyGoalSentences: 10,
  streakCount: 1,
  longestStreak: 1,
  lastActiveDate: '2026-11-04',
  totalXp: 150,
  level: 1,
  reminderTime: '20:00',
  reminderEnabled: true,
  timezone: 'Asia/Ho_Chi_Minh',
  createdAt: NOW,
  updatedAt: NOW,
  ...overrides
});

const practiceRecord = (id: string, overrides: Record<string, unknown> = {}) => ({
  id,
  userId: ALICE,
  targetText: 'I think that this is the best solution.',
  category: 'Daily',
  difficulty: 'Beginner',
  overallScore: 84,
  accuracyScore: 82,
  fluencyScore: 86,
  completenessScore: 100,
  expectedIpa: '/aɪ θɪŋk/',
  feedback: 'Tốt',
  tongueMouthAdvice: null,
  createdAt: NOW,
  ...overrides
});

const dailyStat = (date: string, overrides: Record<string, unknown> = {}) => ({
  id: date,
  userId: ALICE,
  date,
  minutesSpent: 2,
  sentencesPracticed: 1,
  averageScore: 84,
  goalAchieved: false,
  updatedAt: NOW,
  ...overrides
});

const aliceDb = () => env.authenticatedContext(ALICE).firestore();
const bobDb = () => env.authenticatedContext(BOB).firestore();

async function seedAliceProfile(overrides: Record<string, unknown> = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', ALICE), webProfile(overrides));
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-speakmaster',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') }
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env.cleanup();
});

test('users: owner creates a web-shaped or flutter-shaped profile', async () => {
  await assertSucceeds(setDoc(doc(aliceDb(), 'users', ALICE), webProfile()));
  await env.clearFirestore();
  // Flutter's UserProfile.toMap(): nullable photoURL, empty lastActiveDate, no timezone yet.
  const { timezone, ...flutterProfile } = webProfile({
    photoURL: null,
    streakCount: 0,
    longestStreak: 0,
    lastActiveDate: ''
  });
  await assertSucceeds(setDoc(doc(aliceDb(), 'users', ALICE), flutterProfile));
});

test('users: profiles are private and cannot be listed', async () => {
  await seedAliceProfile();
  await assertSucceeds(getDoc(doc(aliceDb(), 'users', ALICE)));
  await assertFails(getDoc(doc(bobDb(), 'users', ALICE)));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users', ALICE)));
  await assertFails(setDoc(doc(bobDb(), 'users', ALICE), webProfile()));
});

test('users: create rejects server fields, inflated stats and unknown keys', async () => {
  const ref = doc(aliceDb(), 'users', ALICE);
  await assertFails(setDoc(ref, webProfile({ lastReminderSentDate: '2026-11-04' })));
  await assertFails(setDoc(ref, webProfile({ streakCount: 50, longestStreak: 50 })));
  await assertFails(setDoc(ref, webProfile({ totalXp: 99999 })));
  await assertFails(setDoc(ref, webProfile({ isAdmin: true })));
  await assertFails(setDoc(ref, webProfile({ id: BOB })));
  await assertFails(setDoc(ref, webProfile({ reminderTime: '25:00' })));
});

test('users: update allows settings and a normal practice step', async () => {
  await seedAliceProfile();
  const ref = doc(aliceDb(), 'users', ALICE);
  await assertSucceeds(updateDoc(ref, { dailyGoalMinutes: 20, reminderTime: '07:30', reminderEnabled: false, updatedAt: NOW }));
  await assertSucceeds(
    updateDoc(ref, { streakCount: 2, longestStreak: 2, lastActiveDate: '2026-11-05', totalXp: 326, level: 1 })
  );
  await assertSucceeds(updateDoc(ref, { streakCount: 1, lastActiveDate: '2026-11-09', totalXp: 476 }));
});

test('users: update rejects cheating and server-managed fields', async () => {
  await seedAliceProfile({ streakCount: 3, longestStreak: 5, totalXp: 400 });
  const ref = doc(aliceDb(), 'users', ALICE);
  await assertFails(updateDoc(ref, { streakCount: 10, longestStreak: 10 }));
  await assertFails(updateDoc(ref, { totalXp: 50000 }));
  await assertFails(updateDoc(ref, { totalXp: 100 }));
  await assertFails(updateDoc(ref, { longestStreak: 4 }));
  await assertFails(updateDoc(ref, { lastReminderSentDate: '2026-11-04' }));
  await assertFails(updateDoc(ref, { id: BOB }));
  await assertFails(updateDoc(ref, { createdAt: '2020-01-01T00:00:00.000Z' }));
  await assertFails(updateDoc(ref, { lastActiveDate: 'yesterday' }));
});

test('practice_records: owner creates valid immutable records', async () => {
  await seedAliceProfile();
  const ref = doc(aliceDb(), 'users', ALICE, 'practice_records', 'rec_1');
  await assertSucceeds(setDoc(ref, practiceRecord('rec_1')));
  await assertSucceeds(getDoc(ref));
  await assertFails(updateDoc(ref, { overallScore: 100 }));
  await assertFails(getDoc(doc(bobDb(), 'users', ALICE, 'practice_records', 'rec_1')));
  await assertSucceeds(deleteDoc(ref));
});

test('practice_records: accepts M4 assessment link fields', async () => {
  const ref = (id: string) => doc(aliceDb(), 'users', ALICE, 'practice_records', id);
  await assertSucceeds(setDoc(ref('rec_m4'), practiceRecord('rec_m4', { assessmentId: 'att_123', scoringSource: 'api' })));
  await assertSucceeds(setDoc(ref('rec_m4b'), practiceRecord('rec_m4b', { scoringSource: 'ruleBased' })));
  await assertFails(setDoc(ref('rec_m4c'), practiceRecord('rec_m4c', { scoringSource: 'manual' })));
});

test('M4 collections are server-written and owner read-only', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', ALICE, 'pronunciation_attempts', 'att_1'), { id: 'att_1' });
    await setDoc(doc(ctx.firestore(), 'users', ALICE, 'phoneme_stats', 'TH'), { phoneme: 'θ' });
  });
  await assertSucceeds(getDoc(doc(aliceDb(), 'users', ALICE, 'pronunciation_attempts', 'att_1')));
  await assertSucceeds(getDoc(doc(aliceDb(), 'users', ALICE, 'phoneme_stats', 'TH')));
  await assertFails(getDoc(doc(bobDb(), 'users', ALICE, 'pronunciation_attempts', 'att_1')));
  await assertFails(setDoc(doc(aliceDb(), 'users', ALICE, 'pronunciation_attempts', 'att_2'), { id: 'att_2' }));
  await assertFails(setDoc(doc(aliceDb(), 'users', ALICE, 'phoneme_stats', 'TH'), { phoneme: 'θ', attempts: 0 }));
  await assertFails(getDoc(doc(aliceDb(), 'users', ALICE, 'pronunciation_idempotency', 'k1')));
});

test('practice_records: rejects invalid shapes', async () => {
  const col = (id: string) => doc(aliceDb(), 'users', ALICE, 'practice_records', id);
  await assertFails(setDoc(col('rec_2'), practiceRecord('rec_other')));
  await assertFails(setDoc(col('rec_3'), practiceRecord('rec_3', { userId: BOB })));
  await assertFails(setDoc(col('rec_4'), practiceRecord('rec_4', { overallScore: 150 })));
  await assertFails(setDoc(col('rec_5'), practiceRecord('rec_5', { targetText: '' })));
  await assertFails(setDoc(col('rec_6'), practiceRecord('rec_6', { hacked: true })));
  await assertFails(setDoc(doc(bobDb(), 'users', ALICE, 'practice_records', 'rec_7'), practiceRecord('rec_7')));
});

test('daily_stats: one doc per day, progress only accumulates', async () => {
  const ref = doc(aliceDb(), 'users', ALICE, 'daily_stats', '2026-11-04');
  await assertSucceeds(setDoc(ref, dailyStat('2026-11-04')));
  await assertSucceeds(setDoc(ref, dailyStat('2026-11-04', { minutesSpent: 4, sentencesPracticed: 2, averageScore: 88 })));
  await assertFails(setDoc(ref, dailyStat('2026-11-04', { minutesSpent: 1, sentencesPracticed: 1 })));
  await assertFails(setDoc(doc(aliceDb(), 'users', ALICE, 'daily_stats', 'today'), dailyStat('today')));
  await assertFails(
    setDoc(doc(aliceDb(), 'users', ALICE, 'daily_stats', '2026-11-05'), dailyStat('2026-11-04'))
  );
  await assertFails(
    setDoc(doc(aliceDb(), 'users', ALICE, 'daily_stats', '2026-11-05'), dailyStat('2026-11-05', { minutesSpent: 5000 }))
  );
});

test('fcm_tokens: owner registers own device tokens only', async () => {
  const token = 'fcm-token_abc:APA91bXyz-123';
  const ref = doc(aliceDb(), 'users', ALICE, 'fcm_tokens', token);
  const data = { token, platform: 'web', timezone: 'Asia/Ho_Chi_Minh', createdAt: NOW, updatedAt: NOW };
  await assertSucceeds(setDoc(ref, data));
  await assertFails(setDoc(doc(aliceDb(), 'users', ALICE, 'fcm_tokens', 'other'), data));
  await assertFails(setDoc(ref, { ...data, platform: 'toaster' }));
  await assertFails(setDoc(doc(bobDb(), 'users', ALICE, 'fcm_tokens', token), data));
  await assertFails(getDoc(doc(bobDb(), 'users', ALICE, 'fcm_tokens', token)));
  await assertSucceeds(deleteDoc(ref));
});

test('web client batch (record + daily stat + profile) commits atomically', async () => {
  await seedAliceProfile({ lastActiveDate: '2026-11-03' });
  const db = aliceDb();
  const batch = writeBatch(db);
  batch.set(doc(db, 'users', ALICE, 'practice_records', 'rec_batch'), practiceRecord('rec_batch'));
  batch.set(doc(db, 'users', ALICE, 'daily_stats', '2026-11-04'), dailyStat('2026-11-04'));
  batch.update(doc(db, 'users', ALICE), {
    streakCount: 2, longestStreak: 2, lastActiveDate: '2026-11-04', totalXp: 326, level: 1, updatedAt: NOW
  });
  await assertSucceeds(batch.commit());
});

test('unknown collections are denied', async () => {
  await assertFails(getDoc(doc(aliceDb(), 'test', 'connection')));
  await assertFails(setDoc(doc(aliceDb(), 'admin', 'config'), { open: true }));
});
