import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const int _dailyReminderId = 1001;
  static const int _instantReminderId = 1002;
  static const int _remoteMessageId = 1003;
  static const String _fallbackTimezone = 'Asia/Ho_Chi_Minh';

  static const AndroidNotificationDetails _dailyReminderAndroid =
      AndroidNotificationDetails(
    // Same channel id the Cloud Function targets for FCM reminders.
    'daily_streak_reminder',
    'Nhắc nhở Luyện Tập Hàng Ngày',
    channelDescription:
        'Thông báo nhắc nhở duy trì chuỗi Streak tiếng Anh mỗi ngày',
    importance: Importance.max,
    priority: Priority.high,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  String _timezoneName = _fallbackTimezone;

  /// IANA timezone of this device, e.g. "Asia/Ho_Chi_Minh".
  String get timezoneName => _timezoneName;

  Future<void> init() async {
    tz.initializeTimeZones();
    // Without this tz.local stays UTC and reminders fire at the wrong hour.
    try {
      _timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(_timezoneName));
    } catch (err) {
      debugPrint('Could not resolve local timezone, using fallback: $err');
      _timezoneName = _fallbackTimezone;
      tz.setLocalLocation(tz.getLocation(_fallbackTimezone));
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // Create the channel up front so FCM notifications delivered while the app
    // is in the background use it on Android 8+.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'daily_streak_reminder',
            'Nhắc nhở Luyện Tập Hàng Ngày',
            description:
                'Thông báo nhắc nhở duy trì chuỗi Streak tiếng Anh mỗi ngày',
            importance: Importance.max,
          ),
        );
  }

  /// On-device fallback used when FCM push is unavailable. When push works the
  /// server sends the reminder instead (and skips days already practiced).
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required int streakCount,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: _dailyReminderAndroid,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      _dailyReminderId,
      '🔥 Giữ vững chuỗi $streakCount ngày Streak!',
      'Dành 15 phút luyện phát âm tiếng Anh cùng AI ngay hôm nay nhé!',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_dailyReminderId);
  }

  /// Displays an FCM message received while the app is in the foreground.
  Future<void> showRemoteNotification({
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: _dailyReminderAndroid,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(_remoteMessageId, title, body, details);
  }

  Future<void> showInstantTestNotification(int streakCount) async {
    const androidDetails = AndroidNotificationDetails(
      'instant_reminder',
      'Kiểm thử Thông Báo',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      _instantReminderId,
      '🔥 SpeakMaster: Đã đến giờ luyện phát âm!',
      'Hãy hoàn thành mục tiêu hôm nay để duy trì chuỗi $streakCount ngày liên tiếp.',
      details,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
