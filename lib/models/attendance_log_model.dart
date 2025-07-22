// lib/models/attendance_log_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceLog {
  final String id;
  final String employeeId;
  final Timestamp date;

  final Timestamp? checkIn;
  final Timestamp? checkOut;
  final GeoPoint? checkInLocation;
  final GeoPoint? checkOutLocation;

  final Timestamp? breakOut;
  final Timestamp? breakIn;

  final String? checkInLocationName;
  final String? checkOutLocationName;

  final String status;
  final String markedBy;

  // --- [START] NEW FIELD ---
  /// Flag to indicate if this attendance was on a scheduled day off.
  final bool isCompensationDay;
  // --- [END] NEW FIELD ---

  final String? employeeName;
  final String? employeeNickname;

  AttendanceLog({
    required this.id,
    required this.employeeId,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.checkInLocation,
    this.checkOutLocation,
    this.breakOut,
    this.breakIn,
    this.checkInLocationName,
    this.checkOutLocationName,
    required this.status,
    required this.markedBy,
    this.isCompensationDay = false, // Added to constructor with default value
    this.employeeName,
    this.employeeNickname,
  });

  factory AttendanceLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AttendanceLog(
      id: doc.id,
      employeeId: data['employeeId'] ?? '',
      date: data['date'] ?? Timestamp.now(),
      checkIn: data['checkIn'] as Timestamp?,
      checkOut: data['checkOut'] as Timestamp?,
      checkInLocation: data['checkInLocation'] as GeoPoint?,
      checkOutLocation: data['checkOutLocation'] as GeoPoint?,
      breakOut: data['breakOut'] as Timestamp?,
      breakIn: data['breakIn'] as Timestamp?,
      checkInLocationName: data['checkInLocationName'],
      checkOutLocationName: data['checkOutLocationName'],
      status: data['status'] ?? 'present',
      markedBy: data['markedBy'] ?? '',
      // --- [START] MAPPING FOR NEW FIELD ---
      isCompensationDay: data['isCompensationDay'] ?? false,
      // --- [END] MAPPING FOR NEW FIELD ---
      employeeName: data['employeeName'] ?? '',
      employeeNickname: data['employeeNickname'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'employeeId': employeeId,
      'date': date,
      'checkIn': checkIn,
      'checkOut': checkOut,
      'checkInLocation': checkInLocation,
      'checkOutLocation': checkOutLocation,
      'breakOut': breakOut,
      'breakIn': breakIn,
      'checkInLocationName': checkInLocationName,
      'checkOutLocationName': checkOutLocationName,
      'status': status,
      'markedBy': markedBy,
      // --- [START] ADD NEW FIELD TO MAP ---
      'isCompensationDay': isCompensationDay,
      // --- [END] ADD NEW FIELD TO MAP ---
      'employeeName': employeeName,
      'employeeNickname': employeeNickname,
    };
  }
}
