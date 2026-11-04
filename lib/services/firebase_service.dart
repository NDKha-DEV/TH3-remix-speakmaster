import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/models.dart';
import 'learning_stats_service.dart';
import 'notification_service.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Enables the on-device cache so profile, history and streak data load
  /// offline and practice results queue until the network is back.
  /// Must run once, before the first Firestore read or write.
  static void configurePersistence() {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Đăng nhập bằng Email & Password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (cred.user != null) {
      await getOrCreateUserProfile(cred.user!);
    }
    return cred;
  }

  // Đăng ký tài khoản mới bằng Email & Password
  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (cred.user != null) {
      await cred.user!.updateDisplayName(displayName);
      await getOrCreateUserProfile(cred.user!);
    }
    return cred;
  }

  // Đăng nhập bằng Google
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);
    if (cred.user != null) {
      await getOrCreateUserProfile(cred.user!);
    }
    return cred;
  }

  // Đăng xuất
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  // Lấy hoặc khởi tạo hồ sơ người dùng trên Firestore
  Future<UserProfile> getOrCreateUserProfile(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    final snap = await docRef.get();

    final timezone = NotificationService().timezoneName;

    if (snap.exists && snap.data() != null) {
      final profile = UserProfile.fromMap(snap.data()!);
      // Keep the stored timezone in sync so the daily reminder fires at local time.
      if (profile.timezone != timezone) {
        await updateUserProfile(user.uid, {'timezone': timezone});
        return profile.copyWith(timezone: timezone);
      }
      return profile;
    }

    final newProfile = UserProfile(
      id: user.uid,
      email: user.email ?? 'student@speakmaster.edu.vn',
      displayName: user.displayName ?? 'Học viên SpeakMaster',
      photoURL: user.photoURL,
      dailyGoalMinutes: 15,
      dailyGoalSentences: 10,
      streakCount: 0,
      longestStreak: 0,
      lastActiveDate: '',
      totalXp: 150,
      level: 1,
      reminderTime: '20:00',
      reminderEnabled: true,
      timezone: timezone,
    );

    await docRef.set({
      ...newProfile.toMap(),
      'createdAt': DateTime.now().toIso8601String(),
    });
    return newProfile;
  }

  // Cập nhật cài đặt mục tiêu và nhắc nhở
  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    await _db.collection('users').doc(userId).update({
      ...updates,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // Lưu kết quả phân tích phát âm và cập nhật chuỗi Streak
  Future<void> recordPracticeSession({
    required String userId,
    required PracticeRecord record,
    required int minutesAdded,
  }) async {
    final userRef = _db.collection('users').doc(userId);
    final recordRef = userRef.collection('practice_records').doc(record.id);
    final today = LearningStatsService.dateKey(DateTime.now());
    final statRef = userRef.collection('daily_stats').doc(today);
    await _db.runTransaction((transaction) async {
      final recordSnapshot = await transaction.get(recordRef);
      if (recordSnapshot.exists) return;

      final profileSnapshot = await transaction.get(userRef);
      final statSnapshot = await transaction.get(statRef);
      final profileData = profileSnapshot.data();
      if (!profileSnapshot.exists || profileData == null) {
        throw StateError(
          'Cannot record a practice session without a user profile.',
        );
      }

      final profile = UserProfile.fromMap(profileData);
      final currentStat = statSnapshot.data() == null
          ? null
          : DailyStat.fromMap(statSnapshot.data()!);
      final updatedStat = LearningStatsService.addCompletedSession(
        currentStat: currentStat,
        userId: userId,
        date: today,
        minutesAdded: minutesAdded,
        score: record.overallScore,
        dailyGoalMinutes: profile.dailyGoalMinutes,
        dailyGoalSentences: profile.dailyGoalSentences,
      );
      final newStreak = LearningStatsService.streakAfterPractice(
        lastActiveDate: profile.lastActiveDate,
        currentStreak: profile.streakCount,
        today: today,
      );
      final streakIncreased = profile.lastActiveDate != today;
      final longestStreak =
          newStreak > profile.longestStreak ? newStreak : profile.longestStreak;
      final addedXp =
          (record.overallScore * 1.5).round() + (streakIncreased ? 50 : 20);
      final totalXp = profile.totalXp + addedXp;

      transaction.set(recordRef, record.toMap());
      transaction.set(statRef, updatedStat.toMap());
      transaction.update(userRef, {
        'streakCount': newStreak,
        'longestStreak': longestStreak,
        'lastActiveDate': today,
        'totalXp': totalXp,
        'level': (totalXp ~/ 500) + 1,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    });
  }

  // Lưu FCM token của thiết bị (doc id = token để ghi lại không bị trùng)
  Future<void> saveFcmToken({
    required String userId,
    required String token,
    required String platform,
    required String timezone,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db
        .collection('users')
        .doc(userId)
        .collection('fcm_tokens')
        .doc(token)
        .set({
      'token': token,
      'platform': platform,
      'timezone': timezone,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> deleteFcmToken(String userId, String token) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('fcm_tokens')
        .doc(token)
        .delete();
  }

  // Lấy lịch sử luyện phát âm
  Future<List<PracticeRecord>> fetchPracticeHistory(String userId) async {
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('practice_records')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => PracticeRecord.fromMap(d.data())).toList();
  }

  Future<List<DailyStat>> fetchDailyStats(String userId) async {
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('daily_stats')
        .orderBy('date')
        .get();
    return snap.docs.map((d) => DailyStat.fromMap(d.data())).toList();
  }

  // Lấy thống kê 7 ngày gần nhất
  Future<List<DailyStat>> fetchRecentDailyStats(String userId) async {
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('daily_stats')
        .orderBy('date', descending: true)
        .limit(7)
        .get();
    return snap.docs
        .map((d) => DailyStat.fromMap(d.data()))
        .toList()
        .reversed
        .toList();
  }
}
