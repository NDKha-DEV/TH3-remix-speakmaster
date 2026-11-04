import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models/models.dart';
import 'services/firebase_service.dart';
import 'services/ai_pronunciation_service.dart';
import 'services/notification_service.dart';
import 'screens/auth_screen.dart';
import 'screens/pronunciation_screen.dart';
import 'screens/streak_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/learning_stats_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService().init();
  runApp(const SpeakMasterApp());
}

class SpeakMasterApp extends StatelessWidget {
  const SpeakMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpeakMaster - AI English & Streak',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          brightness: Brightness.dark,
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final FirebaseService _firebaseService = FirebaseService();
  final AIPronunciationService _aiService = AIPronunciationService(
    apiKey: const String.fromEnvironment('GEMINI_API_KEY', defaultValue: ''),
  );

  int _selectedIndex = 0;
  bool _guestMode = false;
  UserProfile? _userProfile;
  List<PracticeRecord> _history = [];
  List<DailyStat> _dailyStats = [];

  @override
  void initState() {
    super.initState();
    _firebaseService.authStateChanges.listen((User? user) async {
      if (user != null) {
        final profile = await _firebaseService.getOrCreateUserProfile(user);
        final history = await _firebaseService.fetchPracticeHistory(user.uid);
        final stats = await _firebaseService.fetchDailyStats(user.uid);
        if (mounted) {
          setState(() {
            _userProfile = profile;
            _history = history;
            _dailyStats = stats;
          });
        }
      } else if (!_guestMode) {
        if (mounted) {
          setState(() => _userProfile = null);
        }
      }
    });
  }

  void _enableGuestMode() {
    setState(() {
      _guestMode = true;
      _userProfile = UserProfile(
        id: 'guest_student',
        email: 'sinhvien@speakmaster.edu.vn',
        displayName: 'Sinh viên SpeakMaster',
        streakCount: 0,
        longestStreak: 0,
        lastActiveDate: '',
        totalXp: 0,
        level: 1,
      );
      _history = [];
      _dailyStats = [];
    });
  }

  Future<void> _handlePracticeCompleted(
    int minutes,
    int score,
    PronunciationResult result,
    LessonSentence sentence,
  ) async {
    if (_userProfile == null) return;

    final record = PracticeRecord(
      id: 'rec_${DateTime.now().microsecondsSinceEpoch}',
      userId: _userProfile!.id,
      targetText: sentence.text,
      category: sentence.category,
      difficulty: sentence.difficulty,
      overallScore: score,
      accuracyScore: result.accuracyScore,
      fluencyScore: result.fluencyScore,
      completenessScore: result.completenessScore,
      expectedIpa: result.expectedIpa,
      feedback: result.vietnameseSummary,
      tongueMouthAdvice: result.tongueMouthAdvice,
      createdAt: DateTime.now().toIso8601String(),
    );
    final today = LearningStatsService.dateKey(DateTime.now());
    final currentStat = LearningStatsService.statForDate(_dailyStats, today);
    final updatedStat = LearningStatsService.addCompletedSession(
      currentStat: currentStat,
      userId: _userProfile!.id,
      date: today,
      minutesAdded: minutes,
      score: score,
      dailyGoalMinutes: _userProfile!.dailyGoalMinutes,
      dailyGoalSentences: _userProfile!.dailyGoalSentences,
    );

    if (mounted)
      setState(() {
        _history = [record, ..._history];
        _dailyStats = [
          ..._dailyStats.where((stat) => stat.date != today),
          updatedStat,
        ]..sort((a, b) => a.date.compareTo(b.date));
      });

    if (_firebaseService.currentUser != null) {
      await _firebaseService.recordPracticeSession(
        userId: _firebaseService.currentUser!.uid,
        record: record,
        minutesAdded: minutes,
      );
      final updatedProfile = await _firebaseService.getOrCreateUserProfile(
        _firebaseService.currentUser!,
      );
      final updatedStats = await _firebaseService.fetchDailyStats(
        _firebaseService.currentUser!.uid,
      );
      if (mounted) {
        setState(() {
          _userProfile = updatedProfile;
          _dailyStats = updatedStats;
        });
      }
    }
  }

  Future<void> _handleSaveSettings(
    int minutes,
    int sentences,
    bool reminderEnabled,
    String reminderTime,
  ) async {
    if (_userProfile == null) return;
    if (_firebaseService.currentUser != null) {
      await _firebaseService.updateUserProfile(
        _firebaseService.currentUser!.uid,
        {
          'dailyGoalMinutes': minutes,
          'dailyGoalSentences': sentences,
          'reminderEnabled': reminderEnabled,
          'reminderTime': reminderTime,
        },
      );
    }
    final currentProfile = _userProfile!;
    if (mounted) {
      setState(() {
        _userProfile = UserProfile(
          id: currentProfile.id,
          email: currentProfile.email,
          displayName: currentProfile.displayName,
          photoURL: currentProfile.photoURL,
          dailyGoalMinutes: minutes,
          dailyGoalSentences: sentences,
          streakCount: currentProfile.streakCount,
          longestStreak: currentProfile.longestStreak,
          lastActiveDate: currentProfile.lastActiveDate,
          totalXp: currentProfile.totalXp,
          level: currentProfile.level,
          reminderTime: reminderTime,
          reminderEnabled: reminderEnabled,
        );
      });
    }
    if (reminderEnabled) {
      final parts = reminderTime.split(':');
      final hour = int.tryParse(parts[0]) ?? 20;
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      await NotificationService().scheduleDailyReminder(
        hour: hour,
        minute: minute,
        streakCount: LearningStatsService.calculateStreak(
          practiceDates: _dailyStats
              .where((stat) => stat.sentencesPracticed > 0)
              .map((stat) => stat.date),
          now: DateTime.now(),
          longestStreak: currentProfile.longestStreak,
        ).currentStreak,
      );
    } else {
      await NotificationService().cancelAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userProfile == null) {
      return AuthScreen(
        firebaseService: _firebaseService,
        onGuestContinue: _enableGuestMode,
      );
    }

    final streak = LearningStatsService.calculateStreak(
      practiceDates: _dailyStats
          .where((stat) => stat.sentencesPracticed > 0)
          .map((stat) => stat.date),
      now: DateTime.now(),
      longestStreak: _userProfile!.longestStreak,
    );
    final screens = [
      DashboardScreen(
        userProfile: _userProfile!,
        history: _history,
        dailyStats: _dailyStats,
        onOpenPractice: () => setState(() => _selectedIndex = 1),
      ),
      PronunciationScreen(
        aiService: _aiService,
        onPracticeCompleted: _handlePracticeCompleted,
      ),
      StreakScreen(
        userProfile: _userProfile!,
        dailyStats: _dailyStats,
        onSaveSettings: _handleSaveSettings,
      ),
      AnalyticsScreen(
        userProfile: _userProfile!,
        history: _history,
        dailyStats: _dailyStats,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SpeakMaster AI',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '${streak.currentStreak} ngày',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Đăng xuất Firebase',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _firebaseService.signOut();
              setState(() {
                _guestMode = false;
                _userProfile = null;
              });
            },
          ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'Luyện phát âm',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Chuỗi Streak',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Tiến độ & Điểm',
          ),
        ],
      ),
    );
  }
}
