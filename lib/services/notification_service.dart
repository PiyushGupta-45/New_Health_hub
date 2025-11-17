// notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  
  // Expose notifications plugin for fallback use
  FlutterLocalNotificationsPlugin get notifications => _notifications;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();
    
    // Set default timezone to IST (Asia/Kolkata)
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      print('✅ Timezone set to IST (Asia/Kolkata)');
    } catch (e) {
      print('⚠️ Could not set IST timezone, using system default: $e');
    }

    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
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
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      // Create the notification channel
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
      print('✅ Notification channel created');
    }

    // Request permissions (Android 13+)
    final permissionGranted = await androidImplementation
            ?.requestNotificationsPermission() ??
        false;
    
    if (permissionGranted) {
      print('✅ Notification permission granted');
    } else {
      print('⚠️ Notification permission not granted');
    }
    
    _initialized = true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap if needed
    print('Notification tapped: ${response.payload}');
  }

  /// Schedule a notification for a specific date and time
  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Get IST timezone location
      final istLocation = tz.getLocation('Asia/Kolkata');
      
      // Ensure we're working with IST timezone
      // If scheduledDate is already in local time, convert it properly
      DateTime localDateTime;
      if (scheduledDate.isUtc) {
        // Convert UTC to IST
        localDateTime = scheduledDate.toLocal();
      } else {
        // Already in local time, use as is
        localDateTime = scheduledDate;
      }

      // Convert DateTime to TZDateTime in IST timezone
      final tz.TZDateTime scheduledTime = tz.TZDateTime.from(
        localDateTime,
        istLocation,
      );

      final now = tz.TZDateTime.now(istLocation);
      
      // Debug logging
      print('📅 Notification scheduling details (IST):');
      print('   Input DateTime (UTC): ${scheduledDate.toUtc()}');
      print('   Input DateTime (Local): $localDateTime');
      print('   Scheduled Time (IST): $scheduledTime');
      print('   Current Time (IST): $now');
      print('   Time until notification: ${scheduledTime.difference(now).inMinutes} minutes');

      // Check if the scheduled time is in the past
      if (scheduledTime.isBefore(now)) {
        print('⚠️ Cannot schedule notification in the past');
        print('   Scheduled: $scheduledTime');
        print('   Now: $now');
        print('   Difference: ${now.difference(scheduledTime).inMinutes} minutes ago');
        return false;
      }

      // Android notification details
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
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
      try {
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          scheduledTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        print('   📌 Scheduled with EXACT alarm mode');
      } catch (e) {
        print('   ⚠️ Exact alarm failed (may need permission), trying inexact: $e');
        // Fallback to inexact if exact fails
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          scheduledTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        print('   📌 Scheduled with INEXACT alarm mode (may have delay)');
      }

      print('✅ Notification scheduled successfully!');
      print('   ID: $id');
      print('   Scheduled for: $scheduledTime (IST)');
      print('   Title: $title');
      
      // Verify it was scheduled by checking pending notifications
      try {
        // Wait a moment for the notification to be registered
        await Future.delayed(const Duration(milliseconds: 500));
        final pending = await getPendingNotifications();
        print('   📋 Total pending notifications: ${pending.length}');
        
        final thisNotification = pending.firstWhere(
          (n) => n.id == id,
          orElse: () => throw Exception('Notification not found in pending list'),
        );
        print('   ✅ Verified in pending notifications: ID ${thisNotification.id}');
        print('   📝 Notification title: ${thisNotification.title}');
        print('   📝 Notification body: ${thisNotification.body}');
      } catch (e) {
        print('   ⚠️ Could not verify notification in pending list: $e');
        print('   ⚠️ This might mean the notification was not scheduled properly');
        // Don't fail - notification might still be scheduled
      }
      
      return true;
    } catch (e) {
      print('❌ Error scheduling notification: $e');
      print('   Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    print('🗑️ Cancelled notification with id: $id');
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('🗑️ Cancelled all notifications');
  }

  /// Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Debug: Print all pending notifications
  Future<void> debugPrintPendingNotifications() async {
    final pending = await getPendingNotifications();
    print('📋 Pending Notifications (${pending.length}):');
    for (var notification in pending) {
      print('   ID: ${notification.id}');
      print('   Title: ${notification.title}');
      print('   Body: ${notification.body}');
      print('   ---');
    }
    if (pending.isEmpty) {
      print('   No pending notifications');
    }
  }

  /// Test notification - shows immediately to verify channel works
  Future<bool> showTestNotification() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
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

      print('✅ Test notification shown');
      return true;
    } catch (e) {
      print('❌ Error showing test notification: $e');
      return false;
    }
  }

  /// Test scheduled notification - schedules for 10 seconds from now
  Future<bool> testScheduledNotification() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final testTime = DateTime.now().add(const Duration(seconds: 10));
      print('🧪 Testing scheduled notification:');
      print('   Current time: ${DateTime.now()}');
      print('   Scheduled for: $testTime');
      print('   Time difference: ${testTime.difference(DateTime.now()).inSeconds} seconds');
      
      final result = await scheduleNotification(
        id: 999998,
        title: 'Test Scheduled Notification',
        body: 'This is a test scheduled notification. If you see this, scheduled notifications work!',
        scheduledDate: testTime,
        payload: 'test',
      );
      
      if (result) {
        print('✅ Test scheduled notification created. Wait 10 seconds...');
        
        // Verify it's in pending list
        await Future.delayed(const Duration(milliseconds: 500));
        final pending = await getPendingNotifications();
        final testNotification = pending.where((n) => n.id == 999998).toList();
        if (testNotification.isNotEmpty) {
          print('✅ Test notification confirmed in pending list');
          print('   Will fire at: ${testNotification.first.id}');
        } else {
          print('⚠️ Test notification NOT found in pending list!');
        }
        
        return true;
      } else {
        print('❌ Failed to schedule test notification');
        return false;
      }
    } catch (e) {
      print('❌ Error testing scheduled notification: $e');
      print('   Stack trace: ${StackTrace.current}');
      return false;
    }
  }
}

