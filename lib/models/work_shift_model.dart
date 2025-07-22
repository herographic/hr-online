// lib/models/work_shift_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class WorkShift {
  final String id;
  final String name; 
  final String startTime;
  final String endTime;
  final String typeId; // <-- ฟิลด์ใหม่ที่เพิ่มเข้ามา

  WorkShift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.typeId, // <-- เพิ่มใน constructor
  });

  factory WorkShift.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WorkShift(
      id: doc.id,
      name: data['name'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      typeId: data['typeId'] ?? '', // <-- ดึงข้อมูลจาก Firestore
    );
  }

  String get displayTime => '$name ($startTime - $endTime)';
  String get displayTimeThai => '$name ($startTime - $endTime น.)';
}
