import 'package:cie_exam_app/Exam.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart'; // For more reliable URL handling
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart'; // Add this if using alarms

import 'main.dart'; // Import permission_handler

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

    // Request notification permission for Android 13+
    requestNotificationPermission();

    // Initialize timezones and notification plugin
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('app_icon');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // Listen for new exams and trigger notifications
    listenForNewExams();

    // Fetch the upcoming exams stream
    examStream = getUpcomingExams();
  }

  Future<void> requestNotificationPermission() async {
    // Request permission to show notifications
    final status = await Permission.notification.request();
    if (status.isGranted) {
      print("Notification permission granted");
    } else {
      print("Notification permission denied");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Permission denied to show notifications')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Exams'),
        actions: [
          ElevatedButton(
            onPressed: () {
              signOut(context); // Call the sign-out function
            },
            child: const Text('Sign Out'),
          ),
          const SizedBox(width: 8), // Add spacing
        ],
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
                    'Date: ${DateFormat.yMMMd().format(exam.date)}\n'
                        'Time: ${DateFormat.jm().format(exam.date)}\n'
                        'Google Form: ${exam.formLink}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.alarm),
                    onPressed: () {
                      print("Alarm icon clicked!");
                      setReminder(exam); // Set a reminder for the exam
                    },
                  ),
                  onTap: () {
                    if (exam.formLink.isNotEmpty) {
                      launchURL(exam.formLink); // Launch Google Form if the link is valid
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
    try {
      // Ensure that the exam date is not null
      if (exam.date == null) {
        print("Exam date is null for ${exam.subject}. Cannot set reminder.");
        return; // Exit if the date is null
      }

      final examDateTime = exam.date;
      final reminderTime = examDateTime.subtract(const Duration(minutes: 15));

      // Ensure reminder time is in the future
      if (reminderTime.isBefore(DateTime.now())) {
        print("Reminder time for ${exam.subject} is in the past. Cannot set reminder.");
        return; // Exit if reminder time is in the past
      }

      // Log the reminder time
      print("Reminder time for ${exam.subject}: $reminderTime");

      // Schedule notification using the actual reminder time
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

      // Use an integer ID for notification; for example, the hash code of the ID string
      await flutterLocalNotificationsPlugin.zonedSchedule(
        exam.id.hashCode, // Unique ID derived from the exam ID
        'Upcoming Exam: ${exam.subject}',
        'Your exam starts at ${DateFormat.jm().format(examDateTime)}',
        tz.TZDateTime.from(reminderTime, tz.local),
        platformChannelSpecifics,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      print("Reminder set for ${exam.subject} at $reminderTime");

    } catch (e) {
      print("Error setting reminder: $e");
    }
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
    try {
      // Parse URL and attempt to launch
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    } catch (e) {
      // Catch any exceptions and print error
      print("Error launching URL: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  void listenForNewExams() {
    FirebaseFirestore.instance
        .collection('exams')
        .snapshots()
        .listen((snapshot) {
      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.added) {
          // Log the new exam details
          print('New exam added: ${docChange.doc.data()}');

          // New exam added, trigger notification
          Exam newExam = Exam.fromFirestore(docChange.doc);
          triggerNotification(newExam);
        }
      }
    });
  }

  void triggerNotification(Exam exam) async {
    // Unique notification ID for each exam to avoid overriding
    int notificationId = exam.hashCode; // Using the exam's hash code as a unique ID

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'new_exam_channel', // Unique channel ID
      'New Exam Added', // Channel name
      channelDescription: 'Channel for new exam notifications', // Channel description
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    // Log when the notification is triggered
    print('Triggering notification for exam: ${exam.subject}');

    // Show the notification immediately
    await flutterLocalNotificationsPlugin.show(
      notificationId, // Use a unique notification ID
      'New Exam Added: ${exam.subject}', // Title
      'Scheduled for ${DateFormat.yMMMd().format(exam.date)} at ${DateFormat.jm().format(exam.date)}', // Body (date and time)
      platformChannelSpecifics,
      payload: exam.formLink, // Pass the Google Form link in the payload
    );
  }


  // Function to fetch upcoming exams from Firestore
  Stream<List<Exam>> getUpcomingExams() {
    // Get the current time (to fetch future exams)
    DateTime now = DateTime.now();

    return FirebaseFirestore.instance
        .collection('exams')
        .where('examDate',
        isGreaterThanOrEqualTo: now) // Compare with current date/time
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Exam.fromFirestore(doc)).toList());
  }
}

// Stream<List<Exam>> getUpcomingExams() {
//   // Get the current date (today's date) with time set to midnight
//   DateTime startOfToday = DateTime.now();
//   DateTime endOfToday =
//   DateTime(startOfToday.year, startOfToday.month, startOfToday.day, 23, 59, 59);
//
//   return FirebaseFirestore.instance
//       .collection('exams')
//       .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startOfToday)) // Include today
//       .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endOfToday)) // Optional: Include exams up until the end of today
//       .snapshots()
//       .map((snapshot) =>
//       snapshot.docs.map((doc) => Exam.fromFirestore(doc)).toList());
// }
// }
