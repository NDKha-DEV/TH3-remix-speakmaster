import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/learning_stats_service.dart';

class DashboardScreen extends StatelessWidget {
  final UserProfile userProfile;
  final List<PracticeRecord> history;
  final List<DailyStat> dailyStats;
  final VoidCallback onOpenPractice;

  const DashboardScreen({
    super.key,
    required this.userProfile,
    required this.history,
    required this.dailyStats,
    required this.onOpenPractice,
  });

  @override
  Widget build(BuildContext context) {
    final today = LearningStatsService.dateKey(DateTime.now());
    final todayStat = LearningStatsService.statForDate(dailyStats, today);
    final todayMinutes = todayStat?.minutesSpent ?? 0;
    final todaySessions = todayStat?.sentencesPracticed ?? 0;
    final goalByMinutes = LearningStatsService.progressRatio(
      todayMinutes,
      userProfile.dailyGoalMinutes,
    );
    final goalBySessions = LearningStatsService.progressRatio(
      todaySessions,
      userProfile.dailyGoalSentences,
    );
    final streak = LearningStatsService.calculateStreak(
      practiceDates: dailyStats
          .where((stat) => stat.sentencesPracticed > 0)
          .map((stat) => stat.date),
      now: DateTime.now(),
      longestStreak: userProfile.longestStreak,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DailyGoalCard(
          minutes: todayMinutes,
          sessions: todaySessions,
          goalMinutes: userProfile.dailyGoalMinutes,
          goalSessions: userProfile.dailyGoalSentences,
          minutesProgress: goalByMinutes,
          sessionsProgress: goalBySessions,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _OverviewCard(
                title: 'Streak hiện tại',
                value: '${streak.currentStreak} ngày',
                icon: Icons.local_fire_department,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: 'Tổng thời gian',
                value: '${LearningStatsService.totalMinutes(dailyStats)} phút',
                icon: Icons.timer_outlined,
                color: Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Hoạt động gần đây',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: onOpenPractice,
              child: const Text('Luyện tập'),
            ),
          ],
        ),
        if (history.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Chưa có phiên học hoàn thành.'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: onOpenPractice,
                    icon: const Icon(Icons.mic),
                    label: const Text('Bắt đầu luyện tập'),
                  ),
                ],
              ),
            ),
          )
        else
          ...history.take(3).map((record) {
            final createdAt = DateTime.tryParse(record.createdAt);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.mic_none)),
                title: Text(
                  record.targetText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  createdAt == null
                      ? record.category
                      : '${record.category} · ${DateFormat('dd/MM HH:mm').format(createdAt.toLocal())}',
                ),
                trailing: Text(
                  record.hasScore ? '${record.overallScore}' : '--',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  final int minutes;
  final int sessions;
  final int goalMinutes;
  final int goalSessions;
  final double minutesProgress;
  final double sessionsProgress;

  const _DailyGoalCard({
    required this.minutes,
    required this.sessions,
    required this.goalMinutes,
    required this.goalSessions,
    required this.minutesProgress,
    required this.sessionsProgress,
  });

  @override
  Widget build(BuildContext context) {
    final achieved = minutesProgress >= 1 || sessionsProgress >= 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Mục tiêu hôm nay',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (achieved)
                  const Chip(
                    avatar: Icon(Icons.check_circle, size: 18),
                    label: Text('Đã đạt'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _GoalProgress(
              label: 'Thời gian',
              valueLabel: '$minutes/$goalMinutes phút',
              progress: minutesProgress,
            ),
            const SizedBox(height: 12),
            _GoalProgress(
              label: 'Phiên học',
              valueLabel: '$sessions/$goalSessions phiên',
              progress: sessionsProgress,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalProgress extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double progress;

  const _GoalProgress({
    required this.label,
    required this.valueLabel,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '$valueLabel · ${(progress * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: progress),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _OverviewCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
