// notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Generates a deterministic (and platform-stable) notification id from
  /// a unique string key. This avoids relying on `hashCode`, whose value can
  /// change across app launches and lead to duplicate or orphaned schedules.
  static int stableIdFromKey(
    String key, {
    String scope = 'default',
  }) {
    final effectiveKey = '$scope::$key';
    int hash = 5381;
    for (final codeUnit in effectiveKey.codeUnits) {
      hash =
          ((hash <<
                  5) +
              hash) ^
          codeUnit; // djb2 with xor for better spread
    }
    return hash &
        0x7fffffff; // keep it positive and within 32-bit range
  }

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Expose notifications plugin for fallback use
  FlutterLocalNotificationsPlugin get notifications => _notifications;

  /// Initialize the notification service
  Future<
    void
  >
  initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(
        tz.getLocation(
          'Asia/Kolkata',
        ),
      );
      print(
        '✅ Timezone set to IST (Asia/Kolkata)',
      );
    } catch (
      e
    ) {
      print(
        '⚠️ Could not set IST timezone, using system default: $e',
      );
    }

    // Android initialization settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android (required for notifications to show)
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation !=
        null) {
      // Create the goal reminders notification channel
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'goal_reminders',
          'Goal Reminders',
          description: 'Notifications for goal reminders',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
      
      // Create the community chat notification channel
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'community_chat',
          'Community Chat',
          description: 'Notifications for community chat messages',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
      
      print(
        '✅ Notification channels created',
      );
    }

    // Request permissions (Android 13+)
    bool permissionGranted = false;
    if (androidImplementation != null) {
      try {
        permissionGranted = await androidImplementation.requestNotificationsPermission() ?? false;
        print(
          '📱 Notification permission request result: $permissionGranted',
        );
      } catch (e) {
        print(
          '⚠️ Error requesting notification permission: $e',
        );
      }
      
      // Request exact alarms permission (required for precise scheduling on Android 12+)
      try {
        final exactAlarmGranted = await androidImplementation.requestExactAlarmsPermission();
        print(
          '⏰ Exact alarm permission: $exactAlarmGranted',
        );
      } catch (e) {
        print(
          '⚠️ Exact alarm permission request failed (may not be needed on this device): $e',
        );
      }
    }

    if (permissionGranted) {
      print(
        '✅ Notification permission granted',
      );
    } else {
      print(
        '⚠️ Notification permission not granted - notifications may not work',
      );
      print(
        '   Please grant notification permission in device settings',
      );
    }

    _initialized = true;
  }

  // Global handler for notification responses (can be set from app level)
  Function(NotificationResponse)? _globalResponseHandler;
  
  /// Set global notification response handler
  void setGlobalResponseHandler(Function(NotificationResponse) handler) {
    _globalResponseHandler = handler;
  }
  
  /// Handle notification tap
  void _onNotificationTapped(
    NotificationResponse response,
  ) {
    // Handle notification tap if needed
    print(
      '📱 Notification response: ${response.payload}',
    );
    print(
      '   Action ID: ${response.actionId}',
    );
    print(
      '   Input: ${response.input}',
    );
    
    // Call global handler if set
    if (_globalResponseHandler != null) {
      _globalResponseHandler!(response);
    }
  }

  /// Schedule a notification for a specific date and time
  Future<
    bool
  >
  scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Prevent duplicate scheduled notifications for the same id.
    try {
      final pendingBefore = await getPendingNotifications();
      if (pendingBefore.any(
        (
          n,
        ) =>
            n.id ==
            id,
      )) {
        // ✅ Fixed: added n.id ==
        print(
          '🔁 Found existing pending notification with id $id — cancelling it before scheduling a new one',
        );
        await cancelNotification(
          id,
        );
      }
    } catch (
      e
    ) {
      print(
        '⚠️ Could not check/cancel existing pending notifications: $e',
      );
      // Continue and attempt to schedule anyway
    }

    try {
      // Get IST timezone location
      final istLocation = tz.getLocation(
        'Asia/Kolkata',
      );

      // Ensure we're working with IST timezone
      DateTime localDateTime;
      if (scheduledDate.isUtc) {
        localDateTime = scheduledDate.toLocal();
      } else {
        localDateTime = scheduledDate;
      }

      // Convert DateTime to TZDateTime in IST timezone
      final tz.TZDateTime scheduledTime = tz.TZDateTime.from(
        localDateTime,
        istLocation,
      );

      final now = tz.TZDateTime.now(
        istLocation,
      );

      // Debug logging
      print(
        '📅 Notification scheduling details (IST):',
      );
      print(
        '   Input DateTime (UTC): ${scheduledDate.toUtc()}',
      );
      print(
        '   Input DateTime (Local): $localDateTime',
      );
      print(
        '   Scheduled Time (IST): $scheduledTime',
      );
      print(
        '   Current Time (IST): $now',
      );
      print(
        '   Time until notification: ${scheduledTime.difference(now).inMinutes} minutes',
      );

      // Check if the scheduled time is too far in the past (more than 1 hour)
      // Allow scheduling if it's within the last hour (might be due to timezone or slight delays)
      tz.TZDateTime adjustedScheduledTime = scheduledTime;
      final timeDifference = now.difference(scheduledTime);
      
      if (timeDifference.inHours > 1) {
        print(
          '⚠️ Cannot schedule notification too far in the past (more than 1 hour)',
        );
        print(
          '   Scheduled: $scheduledTime',
        );
        print(
          '   Now: $now',
        );
        print(
          '   Difference: ${timeDifference.inHours} hours ${timeDifference.inMinutes % 60} minutes ago',
        );
        return false;
      } else if (scheduledTime.isBefore(now)) {
        // If it's within the last hour, adjust to schedule for 1 minute from now
        adjustedScheduledTime = now.add(const Duration(minutes: 1));
        print(
          '⚠️ Scheduled time is slightly in the past, adjusting to 1 minute from now',
        );
        print(
          '   Original scheduled: $scheduledTime',
        );
        print(
          '   Adjusted to: $adjustedScheduledTime',
        );
      }

      // Android notification details
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'goal_reminders',
        'Goal Reminders',
        channelDescription: 'Notifications for goal reminders',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      // iOS notification details
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Combined notification details
      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Try exact alarms first (more reliable for precise timing)
      // Fallback to inexact if exact fails (no permission)
      bool scheduled = false;
      try {
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          adjustedScheduledTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        print(
          '   📌 Scheduled with EXACT alarm mode',
        );
        scheduled = true;
      } catch (
        e
      ) {
        print(
          '   ⚠️ Exact alarm failed (may need permission), trying inexact: $e',
        );
        try {
          // Fallback to inexact if exact fails
          await _notifications.zonedSchedule(
            id,
            title,
            body,
            adjustedScheduledTime,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
          print(
            '   📌 Scheduled with INEXACT alarm mode (may have delay)',
          );
          scheduled = true;
        } catch (e2) {
          print(
            '   ❌ Both exact and inexact scheduling failed: $e2',
          );
          // Last resort: try without allowWhileIdle
          try {
            await _notifications.zonedSchedule(
              id,
              title,
              body,
              adjustedScheduledTime,
              notificationDetails,
              androidScheduleMode: AndroidScheduleMode.inexact,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              payload: payload,
            );
            print(
              '   📌 Scheduled with basic INEXACT mode',
            );
            scheduled = true;
          } catch (e3) {
            print(
              '   ❌ All scheduling methods failed: $e3',
            );
            return false;
          }
        }
      }
      
      if (!scheduled) {
        return false;
      }

      print(
        '✅ Notification scheduled successfully!',
      );
      print(
        '   ID: $id',
      );
      print(
        '   Scheduled for: $adjustedScheduledTime (IST)',
      );
      print(
        '   Title: $title',
      );

      // Verify it was scheduled by checking pending notifications
      try {
        // Wait a moment for the notification to be registered
        await Future.delayed(
          const Duration(
            milliseconds: 500,
          ),
        );
        final pending = await getPendingNotifications();
        print(
          '   📋 Total pending notifications: ${pending.length}',
        );

        final thisNotification = pending.firstWhere(
          (
            n,
          ) =>
              n.id ==
              id,
          orElse: () => throw Exception(
            'Notification not found in pending list',
          ),
        );
        print(
          '   ✅ Verified in pending notifications: ID ${thisNotification.id}',
        );
        print(
          '   📝 Notification title: ${thisNotification.title}',
        );
        print(
          '   📝 Notification body: ${thisNotification.body}',
        );
      } catch (
        e
      ) {
        print(
          '   ⚠️ Could not verify notification in pending list: $e',
        );
        print(
          '   ⚠️ This might mean the notification was not scheduled properly',
        );
        // Don't fail - notification might still be scheduled
      }

      return true;
    } catch (
      e
    ) {
      print(
        '❌ Error scheduling notification: $e',
      );
      print(
        '   Stack trace: ${StackTrace.current}',
      );
      return false;
    }
  }

  /// Cancel a scheduled notification
  Future<
    void
  >
  cancelNotification(
    int id,
  ) async {
    await _notifications.cancel(
      id,
    );
    print(
      '🗑️ Cancelled notification with id: $id',
    );
  }

  /// Cancel all notifications
  Future<
    void
  >
  cancelAllNotifications() async {
    await _notifications.cancelAll();
    print(
      '🗑️ Cancelled all notifications',
    );
  }

  /// Get pending notifications (for debugging)
  Future<
    List<
      PendingNotificationRequest
    >
  >
  getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Debug: Print all pending notifications
  Future<
    void
  >
  debugPrintPendingNotifications() async {
    final pending = await getPendingNotifications();
    print(
      '📋 Pending Notifications (${pending.length}):',
    );
    for (var notification in pending) {
      print(
        '   ID: ${notification.id}',
      );
      print(
        '   Title: ${notification.title}',
      );
      print(
        '   Body: ${notification.body}',
      );
      print(
        '   ---',
      );
    }
    if (pending.isEmpty) {
      print(
        '   No pending notifications',
      );
    }
  }

  /// Test notification - shows immediately to verify channel works
  Future<
    bool
  >
  showTestNotification() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'goal_reminders',
        'Goal Reminders',
        channelDescription: 'Notifications for goal reminders',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        999999, // Test notification ID
        'Test Notification',
        'If you see this, notifications are working!',
        notificationDetails,
      );

      print(
        '✅ Test notification shown',
      );
      return true;
    } catch (
      e
    ) {
      print(
        '❌ Error showing test notification: $e',
      );
      return false;
    }
  }

  /// Show a chat notification with reply functionality
  Future<bool> showChatNotification({
    required int id,
    required String title,
    required String body,
    required String communityId,
    required String communityName,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Android notification with reply action
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'community_chat',
        'Community Chat',
        channelDescription: 'Notifications for community chat messages',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.message,
        actions: [
          AndroidNotificationAction(
            'reply',
            'Reply',
            titleColor: Colors.indigo,
            showsUserInterface: false,
            cancelNotification: false,
            semanticAction: SemanticAction.reply,
            inputTextReplyParameter: const AndroidNotificationActionInputTextReplyParameter(
              hintText: 'Type a reply...',
            ),
          ),
        ],
        styleInformation: const BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'MESSAGE_CATEGORY',
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload ?? 'community_chat|$communityId',
      );

      print('✅ Chat notification shown: $title');
      return true;
    } catch (e) {
      print('❌ Error showing chat notification: $e');
      return false;
    }
  }

  /// Test scheduled notification - schedules for 10 seconds from now
  Future<
    bool
  >
  testScheduledNotification() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final testTime = DateTime.now().add(
        const Duration(
          seconds: 10,
        ),
      );
      print(
        '🧪 Testing scheduled notification:',
      );
      print(
        '   Current time: ${DateTime.now()}',
      );
      print(
        '   Scheduled for: $testTime',
      );
      print(
        '   Time difference: ${testTime.difference(DateTime.now()).inSeconds} seconds',
      );

      final result = await scheduleNotification(
        id: 999998,
        title: 'Test Scheduled Notification',
        body: 'This is a test scheduled notification. If you see this, scheduled notifications work!',
        scheduledDate: testTime,
        payload: 'test',
      );

      if (result) {
        print(
          '✅ Test scheduled notification created. Wait 10 seconds...',
        );

        // Verify it's in pending list
        await Future.delayed(
          const Duration(
            milliseconds: 500,
          ),
        );
        final pending = await getPendingNotifications();
        final testNotification = pending
            .where(
              (
                n,
              ) =>
                  n.id ==
                  999998,
            )
            .toList();
        if (testNotification.isNotEmpty) {
          print(
            '✅ Test notification confirmed in pending list',
          );
          print(
            '   Will fire at: ${testNotification.first.id}',
          );
        } else {
          print(
            '⚠️ Test notification NOT found in pending list!',
          );
        }

        return true;
      } else {
        print(
          '❌ Failed to schedule test notification',
        );
        return false;
      }
    } catch (
      e
    ) {
      print(
        '❌ Error testing scheduled notification: $e',
      );
      print(
        '   Stack trace: ${StackTrace.current}',
      );
      return false;
    }
  }
}
