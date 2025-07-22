// lib/models/job_posting_model.dart
// หมายเหตุ: ไฟล์นี้จะถูกใช้ในทั้งสองโปรเจกต์ (hr-online และ register-hr)
import 'package:cloud_firestore/cloud_firestore.dart';

class JobPosting {
  final String id;
  final String departmentId;
  final String departmentName;
  final String positionId;
  final String positionName;
  final String jobDetails;
  final int openings; // จำนวนอัตรา
  final String compensation; // ค่าตอบแทน
  final String educationLevel; // วุฒิการศึกษา
  final String workLocation; // สถานที่ปฏิบัติงาน
  final String gender; // เพศ
  final String benefits; // สวัสดิการ
  final Timestamp applicationStartDate;
  final Timestamp applicationEndDate;
  final String workShiftInfo; // เวลาที่เข้างาน
  final String? positionImageUrl; // รูปของตำแหน่งงาน
  final List<String> workImageUrls; // รูปภาพประกอบลักษณะงาน
  final List<String> requiredDocuments; // เอกสารที่ใช้
  final String specialConsiderations; // ลักษณะที่ต้องการ
  final String contactPhone; // เบอร์โทรติดต่อ
  final String postedBy; // ID ผู้โพสต์
  final String postedByName; // ชื่อผู้โพสต์
  final Timestamp postedAt;
  final bool isUrgent; // ด่วน

  JobPosting({
    required this.id,
    required this.departmentId,
    required this.departmentName,
    required this.positionId,
    required this.positionName,
    required this.jobDetails,
    required this.openings,
    required this.compensation,
    required this.educationLevel,
    required this.workLocation,
    required this.gender,
    required this.benefits,
    required this.applicationStartDate,
    required this.applicationEndDate,
    required this.workShiftInfo,
    this.positionImageUrl,
    this.workImageUrls = const [],
    this.requiredDocuments = const [],
    required this.specialConsiderations,
    required this.contactPhone,
    required this.postedBy,
    required this.postedByName,
    required this.postedAt,
    required this.isUrgent,
  });

  factory JobPosting.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobPosting(
      id: doc.id,
      departmentId: data['departmentId'] ?? '',
      departmentName: data['departmentName'] ?? '',
      positionId: data['positionId'] ?? '',
      positionName: data['positionName'] ?? '',
      jobDetails: data['jobDetails'] ?? '',
      openings: data['openings'] ?? 0,
      compensation: data['compensation'] ?? '',
      educationLevel: data['educationLevel'] ?? '',
      workLocation: data['workLocation'] ?? '',
      gender: data['gender'] ?? 'ไม่ระบุ',
      benefits: data['benefits'] ?? '',
      applicationStartDate: data['applicationStartDate'] ?? Timestamp.now(),
      applicationEndDate: data['applicationEndDate'] ?? Timestamp.now(),
      workShiftInfo: data['workShiftInfo'] ?? '',
      positionImageUrl: data['positionImageUrl'],
      workImageUrls: List<String>.from(data['workImageUrls'] ?? []),
      requiredDocuments: List<String>.from(data['requiredDocuments'] ?? []),
      specialConsiderations: data['specialConsiderations'] ?? '',
      contactPhone: data['contactPhone'] ?? '',
      postedBy: data['postedBy'] ?? '',
      postedByName: data['postedByName'] ?? '',
      postedAt: data['postedAt'] ?? Timestamp.now(),
      isUrgent: data['isUrgent'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'departmentId': departmentId,
      'departmentName': departmentName,
      'positionId': positionId,
      'positionName': positionName,
      'jobDetails': jobDetails,
      'openings': openings,
      'compensation': compensation,
      'educationLevel': educationLevel,
      'workLocation': workLocation,
      'gender': gender,
      'benefits': benefits,
      'applicationStartDate': applicationStartDate,
      'applicationEndDate': applicationEndDate,
      'workShiftInfo': workShiftInfo,
      'positionImageUrl': positionImageUrl,
      'workImageUrls': workImageUrls,
      'requiredDocuments': requiredDocuments,
      'specialConsiderations': specialConsiderations,
      'contactPhone': contactPhone,
      'postedBy': postedBy,
      'postedByName': postedByName,
      'postedAt': postedAt,
      'isUrgent': isUrgent,
    };
  }
}