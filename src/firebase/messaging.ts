import { getMessaging, getToken, deleteToken, isSupported } from 'firebase/messaging';
import { app } from './config';
import { saveFcmToken, deleteFcmToken } from './service';

// Web Push certificate key pair (Firebase console > Project settings > Cloud Messaging).
const VAPID_KEY: string | undefined = import.meta.env.VITE_FIREBASE_VAPID_KEY;
const SW_URL = '/firebase-messaging-sw.js';

export type WebPushStatus = 'enabled' | 'unsupported' | 'not-configured' | 'denied' | 'default' | 'error';

let currentToken: string | null = null;

async function getRegistration(): Promise<ServiceWorkerRegistration> {
  const existing = await navigator.serviceWorker.getRegistration(SW_URL);
  return existing ?? navigator.serviceWorker.register(SW_URL);
}

/**
 * Registers this browser for FCM push and stores the token under
 * users/{uid}/fcm_tokens. With `prompt: false` it never shows the permission
 * dialog (safe to call on login); pass `prompt: true` only from a user gesture.
 */
export async function syncWebPushToken(userId: string, { prompt }: { prompt: boolean }): Promise<WebPushStatus> {
  if (!VAPID_KEY) return 'not-configured';
  if (!('Notification' in window) || !('serviceWorker' in navigator) || !(await isSupported())) {
    return 'unsupported';
  }

  let permission = Notification.permission;
  if (permission === 'default' && prompt) {
    permission = await Notification.requestPermission();
  }
  if (permission !== 'granted') return permission;

  try {
    const registration = await getRegistration();
    const token = await getToken(getMessaging(app), {
      vapidKey: VAPID_KEY,
      serviceWorkerRegistration: registration
    });
    if (!token) return 'error';
    currentToken = token;
    await saveFcmToken(userId, token, 'web');
    return 'enabled';
  } catch (err) {
    console.warn('Could not register web push token:', err);
    return 'error';
  }
}

/** Unregisters this browser so a signed-out device stops receiving the user's reminders. */
export async function removeWebPushToken(userId: string): Promise<void> {
  if (!currentToken) return;
  const token = currentToken;
  currentToken = null;
  try {
    await deleteFcmToken(userId, token);
    await deleteToken(getMessaging(app));
  } catch (err) {
    console.warn('Could not remove web push token:', err);
  }
}
