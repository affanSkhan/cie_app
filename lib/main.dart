import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'student_dashboard.dart';
import 'teacher_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'firebase_options.dart';
import 'package:rxdart/rxdart.dart';
import 'package:awesome_notifications/awesome_notifications.dart';


// Used to pass messages from event handler to the UI
final _messageStreamController = BehaviorSubject<RemoteMessage>();

// Initialize Flutter Local Notifications Plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Awesome Notifications
  AwesomeNotifications().initialize(
    'resource://drawable/app_icon', // Add your app icon path here
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

  tz.initializeTimeZones(); // Initialize time zone data

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Firebase initialization error: $e");
  }

  if (!kIsWeb) {
    // Initialize Android Alarm Manager
    await AndroidAlarmManager.initialize();
    tz.initializeTimeZones();
  }

  // Request FCM permission for iOS devices
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (kDebugMode) {
    print('Permission granted: ${settings.authorizationStatus}');
  }

  // Retrieve FCM registration token
  String? token;
  if (DefaultFirebaseOptions.currentPlatform == DefaultFirebaseOptions.web) {
    const vapidKey = "YOUR_VAPID_KEY_HERE";
    token = await messaging.getToken(vapidKey: vapidKey);
  } else {
    token = await messaging.getToken();
  }

  if (kDebugMode) {
    print('FCM Registration Token=$token');
  }

  // Set up FCM background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Flutter Local Notifications Plugin
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      print('Notification Clicked: ${response.payload}');
      // Handle notification click
    },
  );

  // final fcmService = FCMService();
  // await fcmService.setupFirebase(); // Initialize FCM

  // Check if the user is logged in
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

// Background FCM message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // Listen to FCM messages when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        showNotification(notification.title, notification.body);
      }
    });

    // Listen for messages when the app is opened from the background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A notification was opened from the background.');
    });

    // Handle background/terminated state with Flutter Local Notifications
  }

  // Show notification
  void showNotification(String? title, String? body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'exam_reminder_channel', // Channel ID for exam reminders
      'Exam Notifications',
      channelDescription: 'Notifications for exam reminders',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      title,
      body,
      platformChannelSpecifics,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CIE Exam App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: widget.isLoggedIn
          ? const StudentDashboardScreen()
          : const SignInScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}



Future<void> signOut(BuildContext context) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.clear(); // Clear all stored preferences

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const SignInScreen()),
  ); // Redirect to sign-in screen
}

bool _isValidEmail(String email) {
  return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
      .hasMatch(email);
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus(); // Dismiss the keyboard
    setState(() {
      _errorMessage = null; // Reset error message
      _isLoading = true; // Show loading
    });

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = "Please enter both email and password.";
        _isLoading = false;
      });
      return;
    }

    if (!_isValidEmail(_emailController.text)) {
      setState(() {
        _errorMessage = "Please enter a valid email.";
        _isLoading = false;
      });
      return;
    }

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Fetch user role from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).get();
      String userRole = userDoc['role'];

      // Store login state in SharedPreferences
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmail', _emailController.text); // Store email if needed

      // Navigate based on role
      if (userRole == 'student') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StudentDashboardScreen()),
        );
      } else if (userRole == 'teacher') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TeacherDashboardScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error signing in. Please check your credentials and try again.";
        _isLoading = false;
      });
    }
  }


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign In")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _signIn,
              child: const Text("Sign In"),
            ),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignUpScreen()),
                );
              },
              child: const Text("Don't have an account? Sign Up"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PasswordResetScreen()),
                );
              },
              child: const Text("Forgot Password?"),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  String? _errorMessage;
  String? _selectedRole = "student"; // Default role
  String? _selectedClassId = "FY"; // Default class
  String? _selectedDivision = "A"; // Default division
  bool _isLoading = false;

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus(); // Dismiss the keyboard
    setState(() {
      _errorMessage = null; // Reset error message
      _isLoading = true; // Show loading
    });

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = "Please enter all fields.";
        _isLoading = false;
      });
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = "Passwords do not match.";
        _isLoading = false;
      });
      return;
    }

    if (!_isValidEmail(_emailController.text)) {
      setState(() {
        _errorMessage = "Please enter a valid email.";
        _isLoading = false;
      });
      return;
    }

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Add user to Firestore with role, class, and division
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).set({
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'classId': _selectedClassId,
        'division': _selectedDivision,
      });

      // Navigate to sign-in screen after sign-up
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()), // Replace with your SignIn screen widget
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFirebaseAuthErrorMessage(e);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error signing up. Please try again.";
        _isLoading = false;
      });
    }
  }

  String _getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return "The password provided is too weak.";
      case 'email-already-in-use':
        return "The account already exists for that email.";
      case 'invalid-email':
        return "The email address is not valid.";
      default:
        return "An unknown error occurred.";
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
              ),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
              ),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: "Confirm Password"),
                obscureText: true,
              ),
              DropdownButton<String>(
                value: _selectedRole,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedRole = newValue!;
                  });
                },
                items: <String>['student', 'teacher']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              // Class selection dropdown
              DropdownButton<String>(
                value: _selectedClassId,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedClassId = newValue!;
                  });
                },
                items: <String>['FY', 'SY', 'TY', 'BTECH']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              // Division selection dropdown
              DropdownButton<String>(
                value: _selectedDivision,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedDivision = newValue!;
                  });
                },
                items: <String>['A', 'B', 'C', 'D']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _signUp,
                child: const Text("Sign Up"),
              ),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const SignInScreen()),
                  );
                },
                child: const Text("Already have an account? Sign In"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").hasMatch(email);
  }
}


class PasswordResetScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();

  PasswordResetScreen({super.key});

  Future<void> _resetPassword(String email, BuildContext context) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context); // Navigate back after showing snackbar
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Password")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _resetPassword(_emailController.text.trim(), context);
              },
              child: const Text("Send Password Reset Email"),
            ),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final String title;

  const MyHomePage({super.key, required this.title});



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Text('Welcome to the CIE Exam App!'),
      ),
    );
  }
}
