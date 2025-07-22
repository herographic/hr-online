import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for storing leave request information.
class LeaveRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeNickname;
  final String departmentId;
  final String leaveType; // ประเภทการลา
  final Timestamp startDate; // วันที่เริ่มลา
  final Timestamp endDate; // วันที่สิ้นสุดการลา
  final String reason; // เหตุผล
  final String? attachmentUrl; // URL ของไฟล์แนบ
  final String? attachmentFileName; // ชื่อไฟล์แนบ
  final String status; // 'pending', 'approved', 'rejected'
  final String? approverId; // ID ผู้อนุมัติ
  final String? approverName; // ชื่อผู้อนุมัติ
  final String? approverComment; // ความเห็นผู้อนุมัติ
  final String? signatureUrl; // URL ลายเซ็น
  final Timestamp requestedAt; // วันที่ยื่นเรื่อง
  final Timestamp? actionAt; // วันที่อนุมัติ/ปฏิเสธ

  LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeNickname,
    required this.departmentId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.attachmentUrl,
    this.attachmentFileName,
    required this.status,
    this.approverId,
    this.approverName,
    this.approverComment,
    this.signatureUrl,
    required this.requestedAt,
    this.actionAt,
  });

  factory LeaveRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaveRequest(
      id: doc.id,
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      employeeNickname: data['employeeNickname'] ?? '',
      departmentId: data['departmentId'] ?? '',
      leaveType: data['leaveType'] ?? '',
      startDate: data['startDate'] ?? Timestamp.now(),
      endDate: data['endDate'] ?? Timestamp.now(),
      reason: data['reason'] ?? '',
      attachmentUrl: data['attachmentUrl'],
      attachmentFileName: data['attachmentFileName'],
      status: data['status'] ?? 'pending',
      approverId: data['approverId'],
      approverName: data['approverName'],
      approverComment: data['approverComment'],
      signatureUrl: data['signatureUrl'],
      requestedAt: data['requestedAt'] ?? Timestamp.now(),
      actionAt: data['actionAt'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeeNickname': employeeNickname,
      'departmentId': departmentId,
      'leaveType': leaveType,
      'startDate': startDate,
      'endDate': endDate,
      'reason': reason,
      'attachmentUrl': attachmentUrl,
      'attachmentFileName': attachmentFileName,
      'status': status,
      'approverId': approverId,
      'approverName': approverName,
      'approverComment': approverComment,
      'signatureUrl': signatureUrl,
      'requestedAt': requestedAt,
      'actionAt': actionAt,
    };
  }
}

