import test from 'node:test';
import assert from 'node:assert/strict';

function calculateStreak(
  lastActiveDate: string,
  today: string,
  yesterday: string,
  currentStreak: number,
  longestStreak: number
) {
  let newStreak = currentStreak;
  let streakIncreased = false;

  if (lastActiveDate === today) {
    // Already counted today
  } else if (lastActiveDate === yesterday) {
    newStreak += 1;
    streakIncreased = true;
  } else {
    // Missed one or more days, restart at 1
    newStreak = 1;
    streakIncreased = true;
  }

  const newLongest = Math.max(longestStreak, newStreak);
  return { newStreak, longestStreak: newLongest, streakIncreased };
}

test('calculateStreak increases streak by 1 if user practiced yesterday', () => {
  const result = calculateStreak('2026-11-01', '2026-11-02', '2026-11-01', 5, 10);
  assert.equal(result.newStreak, 6);
  assert.equal(result.longestStreak, 10);
  assert.equal(result.streakIncreased, true);
});

test('calculateStreak updates longestStreak if newStreak exceeds longest', () => {
  const result = calculateStreak('2026-11-01', '2026-11-02', '2026-11-01', 10, 10);
  assert.equal(result.newStreak, 11);
  assert.equal(result.longestStreak, 11);
  assert.equal(result.streakIncreased, true);
});

test('calculateStreak maintains streak if user practices multiple times on same day', () => {
  const result = calculateStreak('2026-11-02', '2026-11-02', '2026-11-01', 6, 10);
  assert.equal(result.newStreak, 6);
  assert.equal(result.streakIncreased, false);
});

test('calculateStreak resets to 1 if user missed 2 or more days', () => {
  const result = calculateStreak('2026-10-28', '2026-11-02', '2026-11-01', 15, 20);
  assert.equal(result.newStreak, 1);
  assert.equal(result.longestStreak, 20);
  assert.equal(result.streakIncreased, true);
});
