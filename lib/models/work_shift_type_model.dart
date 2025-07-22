// lib/models/work_shift_type_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class WorkShiftType {
  final String id;
  final String name; // e.g., "Full-time", "Part-time"

  WorkShiftType({required this.id, required this.name});

  factory WorkShiftType.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WorkShiftType(
      id: doc.id,
      name: data['name'] ?? '',
    );
  }
}
