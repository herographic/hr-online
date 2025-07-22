// lib/models/outsource_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for representing an outsource task or project.
class OutsourceTask {
  final String id;
  final String title;
  final String description;
  final num paymentRate;
  final String unit; // e.g., "ชิ้น", "เที่ยว", "วัน"
  final Timestamp createdAt;
  final bool isActive;

  OutsourceTask({
    required this.id,
    required this.title,
    required this.description,
    required this.paymentRate,
    required this.unit,
    required this.createdAt,
    this.isActive = true,
  });

  factory OutsourceTask.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OutsourceTask(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      paymentRate: data['paymentRate'] ?? 0,
      unit: data['unit'] ?? 'N/A',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'paymentRate': paymentRate,
      'unit': unit,
      'createdAt': createdAt,
      'isActive': isActive,
    };
  }
}

/// Model for logging daily work of an outsource person.
class OutsourceWorkLog {
  final String id;
  final String outsourceId; // Links to the user/employee ID (e.g., 990001)
  final String outsourceName;
  final String taskId;
  final String taskTitle;
  final Timestamp date;
  final num quantity;
  final num paymentCalculated;
  final String? notes;
  final Timestamp createdAt;
  final String createdBy; // Admin who logged this entry

  OutsourceWorkLog({
    required this.id,
    required this.outsourceId,
    required this.outsourceName,
    required this.taskId,
    required this.taskTitle,
    required this.date,
    required this.quantity,
    required this.paymentCalculated,
    this.notes,
    required this.createdAt,
    required this.createdBy,
  });

  factory OutsourceWorkLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OutsourceWorkLog(
      id: doc.id,
      outsourceId: data['outsourceId'] ?? '',
      outsourceName: data['outsourceName'] ?? '',
      taskId: data['taskId'] ?? '',
      taskTitle: data['taskTitle'] ?? '',
      date: data['date'] ?? Timestamp.now(),
      quantity: data['quantity'] ?? 0,
      paymentCalculated: data['paymentCalculated'] ?? 0,
      notes: data['notes'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'outsourceId': outsourceId,
      'outsourceName': outsourceName,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'date': date,
      'quantity': quantity,
      'paymentCalculated': paymentCalculated,
      'notes': notes,
      'createdAt': createdAt,
      'createdBy': createdBy,
    };
  }
}
