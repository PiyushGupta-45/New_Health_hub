import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'main_screen.dart';
import 'services/notification_service.dart';
import 'pages/community_page.dart';

// Global navigator key for navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  // Set up global notification response handler
  notificationService.setGlobalResponseHandler(_handleNotificationResponse);
  
  runApp(const MyApp());
}

void _handleNotificationResponse(NotificationResponse response) {
  print('📱 Notification response received:');
  print('   Payload: ${response.payload}');
  print('   Action ID: ${response.actionId}');
  print('   Input: ${response.input}');
  
  // Chat notifications will be handled by CommunityPage's handler
  // This is just for logging
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'FitTrack',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: 'Inter',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}
