import 'package:cloud_firestore/cloud_firestore.dart';

class Exam {
  final String id;
  final String classId; // Class ID like FY, SY, etc.
  final List<String> divisions; // Array of divisions like A, B, etc.
  final String subject;
  final int duration; // Duration in minutes
  final DateTime date; // Exam date
  final String examLink; // Link to the Google Form for the exam
  final String status; // Status of the exam
  final String teacherId; // ID of the teacher who created the exam

  Exam({
    required this.id,
    required this.classId,
    required this.divisions,
    required this.subject,
    required this.duration,
    required this.date,
    required this.examLink,
    required this.status,
    required this.teacherId,
  });

  // Factory method to create an Exam object from Firestore data
  factory Exam.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;

    // Check for null data and handle accordingly
    if (data == null) {
      throw Exception('Document data is null');
    }

    return Exam(
      id: doc.id,
      classId: data['classId'] ?? '', // Provide a default if missing
      divisions: List<String>.from(data['division'] ?? []), // Fetch divisions
      subject: data['subject'] ?? '', // Provide default value for subject if missing
      duration: (data['examDuration'] is int) ? data['examDuration'] : 0, // Ensure duration is an int
      date: (data['examDate'] as Timestamp).toDate(),
      examLink: data['googleFormLink'] ?? '', // Default link if missing
      status: data['status'] ?? '', // Default status if missing
      teacherId: data['teacherId'] ?? '', // Default teacherId if missing
    );
  }

  // Method to convert Exam object back to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'classId': classId,
      'division': divisions, // Store as 'division' to match Firestore
      'subject': subject,
      'examDuration': duration, // Ensure this matches Firestore field name
      'examDate': Timestamp.fromDate(date), // Convert DateTime to Timestamp
      'googleFormLink': examLink,
      'status': status,
      'teacherId': teacherId,
    };
  }
}
