//fcmservice.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FCMService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> setupFirebase() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // Print the message for debugging
      print('Message received: ${message.data}');

      // Show a notification
      if (message.notification != null) {
        await _showNotification(message.notification!);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message clicked! ${message.data}');
      // Navigate to a specific screen if needed
    });
  }

  Future<void> _showNotification(RemoteNotification notification) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'your_channel_id', // Ensure this matches the channel ID used when creating the channel
      'Your Channel Name',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher', // Make sure this exists
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      notification.title, // Notification title
      notification.body, // Notification body
      platformChannelSpecifics,
      payload: 'data', // Optional payload
    );
  }
}
