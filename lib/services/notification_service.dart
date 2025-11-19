import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  bool _initialized = false;

  static int stableIdFromKey(
    String key, {
    String scope = 'default',
  }) {
    final effectiveKey = '$scope::$key';
    int hash = 5381;
    for (final codeUnit in effectiveKey.codeUnits) {
      hash = ((hash << 5) + hash) ^ codeUnit;
    }
    return hash & 0x7fffffff;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('Notifications disabled: initialize() called.');
  }

  void setGlobalResponseHandler(Function(dynamic) handler) {
    debugPrint('Notifications disabled: setGlobalResponseHandler ignored.');
  }

  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    debugPrint('Notifications disabled: scheduleNotification skipped for $title.');
    return false;
  }

  Future<void> cancelNotification(int id) async {
    debugPrint('Notifications disabled: cancelNotification ignored for $id.');
  }

  Future<void> cancelAllNotifications() async {
    debugPrint('Notifications disabled: cancelAllNotifications ignored.');
  }

  Future<bool> showTestNotification() async {
    debugPrint('Notifications disabled: showTestNotification skipped.');
    return false;
  }

  Future<bool> showChatNotification({
    required int id,
    required String title,
    required String body,
    required String communityId,
    required String communityName,
    String? payload,
  }) async {
    debugPrint('Notifications disabled: showChatNotification skipped for $communityName.');
    return false;
  }

  Future<bool> testScheduledNotification() async {
    debugPrint('Notifications disabled: testScheduledNotification skipped.');
    return false;
  }
}
