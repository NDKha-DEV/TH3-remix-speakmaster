import '../models/models.dart';

class StreakSummary {
  final int currentStreak;
  final int longestStreak;

  const StreakSummary({
    required this.currentStreak,
    required this.longestStreak,
  });
}

class LearningStatsService {
  static String dateKey(DateTime date) {
    final localDate = date.toLocal();
    return '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
  }

  static double progressRatio(int value, int goal) {
    if (goal <= 0) return 0;
    return (value / goal).clamp(0.0, 1.0).toDouble();
  }

  static int? averageScore(Iterable<int?> scores) {
    final scoredSessions = scores.whereType<int>().toList();
    if (scoredSessions.isEmpty) return null;
    return (scoredSessions.reduce((total, score) => total + score) /
            scoredSessions.length)
        .round();
  }

  static int totalMinutes(Iterable<DailyStat> dailyStats) {
    return dailyStats.fold(0, (total, stat) => total + stat.minutesSpent);
  }

  static DailyStat? statForDate(Iterable<DailyStat> dailyStats, String date) {
    for (final stat in dailyStats) {
      if (stat.date == date) return stat;
    }
    return null;
  }

  static DailyStat addCompletedSession({
    required DailyStat? currentStat,
    required String userId,
    required String date,
    required int minutesAdded,
    required int? score,
    required int dailyGoalMinutes,
    required int dailyGoalSentences,
  }) {
    final currentSessions = currentStat?.sentencesPracticed ?? 0;
    final currentMinutes = currentStat?.minutesSpent ?? 0;
    final currentScoreTotal =
        (currentStat?.averageScore ?? 0) * currentSessions;
    final scoredSessions = currentSessions + (score == null ? 0 : 1);
    final totalScore = currentScoreTotal + (score ?? 0);
    final minutes = currentMinutes + (minutesAdded < 0 ? 0 : minutesAdded);
    final sessions = currentSessions + 1;

    return DailyStat(
      id: date,
      userId: userId,
      date: date,
      minutesSpent: minutes,
      sentencesPracticed: sessions,
      averageScore: scoredSessions == 0
          ? 0
          : (totalScore / scoredSessions).round(),
      goalAchieved:
          minutes >= dailyGoalMinutes || sessions >= dailyGoalSentences,
    );
  }

  static int streakAfterPractice({
    required String lastActiveDate,
    required int currentStreak,
    required String today,
  }) {
    if (lastActiveDate == today) return currentStreak;
    final lastActive = _parseDateKey(lastActiveDate);
    final currentDay = _parseDateKey(today);
    if (lastActive == null || currentDay == null) return 1;

    final daysSinceLastActivity = _utcDay(currentDay)
        .difference(_utcDay(lastActive))
        .inDays;
    return daysSinceLastActivity == 1 ? currentStreak + 1 : 1;
  }

  static StreakSummary calculateStreak({
    required Iterable<String> practiceDates,
    required DateTime now,
    required int longestStreak,
  }) {
    final activeDays = practiceDates
        .map(_parseDateKey)
        .whereType<DateTime>()
        .map(dateKey)
        .toSet();
    final today = now.toLocal();
    final todayDate = DateTime(today.year, today.month, today.day);
    final todayKey = dateKey(todayDate);
    var anchor = todayDate;
    if (!activeDays.contains(todayKey)) {
      anchor = DateTime(todayDate.year, todayDate.month, todayDate.day - 1);
      if (!activeDays.contains(dateKey(anchor))) {
        return StreakSummary(
          currentStreak: 0,
          longestStreak: _longestRun(activeDays, longestStreak),
        );
      }
    }

    var currentStreak = 0;
    while (activeDays.contains(dateKey(anchor))) {
      currentStreak++;
      anchor = DateTime(anchor.year, anchor.month, anchor.day - 1);
    }

    return StreakSummary(
      currentStreak: currentStreak,
      longestStreak: _longestRun(activeDays, longestStreak),
    );
  }

  static int _longestRun(Set<String> activeDays, int existingLongest) {
    final dates = activeDays.map(_parseDateKey).whereType<DateTime>().toList()
      ..sort();
    var longest = existingLongest;
    var run = 0;
    DateTime? previous;
    for (final date in dates) {
      if (previous != null &&
          _utcDay(date).difference(_utcDay(previous)).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
      previous = date;
    }
    return longest;
  }

  static DateTime? _parseDateKey(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static DateTime _utcDay(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }
}
