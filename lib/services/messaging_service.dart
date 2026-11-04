import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_service.dart';
import 'notification_service.dart';

// Must be a top-level function: runs in a separate isolate when a push arrives
// while the app is terminated/backgrounded. Notification payloads are shown by
// the OS, so we only need Firebase initialised for any data handling.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Registers the device for FCM push and keeps its token in
/// users/{uid}/fcm_tokens so the `sendDailyReminders` Cloud Function can reach it.
class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseService _firebaseService = FirebaseService();

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  String? _currentToken;

  /// Returns true when push is enabled and the token was stored.
  Future<bool> registerForUser(String userId) async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        return false;
      }

      final token = await _messaging.getToken(
        vapidKey:
            kIsWeb ? const String.fromEnvironment('FIREBASE_VAPID_KEY') : null,
      );
      if (token == null) return false;

      await _saveToken(userId, token);

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
        final oldToken = _currentToken;
        await _saveToken(userId, newToken);
        if (oldToken != null && oldToken != newToken) {
          await _firebaseService.deleteFcmToken(userId, oldToken);
        }
      });

      // Android/iOS do not display notification payloads while the app is in
      // the foreground, so mirror them through the local notification plugin.
      await _foregroundSub?.cancel();
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;
        NotificationService().showRemoteNotification(
          title: notification.title ?? 'SpeakMaster',
          body: notification.body ?? '',
        );
      });
      return true;
    } catch (err) {
      debugPrint('FCM registration failed: $err');
      return false;
    }
  }

  /// Call before signing out so this device stops receiving the user's reminders.
  Future<void> unregister(String userId) async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub = null;
    final token = _currentToken;
    _currentToken = null;
    if (token == null) return;
    try {
      await _firebaseService.deleteFcmToken(userId, token);
      await _messaging.deleteToken();
    } catch (err) {
      debugPrint('FCM unregister failed: $err');
    }
  }

  Future<void> _saveToken(String userId, String token) async {
    _currentToken = token;
    await _firebaseService.saveFcmToken(
      userId: userId,
      token: token,
      platform: _platformName(),
      timezone: NotificationService().timezoneName,
    );
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'unknown';
    }
  }
}
