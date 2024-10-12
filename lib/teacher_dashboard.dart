//teacher_dashboard.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'Exam.dart';
import 'create_exam_screen.dart';
import 'main.dart';

class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  // Function to show sign-out confirmation dialog
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
                signOut(context); // Call the sign-out function
                Navigator.of(context).pop(); // Close the dialog after signing out
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  // Function to fetch existing exams from Firestore based on class and divisions
  Stream<List<Exam>> fetchExams(String classId, List<String> divisions) {
    DateTime now = DateTime.now();
    return FirebaseFirestore.instance
        .collection('exams')
        .where('examDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now)) // Filter by date
        .where('classId', isEqualTo: classId) // Match classId
        .where('division', whereIn: divisions) // Multiple divisions
        .where('status', isEqualTo: 'scheduled') // Match only scheduled exams
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Exam.fromFirestore(doc)).toList());
  }

  // Function to delete an exam
  Future<void> deleteExam(String examId) async {
    await FirebaseFirestore.instance.collection('exams').doc(examId).delete();
  }

  // Function to check for exam clashes
  Future<bool> isExamClashing(String classId, List<String> divisions, DateTime examDate) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('exams')
        .where('classId', isEqualTo: classId)
        .where('divisions', arrayContainsAny: divisions)
        .where('examDate', isEqualTo: examDate)
        .where('status', isEqualTo: 'scheduled')
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // Function to show edit dialog
  Future<void> _showEditDialog(BuildContext context, Exam exam) async {
    final subjectController = TextEditingController(text: exam.subject);
    final durationController = TextEditingController(text: exam.duration.toString());
    DateTime selectedDateTime = exam.date;

    // UI for selecting class and divisions
    String selectedClass = exam.classId;
    List<String> selectedDivisions = exam.divisions;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Exam'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Date: ${DateFormat.yMMMd().format(selectedDateTime)}'),
                    ElevatedButton(
                      onPressed: () async {
                        DateTime? newDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDateTime,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2101),
                        );
                        if (newDate != null) {
                          selectedDateTime = DateTime(
                            newDate.year,
                            newDate.month,
                            newDate.day,
                            selectedDateTime.hour,
                            selectedDateTime.minute,
                          );
                        }
                      },
                      child: const Text('Select Date'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Time: ${DateFormat.jm().format(selectedDateTime)}'),
                    ElevatedButton(
                      onPressed: () async {
                        TimeOfDay? newTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                        );
                        if (newTime != null) {
                          selectedDateTime = DateTime(
                            selectedDateTime.year,
                            selectedDateTime.month,
                            selectedDateTime.day,
                            newTime.hour,
                            newTime.minute,
                          );
                        }
                      },
                      child: const Text('Select Time'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                if (subjectController.text.isNotEmpty && durationController.text.isNotEmpty) {
                  FirebaseFirestore.instance.collection('exams').doc(exam.id).update({
                    'subject': subjectController.text,
                    'duration': int.parse(durationController.text),
                    'examDate': selectedDateTime,
                    'classId': selectedClass,
                    'divisions': selectedDivisions,
                  });
                  Navigator.of(context).pop(); // Close the dialog
                }
              },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String classId = 'FY'; // Replace with actual class ID
    final List<String> divisions = ['A', 'B']; // Replace with actual divisions

    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Dashboard"),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateExamScreen(),
                  ),
                );
              },
              child: const Text('Create New Exam'),
            ),
            const SizedBox(height: 30),
            const Text('Scheduled Exams:'),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<List<Exam>>(
                stream: fetchExams(classId, divisions),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('No exams scheduled.');
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
                                'Duration: ${exam.duration} minutes\n'
                                'Status: ${exam.status}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showEditDialog(context, exam); // Show edit dialog
                              } else if (value == 'delete') {
                                _showDeleteConfirmation(context, exam.id); // Show delete confirmation
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Function to show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context, String examId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this exam?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                deleteExam(examId); // Call the delete function
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
