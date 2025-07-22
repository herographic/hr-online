// lib/models/position_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Position {
  final String id;
  final String name;
  final String departmentId; // <-- ฟิลด์นี้สำคัญมาก

  Position({
    required this.id,
    required this.name,
    required this.departmentId,
  });

  factory Position.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Position(
      id: doc.id,
      name: data['name'] ?? '',
      departmentId: data['departmentId'] ?? '', // ตรวจสอบว่ามี field นี้ใน Firestore
    );
  }
}
