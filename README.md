<div align="center">
<img width="1200" height="475" alt="GHBanner" src="https://ai.google.dev/static/site-assets/images/share-ais-513315318.png" />
</div>

# Run and deploy your AI Studio app

This contains everything you need to run your app locally.

View your app in AI Studio: https://ai.studio/apps/7c3c690c-95a1-4851-951e-4badcd8a2288

## Run Locally

**Prerequisites:**  Node.js


1. Install dependencies:
   `npm install`
2. Set the `GEMINI_API_KEY` in [.env.local](.env.local) to your Gemini API key
3. Run the app:
   `npm run dev`

## Firebase backend

- Schema: [`docs/firestore-schema.md`](docs/firestore-schema.md) · rules: [`firestore.rules`](firestore.rules)
- Offline persistence is on for both clients (web IndexedDB cache, Flutter `persistenceEnabled`).
- Daily reminder: the `sendDailyReminders` Cloud Function (`functions/`) runs every 15 minutes and sends an FCM push at each user's `reminderTime` in their `timezone`, skipping days the user already practiced. The Flutter app falls back to a local scheduled notification if push permission is unavailable.

### Deploy

```bash
npm i -g firebase-tools && firebase login
(cd functions && npm install)
firebase deploy --only firestore,functions
```

The functions need the Blaze plan (Cloud Scheduler). Optional params, prompted on first deploy:
`FIRESTORE_DATABASE_ID` (defaults to this app's database) and `APP_URL` (HTTPS URL opened when a web notification is clicked).

### Web push setup

1. Firebase console → Project settings → Cloud Messaging → Web Push certificates → generate key pair.
2. Put the public key in `.env.local` as `VITE_FIREBASE_VAPID_KEY`.
3. In the app, enable the reminder and click save; the browser asks for notification permission and registers `public/firebase-messaging-sw.js`.

### Flutter push setup

Add `google-services.json` (Android) / `GoogleService-Info.plist` + APNs key in Firebase console (iOS) for this project, then run the app. On iOS also enable the Push Notifications and Background Modes → Remote notifications capabilities.

### Tests

```bash
npx tsx --test test/streak_logic.test.ts         # web streak logic
(cd functions && npm test)                       # reminder scheduling logic
(cd firestore-tests && npm install && npm test)  # security rules on the emulator (JDK 21+)
flutter test                                     # Flutter services
```

## App Flutter: M4 – AI Pronunciation

App Flutter (`lib/`) chấm phát âm trên audio thật bằng Pronunciation API
([LearnEnglish-vs-AI-pronun](https://github.com/tugduong57/LearnEnglish-vs-AI-pronun)),
Gemini chỉ dùng làm dự phòng. Cách chạy và kiến trúc: [`docs/M4_AI_PRONUNCIATION.md`](docs/M4_AI_PRONUNCIATION.md).

```bash
flutter run --dart-define=PRONUN_API_BASE=http://10.0.2.2:8000
```
