import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/learning_stats_service.dart';
import '../services/pronunciation_engine.dart';
import 'assessment_history_screen.dart';

class AnalyticsScreen extends StatelessWidget {
  final UserProfile userProfile;
  final List<PracticeRecord> history;
  final List<DailyStat> dailyStats;
  final PronunciationEngine engine;

  const AnalyticsScreen({
    super.key,
    required this.userProfile,
    required this.history,
    required this.dailyStats,
    required this.engine,
  });

  @override
  Widget build(BuildContext context) {
    final averageScore = LearningStatsService.averageScore(
      history.map<int?>(
        (record) => record.hasScore ? record.overallScore : null,
      ),
    );
    final totalMinutes = LearningStatsService.totalMinutes(dailyStats);
    final cardWidth = (MediaQuery.sizeOf(context).width - 44) / 2;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _StatCard(
                title: 'Điểm phát âm TB',
                value: averageScore == null ? '--' : '$averageScore/100',
                icon: Icons.auto_graph,
                color: Colors.teal,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _StatCard(
                title: 'Tổng phiên học',
                value: '${history.length}',
                icon: Icons.mic_none,
                color: Colors.blue,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _StatCard(
                title: 'Thời gian học',
                value: '$totalMinutes phút',
                icon: Icons.timer_outlined,
                color: Colors.deepPurple,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _StatCard(
                title: 'Tổng XP',
                value: '${userProfile.totalXp} XP',
                icon: Icons.emoji_events_outlined,
                color: Colors.amber.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Hoạt động 7 ngày gần nhất',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _DailyActivityChart(dailyStats: dailyStats),
        const SizedBox(height: 20),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: const Icon(Icons.manage_search, color: Colors.teal),
            title: const Text(
              'Lịch sử chấm AI & âm hay sai',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Xem lại phân tích từng âm vị của mỗi lần chấm'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AssessmentHistoryScreen(engine: engine),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Lịch sử phiên học',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (history.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Chưa có lịch sử luyện tập. Hãy hoàn thành phiên đầu tiên!',
              ),
            ),
          )
        else
          ...history.map((record) {
            final createdAt = DateTime.tryParse(record.createdAt);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                onTap: record.assessmentId == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AssessmentDetailScreen(
                              engine: engine,
                              assessmentId: record.assessmentId!,
                            ),
                          ),
                        ),
                title: Text(
                  record.targetText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  createdAt == null
                      ? record.feedback
                      : '${record.feedback}\n${DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toLocal())}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: CircleAvatar(
                  backgroundColor: !record.hasScore || record.overallScore < 80
                      ? Colors.amber.shade700
                      : Colors.teal,
                  child: Text(
                    record.hasScore ? '${record.overallScore}' : '--',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _DailyActivityChart extends StatelessWidget {
  final List<DailyStat> dailyStats;

  const _DailyActivityChart({required this.dailyStats});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day - 6);
    final byDate = {for (final stat in dailyStats) stat.date: stat};
    final days = List.generate(
      7,
      (index) => DateTime(start.year, start.month, start.day + index),
    );
    final maxMinutes = days.fold<int>(0, (maximum, day) {
      final minutes =
          byDate[LearningStatsService.dateKey(day)]?.minutesSpent ?? 0;
      return minutes > maximum ? minutes : maximum;
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: days.map((day) {
            final stat = byDate[LearningStatsService.dateKey(day)];
            final minutes = stat?.minutesSpent ?? 0;
            final progress = maxMinutes == 0 ? 0.0 : minutes / maxMinutes;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(DateFormat('dd/MM').format(day)),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: Text(
                      '${minutes}p · ${stat?.sentencesPracticed ?? 0} phiên',
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
