/**
 * Pure scheduling logic for the daily practice reminder (no Firebase imports,
 * so it is unit-testable). The scheduler runs every 15 minutes in UTC and asks,
 * per user, whether the reminder is due in that user's own timezone.
 */

export const DEFAULT_TIMEZONE = 'Asia/Ho_Chi_Minh';
export const DEFAULT_REMINDER_TIME = '20:00';
/** A reminder is still sent if the scheduler runs up to this long after the chosen time. */
export const REMINDER_WINDOW_MINUTES = 60;

export interface ReminderProfile {
  displayName?: string;
  reminderEnabled?: boolean;
  reminderTime?: string;
  timezone?: string;
  lastActiveDate?: string;
  lastReminderSentDate?: string;
  streakCount?: number;
  dailyGoalMinutes?: number;
}

export interface LocalClock {
  dateKey: string; // YYYY-MM-DD
  minutesOfDay: number; // 0..1439
}

export type ReminderDecision =
  | { due: true; localDate: string }
  | { due: false; localDate: string; reason: 'disabled' | 'invalid_time' | 'outside_window' | 'already_sent' | 'already_practiced' };

export function resolveTimezone(timeZone: string | undefined): string {
  if (!timeZone) return DEFAULT_TIMEZONE;
  try {
    new Intl.DateTimeFormat('en-US', { timeZone });
    return timeZone;
  } catch {
    return DEFAULT_TIMEZONE;
  }
}

export function localClock(now: Date, timeZone: string): LocalClock {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: resolveTimezone(timeZone),
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23'
  }).formatToParts(now);
  const get = (type: Intl.DateTimeFormatPartTypes) => parts.find((p) => p.type === type)?.value ?? '00';
  return {
    dateKey: `${get('year')}-${get('month')}-${get('day')}`,
    minutesOfDay: Number(get('hour')) * 60 + Number(get('minute'))
  };
}

export function parseTimeOfDay(value: string | undefined): number | null {
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(value ?? '');
  if (!match) return null;
  return Number(match[1]) * 60 + Number(match[2]);
}

export function previousDateKey(dateKey: string): string {
  const [y, m, d] = dateKey.split('-').map(Number);
  const prev = new Date(Date.UTC(y, m - 1, d - 1));
  return prev.toISOString().substring(0, 10);
}

export function isReminderDue(profile: ReminderProfile, now: Date): ReminderDecision {
  const { dateKey: localDate, minutesOfDay } = localClock(now, resolveTimezone(profile.timezone));

  if (profile.reminderEnabled === false) return { due: false, localDate, reason: 'disabled' };

  const reminderMinutes = parseTimeOfDay(profile.reminderTime ?? DEFAULT_REMINDER_TIME);
  if (reminderMinutes === null) return { due: false, localDate, reason: 'invalid_time' };

  const elapsed = minutesOfDay - reminderMinutes;
  if (elapsed < 0 || elapsed >= REMINDER_WINDOW_MINUTES) {
    return { due: false, localDate, reason: 'outside_window' };
  }
  if (profile.lastReminderSentDate === localDate) return { due: false, localDate, reason: 'already_sent' };
  if (profile.lastActiveDate === localDate) return { due: false, localDate, reason: 'already_practiced' };

  return { due: true, localDate };
}

export function buildReminderMessage(profile: ReminderProfile, localDate: string): { title: string; body: string } {
  const streak = profile.streakCount ?? 0;
  const goal = profile.dailyGoalMinutes ?? 15;
  const streakAlive = streak > 0 && profile.lastActiveDate === previousDateKey(localDate);

  if (streakAlive) {
    return {
      title: `🔥 Giữ vững chuỗi ${streak} ngày Streak!`,
      body: `Chỉ cần ${goal} phút luyện phát âm hôm nay để không mất chuỗi ${streak} ngày.`
    };
  }
  return {
    title: '🎯 Đã đến giờ luyện phát âm!',
    body: `Dành ${goal} phút luyện cùng AI để bắt đầu chuỗi Streak mới hôm nay nhé.`
  };
}
