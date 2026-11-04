import { initializeApp } from 'firebase-admin/app';
import { getFirestore, type DocumentReference } from 'firebase-admin/firestore';
import { getMessaging, type MulticastMessage } from 'firebase-admin/messaging';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { defineString } from 'firebase-functions/params';
import * as logger from 'firebase-functions/logger';

import { buildReminderMessage, isReminderDue, type ReminderProfile } from './reminder';

// The web app uses a named (non-default) Firestore database; see firebase-applet-config.json.
const FIRESTORE_DATABASE_ID = defineString('FIRESTORE_DATABASE_ID', {
  default: 'ai-studio-remixspeakmaster-7c3c690c-95a1-4851-951e-4badcd8a2288'
});
// Public HTTPS URL of the web app, opened when a web notification is clicked.
const APP_URL = defineString('APP_URL', { default: '' });

const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument'
]);
const USER_CONCURRENCY = 20;

initializeApp();

export const sendDailyReminders = onSchedule(
  {
    schedule: 'every 15 minutes',
    timeZone: 'Etc/UTC',
    region: 'asia-southeast1',
    timeoutSeconds: 300,
    retryCount: 0
  },
  async () => {
    const db = getFirestore(FIRESTORE_DATABASE_ID.value());
    const now = new Date();
    const users = await db.collection('users').where('reminderEnabled', '==', true).get();

    let sent = 0;
    const docs = users.docs;
    for (let i = 0; i < docs.length; i += USER_CONCURRENCY) {
      const results = await Promise.all(
        docs.slice(i, i + USER_CONCURRENCY).map((doc) =>
          remindUser(doc.ref, doc.data() as ReminderProfile, now).catch((err) => {
            logger.error('Daily reminder failed', { userId: doc.id, err });
            return false;
          })
        )
      );
      sent += results.filter(Boolean).length;
    }
    logger.info('Daily reminders done', { candidates: docs.length, sent });
  }
);

async function remindUser(userRef: DocumentReference, profile: ReminderProfile, now: Date): Promise<boolean> {
  const decision = isReminderDue(profile, now);
  if (!decision.due) return false;

  const tokenSnap = await userRef.collection('fcm_tokens').get();
  if (tokenSnap.empty) return false;

  // Claim today's reminder atomically so overlapping runs never double-send.
  const claimed = await userRef.firestore.runTransaction(async (tx) => {
    const fresh = await tx.get(userRef);
    const latest = isReminderDue(fresh.data() as ReminderProfile, now);
    if (!latest.due) return false;
    tx.update(userRef, { lastReminderSentDate: latest.localDate });
    return true;
  });
  if (!claimed) return false;

  const tokens = tokenSnap.docs.map((d) => d.id);
  const { title, body } = buildReminderMessage(profile, decision.localDate);
  const link = APP_URL.value().startsWith('https://') ? APP_URL.value() : undefined;

  const message: MulticastMessage = {
    tokens,
    notification: { title, body },
    data: { type: 'daily_reminder', tag: 'daily-reminder', title, body, ...(link ? { link } : {}) },
    android: {
      priority: 'high',
      notification: { channelId: 'daily_streak_reminder', tag: 'daily-reminder' }
    },
    apns: { payload: { aps: { sound: 'default' } } },
    webpush: link ? { fcmOptions: { link } } : undefined
  };

  const response = await getMessaging().sendEachForMulticast(message);

  const staleTokens = response.responses
    .map((r, idx) => (!r.success && r.error && INVALID_TOKEN_CODES.has(r.error.code) ? tokens[idx] : null))
    .filter((t): t is string => t !== null);
  await Promise.all(staleTokens.map((t) => userRef.collection('fcm_tokens').doc(t).delete()));

  logger.info('Daily reminder sent', {
    userId: userRef.id,
    success: response.successCount,
    failure: response.failureCount,
    removedTokens: staleTokens.length
  });
  return response.successCount > 0;
}
