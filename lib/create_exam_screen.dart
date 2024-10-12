import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // To format date and time
import 'package:firebase_auth/firebase_auth.dart'; // To get the logged-in teacher

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
  final TextEditingController _durationController = TextEditingController();

  bool _isLoading = false;

  // For class dropdown and division checkboxes
  String selectedClass = 'FY'; // Default class
  List<String> selectedDivisions = ['A']; // Default division

  // Function to save exam details to Firestore
  Future<void> saveExamDetails() async {
    final subject = _subjectController.text.trim();
    final date = _dateController.text.trim();
    final time = _timeController.text.trim();
    final formLink = _formLinkController.text.trim();
    final classId = selectedClass;
    final List<String> divisions = selectedDivisions;
    final int examDuration = int.tryParse(_durationController.text.trim()) ?? 60; // Default to 60 minutes
    final DateTime examDate = DateFormat('yyyy-MM-dd hh:mm a').parse('$date $time');

    // Validate form inputs
    if (subject.isEmpty || date.isEmpty || time.isEmpty || formLink.isEmpty || classId.isEmpty || divisions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields, including selecting a division')),
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

  // Clear the form after submission
  void _clearForm() {
    _subjectController.clear();
    _dateController.clear();
    _timeController.clear();
    _formLinkController.clear();
    _durationController.clear();
    setState(() {
      selectedDivisions = ['A']; // Reset division selection
      selectedClass = 'FY'; // Reset class selection
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
        return true;  // Exam clashes
      }
    }
    return false;  // No clash
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
                decoration: const InputDecoration(labelText: 'Exam Duration (minutes)'),
              ),
              TextField(
                controller: _formLinkController,
                decoration: const InputDecoration(labelText: 'Google Form Link'),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _isLoading ? null : saveExamDetails,
                child: const Text('Save Exam'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
