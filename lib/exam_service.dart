import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendExamNotification(String title, String body) async {
  const String serverKey = 'YOUR_SERVER_KEY'; // Get this from Firebase Console
  const String fcmUrl = 'https://fcm.googleapis.com/fcm/send';

  final response = await http.post(
    Uri.parse(fcmUrl),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'key=$serverKey',
    },
    body: jsonEncode({
      'to': '/topics/exams', // Subscribe clients to this topic to receive notifications
      'notification': {
        'title': title,
        'body': body,
      },
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to send notification');
  }
}
