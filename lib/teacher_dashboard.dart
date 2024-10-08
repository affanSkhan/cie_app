//teacher_dashboard.dart
import 'package:flutter/material.dart';
import 'create_exam_screen.dart';


class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Dashboard")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to the Teacher Dashboard!'),
            const SizedBox(height: 20), // Adds some space between the text and the button
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
          ],
        ),
      ),
    );
  }
}

