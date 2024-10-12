import 'package:cloud_firestore/cloud_firestore.dart';

class Exam {
  final String id;
  final String classId; // Class ID like FY, SY, etc.
  final List<String> divisions; // Array of divisions like A, B, etc.
  final String subject;
  final int duration;
  final DateTime date; // Keep this as 'date' for consistency with the parameter
  final String examLink;
  final String status;
  final String teacherId; // Field to store which teacher created the exam

  Exam({
    required this.id,
    required this.classId,
    required this.divisions,
    required this.subject,
    required this.duration,
    required this.date, // Keep this as 'date' for consistency with the parameter
    required this.examLink,
    required this.status,
    required this.teacherId, // Teacher who created the exam
  });

  // Factory method to create an Exam object from Firestore data
  factory Exam.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Exam(
      id: doc.id,
      classId: data['classId'],
      divisions: List<String>.from(data['division'] ?? []), // Adjust to use 'division' as in Firestore
      subject: data['subject'],
      duration: data['examDuration'] ?? 0, // Provide default value for duration if missing
      date: (data['examDate'] as Timestamp).toDate(),
      examLink: data['googleFormLink'] ?? '', // Provide default value for link if missing
      status: data['status'] ?? '', // Provide default value for status if missing
      teacherId: data['teacherId'] ?? '', // Ensure teacherId field is fetched and provided default value if missing
    );
  }

  // Method to convert Exam object back to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'classId': classId,
      'division': divisions, // Store as 'division' to match Firestore
      'subject': subject,
      'duration': duration,
      'examDate': date, // Ensure this matches with the 'fromFirestore' method
      'googleFormLink': examLink,
      'status': status,
      'teacherId': teacherId, // Include teacherId when saving the exam
    };
  }
}
