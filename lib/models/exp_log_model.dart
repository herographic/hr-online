// lib/models/exp_log_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ExpLog {
  final String id;
  final String employeeId;
  final int amount;
  final String sourceType; // เช่น 'rating_received', 'gave_rating', 'submit_work', 'check_in'
  final String sourceDetails; // เช่น 'Like from John Doe', 'Check-in on 2024-07-26'
  final Timestamp timestamp;

  ExpLog({
    required this.id,
    required this.employeeId,
    required this.amount,
    required this.sourceType,
    required this.sourceDetails,
    required this.timestamp,
  });

  factory ExpLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpLog(
      id: doc.id,
      employeeId: data['employeeId'] ?? '',
      amount: data['amount'] ?? 0,
      sourceType: data['sourceType'] ?? 'unknown',
      sourceDetails: data['sourceDetails'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'employeeId': employeeId,
      'amount': amount,
      'sourceType': sourceType,
      'sourceDetails': sourceDetails,
      'timestamp': timestamp,
    };
  }
}
