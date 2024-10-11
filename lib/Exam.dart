import 'package:cloud_firestore/cloud_firestore.dart';

class Exam {
  final String id; // Unique identifier for the exam
  final String subject;
  final String formLink;
  final DateTime date;
  final int duration;
  final String status;

  Exam({
    required this.id,
    required this.subject,
    required this.formLink,
    required this.date,
    required this.duration,
    required this.status,
  });

  Future<List<String>> getDivisions(String classId) async {
    DocumentSnapshot classDoc = await FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .get();

    if (classDoc.exists) {
      List<dynamic> divisions = classDoc['divisions'];
      return divisions.cast<String>();
    } else {
      return [];
    }
  }

  // Factory method to create an Exam object from Firestore document
  factory Exam.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Exam(
      id: doc.id, // Get the Firestore document ID
      subject: data['subject'] ?? '',
      formLink: data['googleFormLink'] ?? '',
      date: (data['examDate'] as Timestamp).toDate(), // Ensure this is not null
      duration: data['examDuration'] ?? 0,
      status: data['status'] ?? '',
    );
  }
}
