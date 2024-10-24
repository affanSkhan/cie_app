// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
//
// class FCMService {
//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//   FlutterLocalNotificationsPlugin();
//
//   FCMService() {
//     _initializeLocalNotifications();
//   }
//
//   Future<void> setupFirebase() async {
//     // Request notification permissions
//     NotificationSettings settings =
//     await FirebaseMessaging.instance.requestPermission();
//     print('User granted permission: ${settings.authorizationStatus}');
//
//     // Configure FCM handlers
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
//       print('Message received: ${message.data}');
//       if (message.notification != null) {
//         await _showNotification(message.notification!);
//       }
//     });
//
//     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//       print('Message clicked: ${message.data}');
//       // Handle click action (navigate to a specific screen if needed)
//     });
//
//     // Set background message handler
//     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//   }
//
//   Future<void> _initializeLocalNotifications() async {
//     const AndroidInitializationSettings initializationSettingsAndroid =
//     AndroidInitializationSettings('@mipmap/ic_launcher');
//
//     const InitializationSettings initializationSettings =
//     InitializationSettings(android: initializationSettingsAndroid);
//
//     await flutterLocalNotificationsPlugin.initialize(
//       initializationSettings,
//     );
//   }
//
//   Future<void> _showNotification(RemoteNotification notification) async {
//     const AndroidNotificationDetails androidPlatformChannelSpecifics =
//     AndroidNotificationDetails(
//       'exam_reminder_channel', // Change to your channel ID
//       'Exam Reminders', // Change to your channel name
//       channelDescription: 'Notifications for exam reminders',
//       importance: Importance.max,
//       priority: Priority.high,
//       icon: '@mipmap/ic_launcher', // Icon for notifications
//       playSound: true,
//     );
//
//     const NotificationDetails platformChannelSpecifics =
//     NotificationDetails(android: androidPlatformChannelSpecifics);
//
//     await flutterLocalNotificationsPlugin.show(
//       notification.hashCode, // Use unique ID for each notification
//       notification.title,
//       notification.body,
//       platformChannelSpecifics,
//       payload: 'exam_notification', // Use a relevant payload
//     );
//   }
// }
//
// // Background message handler function
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   print('Handling a background message: ${message.messageId}');
//   // You can also show a notification here if needed
//   if (message.notification != null) {
//     // Initialize local notifications and show a notification
//     final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//     FlutterLocalNotificationsPlugin();
//
//     const AndroidInitializationSettings initializationSettingsAndroid =
//     AndroidInitializationSettings('@mipmap/ic_launcher');
//
//     const InitializationSettings initializationSettings =
//     InitializationSettings(android: initializationSettingsAndroid);
//
//     await flutterLocalNotificationsPlugin.initialize(initializationSettings);
//
//     await flutterLocalNotificationsPlugin.show(
//       message.notification!.hashCode,
//       message.notification!.title,
//       message.notification!.body,
//       const NotificationDetails(
//         android: AndroidNotificationDetails(
//           'exam_reminder_channel',
//           'Exam Reminders',
//           channelDescription: 'Notifications for exam reminders',
//           importance: Importance.max,
//           priority: Priority.high,
//           icon: '@mipmap/ic_launcher',
//           playSound: true,
//         ),
//       ),
//     );
//   }
// }
