import 'package:cie_exam_app/Exam.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:url_launcher/url_launcher_string.dart'; // For URL handling
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'main.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  _StudentDashboardScreenState createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  String? _classId;
  String? _division;
  String? _userId = FirebaseAuth.instance.currentUser?.uid;
  Stream<List<Exam>>? examStream;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    requestNotificationPermission();
    tz.initializeTimeZones();
    initializeNotifications();
    _getClassAndDivision();
  }

  // Initialize notification plugin
  void initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('app_icon');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
  }

  Future<void> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      print("Notification permission granted");
    } else {
      print("Notification permission denied");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission denied to show notifications'),
        ),
      );
    }
  }

  // Fetch the student's class and division from Firestore
  Future<void> _getClassAndDivision() async {
    if (_userId != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          _classId = userDoc['classId'];
          _division = userDoc['division'];
        });

        print('Fetched ClassId: $_classId, Division: $_division');

        // Fetch the exams only after classId and division are fetched
        examStream = getUpcomingExamsForStudent(_classId!, _division!);
      }
    }
  }

  // Fetch upcoming exams based on the student's class and division
  Stream<List<Exam>> getUpcomingExamsForStudent(String classId, String division) {
    DateTime startOfToday = DateTime.now();

    return FirebaseFirestore.instance
        .collection('exams')
        .where('classId', isEqualTo: classId)
        .where('division', arrayContains: division)
        .where('status', isEqualTo: 'scheduled')
        .where('examDate', isGreaterThanOrEqualTo: startOfToday)
        .orderBy('examDate', descending: false)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        print('No exams found for class: $classId, division: $division');
      } else {
        print('Exams found: ${snapshot.docs.length}');
      }
      return snapshot.docs.map((doc) => Exam.fromFirestore(doc)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Exams'),
        actions: [
          ElevatedButton(
            onPressed: () {
              _showSignOutConfirmation(context); // Show sign-out confirmation dialog
            },
            child: const Text('Sign Out'),
          ),
          const SizedBox(width: 8), // Add spacing
        ],
      ),
      body: examStream != null
          ? StreamBuilder<List<Exam>>(
        stream: examStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
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
                        'Google Form: ${exam.examLink}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.alarm),
                    onPressed: () {
                      setReminder(exam); // Set a reminder for the exam
                    },
                  ),
                  onTap: () {
                    if (exam.examLink.isNotEmpty) {
                      launchURL(exam.examLink); // Launch Google Form link
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
      )

          : const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  // Function to set reminders
  Future<void> setReminder(Exam exam) async {
    if (exam.date == null) return;

    final reminderTime = exam.date.subtract(const Duration(minutes: 15));
    if (reminderTime.isBefore(DateTime.now())) return;

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
      exam.id.hashCode, // Unique ID
      'Upcoming Exam: ${exam.subject}',
      'Your exam starts at ${DateFormat.jm().format(exam.date)}',
      tz.TZDateTime.from(reminderTime, tz.local),
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Function to handle notification tap
  Future<void> onDidReceiveNotificationResponse(
      NotificationResponse response) async {
    final String? payload = response.payload;
    if (payload != null) {
      launchURL(payload);
    }
  }

  // Function to launch URL
  Future<void> launchURL(String url) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
    }
  }

  // Sign out confirmation dialog
  void _showSignOutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                signOut(context); // Call sign-out function
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }
}

