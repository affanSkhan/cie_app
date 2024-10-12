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
    final List<String> divisions = selectedDivisions; // No need to join as a string
    final int examDuration = int.tryParse(_durationController.text.trim()) ?? 60; // Default to 60 minutes
    final DateTime examDate = DateFormat('yyyy-MM-dd hh:mm a').parse('$date $time');

    if (subject.isEmpty || date.isEmpty || time.isEmpty || formLink.isEmpty || classId.isEmpty || selectedDivisions.isEmpty) {
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
      // Check for exam clash
      bool clashExists = await isExamClashing(classId, divisions, examDate, Duration(minutes: examDuration));

      if (clashExists) {
        // Show a message about the clash
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exam cannot be scheduled due to a clash with another exam.')),
        );
      } else {
        // If no clash exists, save the exam

        await FirebaseFirestore.instance.collection('exams').add({
          'subject': subject,
          'classId': classId,
          'division': divisions, // Store division as an array
          'examDate': Timestamp.fromDate(examDate),
          'examDuration': examDuration,
          'googleFormLink': formLink,
          'canEdit': true,
          'lastUpdated': FieldValue.serverTimestamp(),
          'status': 'scheduled',
        });


        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exam created successfully!')),
        );

        // Clear the form after successful submission
        _subjectController.clear();
        _dateController.clear();
        _timeController.clear();
        _formLinkController.clear();
        _durationController.clear();
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

  // Function to check for exam clashes
  // Function to check for exam clashes
  Future<bool> isExamClashing(String classId, List<String> divisions, DateTime newExamDate, Duration examDuration) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection('exams')
        .where('classId', isEqualTo: classId)
        .where('division', arrayContainsAny: divisions) // Check for any division clashes
        .where('status', isEqualTo: 'scheduled')
        .get();

    for (var doc in query.docs) {
      var examData = doc.data() as Map<String, dynamic>;
      DateTime existingExamDate = (examData['examDate'] as Timestamp).toDate();
      Duration existingDuration = Duration(minutes: examData['examDuration']);

      // Check if the new exam overlaps with an existing one
      if (newExamDate.isBefore(existingExamDate.add(existingDuration)) &&
          newExamDate.add(examDuration).isAfter(existingExamDate)) {
        return true;  // Exam clashes
      }
    }
    return false;  // No clash
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
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Exam'),
      ),
      body: SingleChildScrollView( // Make the content scrollable
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Subject Name'),
              ),

              // Class Dropdown
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
                  isExpanded: true, // Makes dropdown take full width
                  underline: Container(), // Removes default underline
                ),
              ),

              // Division Checkboxes
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
                onPressed: saveExamDetails,
                child: const Text('Save Exam'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
