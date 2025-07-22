// lib/models/time_update_request_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for storing time update request information.
class TimeUpdateRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeNickname;
  final String employeePosition;

  final Timestamp requestedDate; // วันที่ต้องการแก้ไข
  final String requestedTime; // เวลาที่ต้องการแก้ไข (HH:mm)
  final String attendanceType; // 'checkIn', 'checkOut', 'breakIn', 'breakOut'
  final String reason; // เหตุผล
  
  final String status; // 'pending', 'approved', 'rejected'
  final String? approverId;
  final String? approverName;
  final Timestamp requestedAt; // วันที่ส่งคำร้อง
  final Timestamp? actionAt; // วันที่อนุมัติ/ปฏิเสธ

  TimeUpdateRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeNickname,
    required this.employeePosition,
    required this.requestedDate,
    required this.requestedTime,
    required this.attendanceType,
    required this.reason,
    this.status = 'pending',
    this.approverId,
    this.approverName,
    required this.requestedAt,
    this.actionAt,
  });

  factory TimeUpdateRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TimeUpdateRequest(
      id: doc.id,
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      employeeNickname: data['employeeNickname'] ?? '',
      employeePosition: data['employeePosition'] ?? '',
      requestedDate: data['requestedDate'] ?? Timestamp.now(),
      requestedTime: data['requestedTime'] ?? '',
      attendanceType: data['attendanceType'] ?? '',
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      approverId: data['approverId'],
      approverName: data['approverName'],
      requestedAt: data['requestedAt'] ?? Timestamp.now(),
      actionAt: data['actionAt'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeeNickname': employeeNickname,
      'employeePosition': employeePosition,
      'requestedDate': requestedDate,
      'requestedTime': requestedTime,
      'attendanceType': attendanceType,
      'reason': reason,
      'status': status,
      'approverId': approverId,
      'approverName': approverName,
      'requestedAt': requestedAt,
      'actionAt': actionAt,
    };
  }
}
