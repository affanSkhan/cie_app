import 'package:cie_exam_app/Exam.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:url_launcher/url_launcher_string.dart'; // For URL handling
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'main.dart';

void subscribeToTopics(String classId, String division) {
  FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  // Subscribe to class and division topics
  firebaseMessaging.subscribeToTopic('class_$classId');
  firebaseMessaging.subscribeToTopic('division_$division');

  print('Subscribed to class_$classId and division_$division topics');
}


void unsubscribeFromTopics(String? classId, String? division) {
  if (classId != null && division != null) {
    FirebaseMessaging.instance.unsubscribeFromTopic('class_$classId');
    FirebaseMessaging.instance.unsubscribeFromTopic('division_$division');
    print('Unsubscribed from topics class_$classId and division_$division');
  }
}


class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  _StudentDashboardScreenState createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  String? _classId;
  String? _division;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;
  Stream<List<Exam>>? examStream;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _getClassAndDivision();
    requestNotificationPermission();
   // initializeAwesomeNotifications();
    tz.initializeTimeZones();
   // initializeNotifications();
    configureFirebaseMessaging();
  }

  void initializeAwesomeNotifications() {
    AwesomeNotifications().initialize(
      'resource://drawable/app_icon', // App icon
      [
        NotificationChannel(
          channelKey: 'scheduled_channel',
          channelName: 'Scheduled Notifications',
          channelDescription: 'Notification channel for scheduled exams',
          defaultColor: Colors.blue,
          ledColor: Colors.white,
          importance: NotificationImportance.High,
        ),
      ],
    );
  }

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
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  // Firebase Cloud Messaging setup for receiving notifications
  void configureFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showNotification(message.notification!.title, message.notification!.body);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.notification != null) {
        // Handle notification tap
      }
    });
  }

  Future<void> showNotification(String? title, String? body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'scheduled_channel',
      'Scheduled Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  Future<void> _getClassAndDivision() async {
    if (_userId != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();

      if (userDoc.exists) {
        String? newClassId = userDoc['classId'];
        String? newDivision = userDoc['division'];

        // Unsubscribe from previous topics if they exist
        if (_classId != null && _division != null) {
          unsubscribeFromTopics(_classId, _division);
        }

        // Update state with new class and division
        setState(() {
          _classId = newClassId;
          _division = newDivision;
        });

        // Subscribe to new class and division topics
        if (_classId != null && _division != null) {
          subscribeToTopics(_classId!, _division!);
        }

        // Update the exam stream for new class and division
        if (_classId != null && _division != null) {
          examStream = getUpcomingExamsForStudent(_classId!, _division!);
        }
      }
    }
  }

  Stream<List<Exam>> getUpcomingExamsForStudent(String classId, String division) {
    DateTime now = DateTime.now();
    DateTime startOfToday = DateTime(now.year, now.month, now.day);

    return FirebaseFirestore.instance
        .collection('exams')
        .where('classId', isEqualTo: classId)
        .where('division', arrayContains: division)
        .where('status', isEqualTo: 'scheduled')
        .where('examDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
        .orderBy('examDate', descending: false)
        .snapshots()
        .map((snapshot) {
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
                      setReminder(context, exam);
                    },
                  ),
                  onTap: () {
                    if (exam.examLink.isNotEmpty) {
                      launchURL(exam.examLink);
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

  static const platform = MethodChannel('exam_reminder_channel');

  Future<void> setReminder(BuildContext context, Exam exam) async {
    int? minutesBeforeExam = await _showTimeInputDialog(context);
    if (minutesBeforeExam == null || minutesBeforeExam <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number of minutes!')),
      );
      return;
    }

    final DateTime reminderTime = exam.date.subtract(Duration(minutes: minutesBeforeExam));
    if (reminderTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder time must be in the future!')),
      );
      return;
    }

    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: exam.hashCode,
        channelKey: 'scheduled_channel',
        title: 'Reminder for ${exam.subject}',
        body:
        'Your exam is scheduled for ${DateFormat.yMMMd().format(exam.date)} at ${DateFormat.jm().format(exam.date)}',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar.fromDate(date: reminderTime),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder set successfully!')),
    );
  }

  Future<int?> _showTimeInputDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Set Reminder'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter minutes before exam',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                final minutesBefore = int.tryParse(controller.text);
                Navigator.of(context).pop(minutesBefore);
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  Future<void> onDidReceiveNotificationResponse(
      NotificationResponse response) async {
    String? payload = response.payload;
    if (payload != null) {
      launchURL(payload);
    }
  }

  Future<void> launchURL(String url) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      throw 'Could not launch $url';
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
