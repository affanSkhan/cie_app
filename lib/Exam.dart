//Exam.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Exam {
  final String subject;
  final String date;
  final String time;
  final String formLink;
  final DateTime createdAt; // Handle createdAt as DateTime

  Exam({
    required this.subject,
    required this.date,
    required this.time,
    required this.formLink,
    required this.createdAt,
  });

  // Method to create an Exam object from Firestore document
  factory Exam.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Exam(
      subject: data['subject'] ?? 'Unknown Subject',
      date: data['date'] ?? 'Unknown Date',
      time: data['time'] ?? 'Unknown Time',
      formLink: data['formLink'] ?? 'Unknown Link',
      createdAt: (data['createdAt'] as Timestamp).toDate(), // Convert Timestamp to DateTime
    );
  }
}
