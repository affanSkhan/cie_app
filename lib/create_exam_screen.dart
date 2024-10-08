//create_exam_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // To format date and time

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
  bool _isLoading = false;

  // Function to save exam details to Firestore
  Future<void> saveExamDetails() async {
    final subject = _subjectController.text.trim();
    final date = _dateController.text.trim();
    final time = _timeController.text.trim();
    final formLink = _formLinkController.text.trim();

    if (subject.isEmpty || date.isEmpty || time.isEmpty || formLink.isEmpty) {
      // Show an error message if any field is empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('exams').add({
        'subject': subject,
        'date': date,
        'time': time,
        'formLink': formLink,
        'createdAt': DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exam created successfully!')),
      );
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

  // Function to show Date Picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(), // default to today's date
      firstDate: DateTime(2020), // earliest date to select
      lastDate: DateTime(2100),  // latest date to select
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // Function to show Time Picker
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(), // default to current time
    );
    if (picked != null) {
      setState(() {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
        _timeController.text = DateFormat('hh:mm a').format(dt); // Formats to 12-hour time
      });
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _formLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Exam'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Subject Name'),
            ),
            TextField(
              controller: _dateController,
              readOnly: true, // Makes the field read-only
              onTap: () => _selectDate(context), // Opens date picker when tapped
              decoration: const InputDecoration(labelText: 'Exam Date'),
            ),
            TextField(
              controller: _timeController,
              readOnly: true, // Makes the field read-only
              onTap: () => _selectTime(context), // Opens time picker when tapped
              decoration: const InputDecoration(labelText: 'Exam Time'),
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
              child: const Text('Save Exam'),
            ),
          ],
        ),
      ),
    );
  }
}
