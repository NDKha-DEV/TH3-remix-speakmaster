import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildReminderMessage,
  isReminderDue,
  localClock,
  parseTimeOfDay,
  previousDateKey,
  resolveTimezone
} from '../src/reminder';

// 2026-11-04 13:05 UTC == 20:05 in Asia/Ho_Chi_Minh (UTC+7).
const NOW = new Date('2026-11-04T13:05:00Z');

test('localClock converts to the user timezone', () => {
  assert.deepEqual(localClock(NOW, 'Asia/Ho_Chi_Minh'), { dateKey: '2026-11-04', minutesOfDay: 20 * 60 + 5 });
  assert.deepEqual(localClock(NOW, 'America/Los_Angeles'), { dateKey: '2026-11-04', minutesOfDay: 5 * 60 + 5 });
  assert.deepEqual(localClock(new Date('2026-11-04T18:30:00Z'), 'Asia/Tokyo'), { dateKey: '2026-11-05', minutesOfDay: 3 * 60 + 30 });
});

test('resolveTimezone falls back for missing or invalid zones', () => {
  assert.equal(resolveTimezone(undefined), 'Asia/Ho_Chi_Minh');
  assert.equal(resolveTimezone('Mars/Olympus'), 'Asia/Ho_Chi_Minh');
  assert.equal(resolveTimezone('Europe/Paris'), 'Europe/Paris');
});

test('parseTimeOfDay validates HH:mm', () => {
  assert.equal(parseTimeOfDay('20:00'), 1200);
  assert.equal(parseTimeOfDay('07:30'), 450);
  assert.equal(parseTimeOfDay('24:00'), null);
  assert.equal(parseTimeOfDay('7:30'), null);
  assert.equal(parseTimeOfDay(undefined), null);
});

test('previousDateKey crosses month and year boundaries', () => {
  assert.equal(previousDateKey('2026-11-04'), '2026-11-03');
  assert.equal(previousDateKey('2026-03-01'), '2026-02-28');
  assert.equal(previousDateKey('2027-01-01'), '2026-12-31');
});

test('reminder is due inside the window when not practiced or sent today', () => {
  const decision = isReminderDue(
    { reminderEnabled: true, reminderTime: '20:00', timezone: 'Asia/Ho_Chi_Minh', lastActiveDate: '2026-11-03' },
    NOW
  );
  assert.deepEqual(decision, { due: true, localDate: '2026-11-04' });
});

test('reminder respects the user settings and daily state', () => {
  const base = { reminderEnabled: true, reminderTime: '20:00', timezone: 'Asia/Ho_Chi_Minh' };
  const reason = (overrides: object) => {
    const d = isReminderDue({ ...base, ...overrides }, NOW);
    return d.due ? 'due' : d.reason;
  };
  assert.equal(reason({ reminderEnabled: false }), 'disabled');
  assert.equal(reason({ reminderTime: 'bad' }), 'invalid_time');
  assert.equal(reason({ reminderTime: '20:10' }), 'outside_window');
  assert.equal(reason({ reminderTime: '19:05' }), 'outside_window');
  assert.equal(reason({ reminderTime: '19:06' }), 'due');
  assert.equal(reason({ lastReminderSentDate: '2026-11-04' }), 'already_sent');
  assert.equal(reason({ lastActiveDate: '2026-11-04' }), 'already_practiced');
  // Same instant is 05:05 in Los Angeles, so an 20:00 reminder is not due there.
  assert.equal(reason({ timezone: 'America/Los_Angeles' }), 'outside_window');
});

test('message mentions the streak only while it is still alive', () => {
  const alive = buildReminderMessage({ streakCount: 6, lastActiveDate: '2026-11-03', dailyGoalMinutes: 10 }, '2026-11-04');
  assert.match(alive.title, /6 ngày/);
  assert.match(alive.body, /10 phút/);

  const broken = buildReminderMessage({ streakCount: 6, lastActiveDate: '2026-10-30' }, '2026-11-04');
  assert.doesNotMatch(broken.title, /6 ngày/);
});
