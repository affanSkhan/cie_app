import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';


class CreateExamScreen extends StatefulWidget {
  const CreateExamScreen({super.key});

  @override
  _CreateExamScreenState createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _formLinkController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(text: "60");
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final List<String> _selectedDivisions = ['A', 'B'];

  bool _isLoading = false;

  String selectedClass = 'FY';
  List<String> selectedDivisions = ['A'];

  Future<void> saveExamDetails() async {
    final subject = _subjectController.text.trim();
    final date = _dateController.text.trim();
    final time = _timeController.text.trim();
    final formLink = _formLinkController.text.trim();
    final classId = selectedClass;
    final List<String> divisions = selectedDivisions;
    final int examDuration = int.tryParse(_durationController.text.trim()) ?? 60;
    final DateTime examDate = DateFormat('yyyy-MM-dd hh:mm a').parse('$date $time');

    if (subject.isEmpty || date.isEmpty || time.isEmpty || formLink.isEmpty || classId.isEmpty || divisions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields, including selecting a division')),
      );
      return;
    }

    if (examDuration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duration must be a positive number')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No teacher logged in')),
        );
        return;
      }

      bool clashExists = await isExamClashing(classId, divisions, examDate, Duration(minutes: examDuration));

      if (clashExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exam clash detected. Please choose a different time.')),
        );
      } else {
        await FirebaseFirestore.instance.collection('exams').add({
          'subject': subject,
          'classId': classId,
          'division': divisions,
          'examDate': Timestamp.fromDate(examDate),
          'examDuration': examDuration,
          'googleFormLink': formLink,
          'canEdit': true,
          'lastUpdated': FieldValue.serverTimestamp(),
          'status': 'scheduled',
          'teacherId': user.uid,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exam created successfully!')),
        );

        _clearForm();

        sendFCMNotification(subject, 'You have an upcoming exam', classId, divisions);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating exam: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearForm() {
    _subjectController.clear();
    _dateController.clear();
    _timeController.clear();
    _formLinkController.clear();
    setState(() {
      selectedDivisions = ['A'];
      selectedClass = 'FY';
    });
  }

  Future<bool> isExamClashing(String classId, List<String> divisions, DateTime newExamDate, Duration examDuration) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection('exams')
        .where('classId', isEqualTo: classId)
        .where('division', arrayContainsAny: divisions)
        .where('status', isEqualTo: 'scheduled')
        .get();

    for (var doc in query.docs) {
      var examData = doc.data() as Map<String, dynamic>;
      DateTime existingExamDate = (examData['examDate'] as Timestamp).toDate();
      Duration existingDuration = Duration(minutes: examData['examDuration']);

      if (newExamDate.isBefore(existingExamDate.add(existingDuration)) &&
          newExamDate.add(examDuration).isAfter(existingExamDate)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      setState(() {
        _timeController.text = DateFormat('hh:mm a').format(dt);
      });
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _formLinkController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Exam'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Subject Name'),
              ),
              const SizedBox(height: 10),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Class'),
                child: DropdownButton<String>(
                  value: selectedClass,
                  items: ['FY', 'SY', 'TY', 'BTECH'].map((classId) {
                    return DropdownMenuItem(
                      value: classId,
                      child: Text(classId),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedClass = value!;
                    });
                  },
                  isExpanded: true,
                  underline: Container(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                children: ['A', 'B', 'C', 'D'].map((division) {
                  return CheckboxListTile(
                    title: Text(division),
                    value: selectedDivisions.contains(division),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value!) {
                          selectedDivisions.add(division);
                        } else {
                          selectedDivisions.remove(division);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _dateController,
                readOnly: true,
                onTap: () => _selectDate(context),
                decoration: const InputDecoration(labelText: 'Exam Date'),
              ),
              TextField(
                controller: _timeController,
                readOnly: true,
                onTap: () => _selectTime(context),
                decoration: const InputDecoration(labelText: 'Exam Time'),
              ),
              TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duration (minutes)'),
              ),
              TextField(
                controller: _formLinkController,
                decoration: const InputDecoration(labelText: 'Google Form Link'),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: saveExamDetails,
                child: const Text('Create Exam'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> sendFCMNotification(String title, String body, String classId, List<String> divisions) async {
  try {
    // Load the service account JSON file from assets
    final serviceAccountJsonString = await rootBundle.loadString('assets/cie-exams-viit-eb74a001b9fc.json');
    final serviceAccountJson = json.decode(serviceAccountJsonString);

    // Create an authenticated client
    final client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(serviceAccountJson),
      ['https://www.googleapis.com/auth/firebase.messaging'],
    );

    // Get the project ID from the service account JSON
    final projectId = serviceAccountJson['project_id'];
    final url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

    // Send notification to both class and division topics
    for (String division in divisions) {
      final response = await client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': {
            'condition': "'class_$classId' in topics && 'division_$division' in topics",
            'notification': {
              'title': title,
              'body': body,
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        print('Notification successfully sent to class $classId and division $division');
      } else {
        print('Failed to send notification: ${response.statusCode} - ${response.body}');
      }
    }

    // Close the client when done
    client.close();
  } catch (e) {
    print('Error sending FCM notification: $e');
  }
}
