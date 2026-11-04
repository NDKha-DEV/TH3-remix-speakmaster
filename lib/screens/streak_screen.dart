import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/learning_stats_service.dart';
import '../services/notification_service.dart';

class StreakScreen extends StatefulWidget {
  final UserProfile userProfile;
  final List<DailyStat> dailyStats;
  final Future<void> Function(
    int minutes,
    int sentences,
    bool reminderEnabled,
    String reminderTime,
  )
  onSaveSettings;

  const StreakScreen({
    super.key,
    required this.userProfile,
    required this.dailyStats,
    required this.onSaveSettings,
  });

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  late int _goalMinutes;
  late int _goalSentences;
  late bool _reminderEnabled;
  late String _reminderTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _goalMinutes = widget.userProfile.dailyGoalMinutes;
    _goalSentences = widget.userProfile.dailyGoalSentences;
    _reminderEnabled = widget.userProfile.reminderEnabled;
    _reminderTime = widget.userProfile.reminderTime;
  }

  @override
  void didUpdateWidget(covariant StreakScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userProfile.dailyGoalMinutes !=
            widget.userProfile.dailyGoalMinutes ||
        oldWidget.userProfile.dailyGoalSentences !=
            widget.userProfile.dailyGoalSentences ||
        oldWidget.userProfile.reminderEnabled !=
            widget.userProfile.reminderEnabled ||
        oldWidget.userProfile.reminderTime != widget.userProfile.reminderTime) {
      _goalMinutes = widget.userProfile.dailyGoalMinutes;
      _goalSentences = widget.userProfile.dailyGoalSentences;
      _reminderEnabled = widget.userProfile.reminderEnabled;
      _reminderTime = widget.userProfile.reminderTime;
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await widget.onSaveSettings(
        _goalMinutes,
        _goalSentences,
        _reminderEnabled,
        _reminderTime,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu cài đặt mục tiêu.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lưu cài đặt: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final activeDays = widget.dailyStats
        .where((stat) => stat.sentencesPracticed > 0)
        .map((stat) => stat.date)
        .toSet();
    final streak = LearningStatsService.calculateStreak(
      practiceDates: activeDays,
      now: now,
      longestStreak: widget.userProfile.longestStreak,
    );
    final todayStat = LearningStatsService.statForDate(
      widget.dailyStats,
      LearningStatsService.dateKey(today),
    );
    final todayMinutes = todayStat?.minutesSpent ?? 0;
    final todaySessions = todayStat?.sentencesPracticed ?? 0;
    final minutesProgress = LearningStatsService.progressRatio(
      todayMinutes,
      widget.userProfile.dailyGoalMinutes,
    );
    final sessionsProgress = LearningStatsService.progressRatio(
      todaySessions,
      widget.userProfile.dailyGoalSentences,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.white,
                    size: 56,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${streak.currentStreak} Ngày Liên Tiếp!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Kỷ lục cao nhất: ${streak.longestStreak} ngày',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(weekDays.length, (index) {
                  final date = DateTime(
                    weekStart.year,
                    weekStart.month,
                    weekStart.day + index,
                  );
                  final practiced = activeDays.contains(
                    LearningStatsService.dateKey(date),
                  );
                  return Column(
                    children: [
                      Text(
                        weekDays[index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: practiced
                            ? Colors.white
                            : Colors.white24,
                        child: practiced
                            ? const Icon(
                                Icons.check,
                                color: Colors.deepOrange,
                                size: 16,
                              )
                            : null,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tiến độ hôm nay',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Thời gian: $todayMinutes/${widget.userProfile.dailyGoalMinutes} phút',
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: minutesProgress),
                const SizedBox(height: 12),
                Text(
                  'Phiên học: $todaySessions/${widget.userProfile.dailyGoalSentences}',
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: sessionsProgress),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đặt Mục Tiêu Hàng Ngày',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Thời gian luyện tập: $_goalMinutes phút/ngày'),
                Slider(
                  value: _goalMinutes.toDouble(),
                  min: 5,
                  max: 30,
                  divisions: 5,
                  label: '$_goalMinutes phút',
                  onChanged: (val) =>
                      setState(() => _goalMinutes = val.round()),
                ),
                Text('Số câu phát âm: $_goalSentences câu/ngày'),
                Slider(
                  value: _goalSentences.toDouble(),
                  min: 5,
                  max: 25,
                  divisions: 4,
                  label: '$_goalSentences câu',
                  onChanged: (val) =>
                      setState(() => _goalSentences = val.round()),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bật thông báo nhắc nhở hàng ngày'),
                  subtitle: Text('Giờ nhắc: $_reminderTime'),
                  value: _reminderEnabled,
                  onChanged: (val) => setState(() => _reminderEnabled = val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => NotificationService()
                                .showInstantTestNotification(
                                  streak.currentStreak,
                                ),
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Thử thông báo'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      child: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Lưu Cài Đặt'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
