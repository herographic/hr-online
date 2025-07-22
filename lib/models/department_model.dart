import 'package:cloud_firestore/cloud_firestore.dart';

/// Model สำหรับ "แผนก"
class Department {
  final String id; // Document ID จาก Firestore
  final String name;
  final Timestamp createdAt;

  Department({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory Department.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Department(
      id: doc.id,
      name: data['name'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}
