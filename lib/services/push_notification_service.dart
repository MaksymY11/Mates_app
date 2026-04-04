import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class PushNotificationService {
  /// Singleton service managing FCM push notifications.
  /// Handles permission, token registration, and background tap data.
  /// Only active on Android, iOS, and web; Desktop platforms are skipped.
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();

  bool _initialized = false;
  static Map<String, dynamic>? pendingNotificationData;

  Future<void> initialize() async {
    /// Request notification permission, register device token, and listen for refreshes.
    /// Safe to call multiple times — guarded by [_initialized]
    if (_initialized || !isSupported) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        pendingNotificationData = initialMessage.data;
      }

      await registerDevice();

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        registerDevice();
      });

      _initialized = true;
    } catch (e) {
      print('[PUSH] Initialization failed: $e');
    }
  }

  static bool get isSupported {
    /// Whether the current platform supports FCM push notifications.
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> registerDevice() async {
    /// Get the FCM token and send it to the backend with the platform identifier.
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      String platform;
      if (kIsWeb) {
        platform = 'web';
      } else if (Platform.isAndroid) {
        platform = 'android';
      } else {
        platform = 'ios';
      }
      await ApiService.post(
        '/devices/register',
        body: {'fcm_token': fcmToken, 'platform': platform},
      );
    } catch (e) {
      print("[PUSH] Register failed: $e");
    }
  }

  Future<void> unregisterDevice() async {
    /// Remove the FCM token from the backend. Called on logout.
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      await ApiService.post(
        '/devices/unregister',
        body: {'fcm_token': fcmToken},
      );
    } catch (e) {
      print("[PUSH] Unregister failed: $e");
    }
  }
}
