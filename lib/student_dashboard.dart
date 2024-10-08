import 'package:cie_exam_app/Exam.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:url_launcher/url_launcher.dart'; // For launching URLs
import 'package:url_launcher/url_launcher_string.dart'; // For more reliable URL handling

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  _StudentDashboardScreenState createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  Stream<List<Exam>>? examStream;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();

    // Initialize the timezone and the notification plugin
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('app_icon');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // Fetch the upcoming exams stream
    examStream = getUpcomingExams();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Exams'),
      ),
      body: StreamBuilder<List<Exam>>(
        stream: examStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No upcoming exams.'));
          }

          final exams = snapshot.data!;

          return ListView.builder(
            itemCount: exams.length,
            itemBuilder: (context, index) {
              final exam = exams[index];

              return Card(
                child: ListTile(
                  title: Text(exam.subject),
                  subtitle: Text(
                      'Date: ${exam.date}\nTime: ${exam.time}\nGoogle Form: ${exam.formLink}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.alarm),
                    onPressed: () {
                      setReminder(exam);
                    },
                  ),
                  onTap: () {
                    // Check if the form link is not null or empty
                    if (exam.formLink != null && exam.formLink.isNotEmpty) {
                      // Launch the Google Form link when tapped
                      launchURL(exam.formLink);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No valid link provided for this exam.'),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Function to set up reminders using timezone package
  Future<void> setReminder(Exam exam) async {
    final examDateTime = DateTime.parse('${exam.date} ${exam.time}');
    final reminderTime = examDateTime.subtract(const Duration(minutes: 15));

    // Convert DateTime to TZDateTime
    final tz.TZDateTime tzReminderTime = tz.TZDateTime.from(reminderTime, tz.local);

    // Android notification details
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'exam_reminder_channel',
      'Exam Reminders',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0, // Notification ID
      'Upcoming Exam: ${exam.subject}',
      'Your exam starts at ${exam.time}',
      tzReminderTime,
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: exam.formLink, // Payload contains the exam's Google Form link
    );
  }

  // Function to handle notification tap
  Future<void> onDidReceiveNotificationResponse(
      NotificationResponse response) async {
    final String? payload = response.payload;
    if (payload != null) {
      launchURL(payload); // Open the Google Form link
    }
  }

  // Function to open a URL (e.g., the Google Form link)

  Future<void> launchURL(String url) async {
    // Check if the URL can be launched
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }


  // Function to fetch upcoming exams from Firestore
  Stream<List<Exam>> getUpcomingExams() {
    // Get the current date (today's date) with time set to midnight
    DateTime startOfToday = DateTime.now();
    DateTime endOfToday =
    DateTime(startOfToday.year, startOfToday.month, startOfToday.day, 23, 59, 59);

    return FirebaseFirestore.instance
        .collection('exams')
        .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startOfToday)) // Include today
        .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endOfToday)) // Optional: Include exams up until the end of today
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Exam.fromFirestore(doc)).toList());
  }
}
