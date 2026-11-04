# Firestore schema

Database: `ai-studio-remixspeakmaster-7c3c690c-95a1-4851-951e-4badcd8a2288` (named database, project `gen-lang-client-0369290048`).
Machine-readable definition: [`firebase-blueprint.json`](../firebase-blueprint.json). Access control: [`firestore.rules`](../firestore.rules).

All user data lives under the user's own document, so every rule reduces to "the signed-in user owns this path".

```
users/{uid}                              UserProfile
├── practice_records/{recordId}          PracticeRecord   (immutable)
├── daily_stats/{YYYY-MM-DD}             DailyStat        (one per local day)
├── fcm_tokens/{fcmToken}                FcmToken         (one per device)
├── pronunciation_attempts/{attemptId}   PronunciationAttempt (M4, server-written, owner read-only)
├── phoneme_stats/{phonemeId}            PhonemeStat      (M4, server-written, owner read-only)
└── pronunciation_idempotency/{key}      (M4, server-only, no client access)
```

## `users/{uid}` — UserProfile

| Field | Type | Notes |
|---|---|---|
| `id` | string | Must equal `{uid}`. Immutable. |
| `email` | string | ≤ 320 chars. |
| `displayName` | string? | ≤ 100 chars. |
| `photoURL` | string \| null | ≤ 2048 chars. |
| `dailyGoalMinutes` | int | 1–1440. |
| `dailyGoalSentences` | int | 1–1000. |
| `streakCount` | int | Can only stay, +1, or reset to ≤ 1 per write. |
| `longestStreak` | int | Never decreases, always ≥ `streakCount`. |
| `lastActiveDate` | string | `YYYY-MM-DD` (local) or `""` before first practice. |
| `totalXp` | int | Never decreases; at most +1000 per write. |
| `level` | int | ≥ 1 (`floor(totalXp / 500) + 1`). |
| `reminderTime` | string | `HH:mm`, 24h, in `timezone`. |
| `reminderEnabled` | bool | |
| `timezone` | string? | IANA zone, synced by clients on login. |
| `lastReminderSentDate` | string? | **Server only** (Cloud Functions). Clients cannot create or change it. |
| `createdAt` / `updatedAt` | ISO string | `createdAt` immutable. |

## `users/{uid}/practice_records/{recordId}` — PracticeRecord

`recordId` matches `^[a-zA-Z0-9_-]{1,128}$` and equals `id`. Records are append-only (no updates); owner may delete.

`id`, `userId`, `targetText` (1–1000 chars), `category`, `difficulty`, `overallScore` / `accuracyScore` / `fluencyScore` / `completenessScore` (0–100), `expectedIpa`, `detectedText?`, `feedback`, `mispronouncedWords?`, `tongueMouthAdvice?` (nullable), `assessmentId?` (M4 attempt id), `scoringSource?` (`api|gemini|ruleBased`), `createdAt`.

## `users/{uid}/daily_stats/{YYYY-MM-DD}` — DailyStat

Document ID, `id` and `date` are the same local date key. On update `minutesSpent` and `sentencesPracticed` may only grow.

`id`, `userId`, `date`, `minutesSpent` (0–1440), `sentencesPracticed`, `averageScore` (0–100), `goalAchieved`, `updatedAt`.

## `users/{uid}/fcm_tokens/{token}` — FcmToken

Document ID is the FCM registration token, so re-registering is idempotent.

`token` (= doc ID), `platform` (`web|android|ios|macos|windows|linux|unknown`), `timezone?`, `createdAt?`, `updatedAt`.
Invalid tokens are deleted by the reminder function when FCM reports them unregistered.

## Writes per practice session

Record, daily stat and profile (streak/XP) are written atomically:

- Web: one `writeBatch` (works offline; queued by the persistent cache).
- Flutter: one transaction (`FirebaseService.recordPracticeSession`).

## Indexes

All queries are single-field (`orderBy('createdAt')`, `orderBy('date')`, `where('reminderEnabled', '==', true)`), covered by automatic indexes. `firestore.indexes.json` is intentionally empty.
