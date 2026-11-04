import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? photoURL;
  final int dailyGoalMinutes;
  final int dailyGoalSentences;
  final int streakCount;
  final int longestStreak;
  final String lastActiveDate;
  final int totalXp;
  final int level;
  final String reminderTime;
  final bool reminderEnabled;
  // IANA timezone (e.g. "Asia/Ho_Chi_Minh") used by the server-side reminder.
  final String? timezone;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoURL,
    this.dailyGoalMinutes = 15,
    this.dailyGoalSentences = 10,
    this.streakCount = 1,
    this.longestStreak = 1,
    required this.lastActiveDate,
    this.totalXp = 100,
    this.level = 1,
    this.reminderTime = '20:00',
    this.reminderEnabled = true,
    this.timezone,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? 'Học viên SpeakMaster',
      photoURL: map['photoURL'],
      dailyGoalMinutes: (map['dailyGoalMinutes'] ?? 15).toInt(),
      dailyGoalSentences: (map['dailyGoalSentences'] ?? 10).toInt(),
      streakCount: (map['streakCount'] ?? 1).toInt(),
      longestStreak: (map['longestStreak'] ?? 1).toInt(),
      lastActiveDate: map['lastActiveDate'] ?? '',
      totalXp: (map['totalXp'] ?? 100).toInt(),
      level: (map['level'] ?? 1).toInt(),
      reminderTime: map['reminderTime'] ?? '20:00',
      reminderEnabled: map['reminderEnabled'] ?? true,
      timezone: map['timezone'],
    );
  }

  UserProfile copyWith({
    int? dailyGoalMinutes,
    int? dailyGoalSentences,
    String? reminderTime,
    bool? reminderEnabled,
    String? timezone,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName,
      photoURL: photoURL,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      dailyGoalSentences: dailyGoalSentences ?? this.dailyGoalSentences,
      streakCount: streakCount,
      longestStreak: longestStreak,
      lastActiveDate: lastActiveDate,
      totalXp: totalXp,
      level: level,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      timezone: timezone ?? this.timezone,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'dailyGoalMinutes': dailyGoalMinutes,
      'dailyGoalSentences': dailyGoalSentences,
      'streakCount': streakCount,
      'longestStreak': longestStreak,
      'lastActiveDate': lastActiveDate,
      'totalXp': totalXp,
      'level': level,
      'reminderTime': reminderTime,
      'reminderEnabled': reminderEnabled,
      if (timezone != null) 'timezone': timezone,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}

class PhonemeBreakdown {
  final String symbol;
  final String status; // 'correct' | 'warning' | 'incorrect'
  final String? tip;

  PhonemeBreakdown({
    required this.symbol,
    required this.status,
    this.tip,
  });

  factory PhonemeBreakdown.fromJson(Map<String, dynamic> json) {
    return PhonemeBreakdown(
      symbol: json['symbol'] ?? '',
      status: json['status'] ?? 'correct',
      tip: json['tip'],
    );
  }
}

class WordAnalysis {
  final String word;
  final String expectedIpa;
  final String detectedIpa;
  final int score;
  final String status; // 'correct' | 'warning' | 'incorrect'
  final String errorType;
  final List<PhonemeBreakdown> phonemes;
  final String specificError;

  WordAnalysis({
    required this.word,
    required this.expectedIpa,
    required this.detectedIpa,
    required this.score,
    required this.status,
    required this.errorType,
    required this.phonemes,
    required this.specificError,
  });

  factory WordAnalysis.fromJson(Map<String, dynamic> json) {
    return WordAnalysis(
      word: json['word'] ?? '',
      expectedIpa: json['expectedIpa'] ?? '',
      detectedIpa: json['detectedIpa'] ?? '',
      score: (json['score'] ?? 0).toInt(),
      status: json['status'] ?? 'correct',
      errorType: json['errorType'] ?? 'none',
      phonemes: (json['phonemes'] as List<dynamic>? ?? [])
          .map((p) => PhonemeBreakdown.fromJson(p as Map<String, dynamic>))
          .toList(),
      specificError: json['specificError'] ?? '',
    );
  }
}

class PronunciationResult {
  final int overallScore;
  final int accuracyScore;
  final int fluencyScore;
  final int completenessScore;
  final String expectedIpa;
  final String vietnameseSummary;
  final String tongueMouthAdvice;
  final List<WordAnalysis> wordAnalysis;
  final List<String> recommendedDrills;

  PronunciationResult({
    required this.overallScore,
    required this.accuracyScore,
    required this.fluencyScore,
    required this.completenessScore,
    required this.expectedIpa,
    required this.vietnameseSummary,
    required this.tongueMouthAdvice,
    required this.wordAnalysis,
    required this.recommendedDrills,
  });

  factory PronunciationResult.fromJson(Map<String, dynamic> json) {
    return PronunciationResult(
      overallScore: (json['overallScore'] ?? 0).toInt(),
      accuracyScore: (json['accuracyScore'] ?? 0).toInt(),
      fluencyScore: (json['fluencyScore'] ?? 0).toInt(),
      completenessScore: (json['completenessScore'] ?? 0).toInt(),
      expectedIpa: json['expectedIpa'] ?? '',
      vietnameseSummary: json['vietnameseSummary'] ?? '',
      tongueMouthAdvice: json['tongueMouthAdvice'] ?? '',
      wordAnalysis: (json['wordAnalysis'] as List<dynamic>? ?? [])
          .map((w) => WordAnalysis.fromJson(w as Map<String, dynamic>))
          .toList(),
      recommendedDrills: (json['recommendedDrills'] as List<dynamic>? ?? [])
          .map((d) => d.toString())
          .toList(),
    );
  }
}

class PracticeRecord {
  final String id;
  final String userId;
  final String targetText;
  final String category;
  final String difficulty;
  final int overallScore;
  final int accuracyScore;
  final int fluencyScore;
  final int completenessScore;
  final String expectedIpa;
  final String feedback;
  final String? tongueMouthAdvice;
  final String createdAt;
  final bool hasScore;

  /// Id lần chấm M4 (Pronunciation API `Attempt.id`) để mở lại chi tiết.
  final String? assessmentId;

  /// api | gemini | ruleBased — nguồn chấm điểm của phiên này.
  final String? scoringSource;

  PracticeRecord({
    required this.id,
    required this.userId,
    required this.targetText,
    required this.category,
    required this.difficulty,
    required this.overallScore,
    required this.accuracyScore,
    required this.fluencyScore,
    required this.completenessScore,
    required this.expectedIpa,
    required this.feedback,
    this.tongueMouthAdvice,
    required this.createdAt,
    this.hasScore = true,
    this.assessmentId,
    this.scoringSource,
  });

  factory PracticeRecord.fromMap(Map<String, dynamic> map) {
    return PracticeRecord(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      targetText: map['targetText'] ?? '',
      category: map['category'] ?? 'General',
      difficulty: map['difficulty'] ?? 'Intermediate',
      overallScore: (map['overallScore'] ?? 0).toInt(),
      accuracyScore: (map['accuracyScore'] ?? 0).toInt(),
      fluencyScore: (map['fluencyScore'] ?? 0).toInt(),
      completenessScore: (map['completenessScore'] ?? 0).toInt(),
      expectedIpa: map['expectedIpa'] ?? '',
      feedback: map['feedback'] ?? '',
      tongueMouthAdvice: map['tongueMouthAdvice'],
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      hasScore: map['overallScore'] is num,
      assessmentId: map['assessmentId'],
      scoringSource: map['scoringSource'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'targetText': targetText,
      'category': category,
      'difficulty': difficulty,
      'overallScore': overallScore,
      'accuracyScore': accuracyScore,
      'fluencyScore': fluencyScore,
      'completenessScore': completenessScore,
      'expectedIpa': expectedIpa,
      'feedback': feedback,
      'tongueMouthAdvice': tongueMouthAdvice,
      'createdAt': createdAt,
      if (assessmentId != null) 'assessmentId': assessmentId,
      if (scoringSource != null) 'scoringSource': scoringSource,
    };
  }
}

class DailyStat {
  final String id;
  final String userId;
  final String date;
  final int minutesSpent;
  final int sentencesPracticed;
  final int averageScore;
  final bool goalAchieved;

  DailyStat({
    required this.id,
    required this.userId,
    required this.date,
    required this.minutesSpent,
    required this.sentencesPracticed,
    required this.averageScore,
    required this.goalAchieved,
  });

  factory DailyStat.fromMap(Map<String, dynamic> map) {
    return DailyStat(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      date: map['date'] ?? '',
      minutesSpent: (map['minutesSpent'] ?? 0).toInt(),
      sentencesPracticed: (map['sentencesPracticed'] ?? 0).toInt(),
      averageScore: (map['averageScore'] ?? 0).toInt(),
      goalAchieved: map['goalAchieved'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': date,
      'minutesSpent': minutesSpent,
      'sentencesPracticed': sentencesPracticed,
      'averageScore': averageScore,
      'goalAchieved': goalAchieved,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}

class LessonSentence {
  final String id;
  final String text;
  final String translation;
  final String ipa;
  final String category;
  final String difficulty;
  final String focusSound;
  final String tips;

  const LessonSentence({
    required this.id,
    required this.text,
    required this.translation,
    required this.ipa,
    required this.category,
    required this.difficulty,
    required this.focusSound,
    required this.tips,
  });
}
