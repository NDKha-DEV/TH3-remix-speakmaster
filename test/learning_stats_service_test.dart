import 'package:flutter_test/flutter_test.dart';
import 'package:speakmaster_flutter/models/models.dart';
import 'package:speakmaster_flutter/services/learning_stats_service.dart';

void main() {
  group('LearningStatsService streaks', () {
    test('keeps the streak when there has been no practice yet today', () {
      final result = LearningStatsService.calculateStreak(
        practiceDates: ['2026-11-02', '2026-11-03'],
        now: DateTime(2026, 11, 4, 9),
        longestStreak: 2,
      );

      expect(result.currentStreak, 2);
      expect(result.longestStreak, 2);
    });

    test('counts consecutive local calendar days including today', () {
      final result = LearningStatsService.calculateStreak(
        practiceDates: ['2026-11-01', '2026-11-02', '2026-11-03', '2026-11-04'],
        now: DateTime(2026, 11, 4, 23),
        longestStreak: 1,
      );

      expect(result.currentStreak, 4);
      expect(result.longestStreak, 4);
    });

    test('breaks the current streak after a missed day', () {
      final result = LearningStatsService.calculateStreak(
        practiceDates: ['2026-11-01'],
        now: DateTime(2026, 11, 4),
        longestStreak: 7,
      );

      expect(result.currentStreak, 0);
      expect(result.longestStreak, 7);
    });

    test('starts a new streak after a gap', () {
      expect(
        LearningStatsService.streakAfterPractice(
          lastActiveDate: '2026-10-30',
          currentStreak: 8,
          today: '2026-11-04',
        ),
        1,
      );
    });

    test('does not increment twice on the same day', () {
      expect(
        LearningStatsService.streakAfterPractice(
          lastActiveDate: '2026-11-04',
          currentStreak: 3,
          today: '2026-11-04',
        ),
        3,
      );
    });

    test('increments after practice on the previous local calendar day', () {
      expect(
        LearningStatsService.streakAfterPractice(
          lastActiveDate: '2026-11-03',
          currentStreak: 3,
          today: '2026-11-04',
        ),
        4,
      );
    });

    test('does not count an invalid date as a practice day', () {
      final result = LearningStatsService.calculateStreak(
        practiceDates: ['2026-02-30', 'not-a-date'],
        now: DateTime(2026, 11, 4),
        longestStreak: 0,
      );

      expect(result.currentStreak, 0);
      expect(result.longestStreak, 0);
    });
  });

  group('LearningStatsService statistics', () {
    test('marks records without an AI score as unscored', () {
      final record = PracticeRecord.fromMap({
        'id': 'unscored-session',
        'userId': 'student',
        'createdAt': '2026-11-04T10:00:00',
      });

      expect(record.hasScore, isFalse);
      expect(record.overallScore, 0);
    });

    test('averages only sessions that have a score', () {
      expect(LearningStatsService.averageScore([80, null, 90, null]), 85);
      expect(LearningStatsService.averageScore([null, null]), isNull);
    });

    test('caps goal progress at 100 percent', () {
      expect(LearningStatsService.progressRatio(15, 10), 1);
      expect(LearningStatsService.progressRatio(5, 10), 0.5);
    });

    test('increments completed sessions and minutes for a day', () {
      final result = LearningStatsService.addCompletedSession(
        currentStat: DailyStat(
          id: '2026-11-04',
          userId: 'student',
          date: '2026-11-04',
          minutesSpent: 12,
          sentencesPracticed: 2,
          averageScore: 80,
          goalAchieved: false,
        ),
        userId: 'student',
        date: '2026-11-04',
        minutesAdded: 3,
        score: 100,
        dailyGoalMinutes: 15,
        dailyGoalSentences: 10,
      );

      expect(result.minutesSpent, 15);
      expect(result.sentencesPracticed, 3);
      expect(result.averageScore, 87);
      expect(result.goalAchieved, isTrue);
    });

    test('counts minutes across all recorded days', () {
      final stats = [_dailyStat('2026-11-03', 4), _dailyStat('2026-11-04', 7)];

      expect(LearningStatsService.totalMinutes(stats), 11);
    });
  });
}

DailyStat _dailyStat(String date, int minutes) {
  return DailyStat(
    id: date,
    userId: 'student',
    date: date,
    minutesSpent: minutes,
    sentencesPracticed: 1,
    averageScore: 80,
    goalAchieved: false,
  );
}
