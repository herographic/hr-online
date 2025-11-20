// lib/models/employee_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// --- [START] MODIFIED CODE: New Leveling System ---
class LevelingSystem {
  static const Map<int, String> titles = {
    1: "น้องใหม่",
    5: "สิบตำรวจตรี",
    10: "สิบตำรวจโท",
    15: "สิบตำรวจเอก",
    20: "ร้อยตำรวจตรี",
    25: "ร้อยตำรวจโท",
    30: "ร้อยตำรวจเอก",
    40: "พันตำรวจตรี",
    50: "พันตำรวจโท",
    60: "พันตำรวจเอก",
    70: "พลตำรวจตรี",
    80: "พลตำรวจโท",
    90: "พลตำรวจเอก",
    100: "ผู้บัญชาการตำรวจแห่งชาติ",
  };

  static String getTitleForLevel(int level) {
    int currentTitleLevel = 1;
    for (var titleLevel in titles.keys) {
      if (level >= titleLevel) {
        currentTitleLevel = titleLevel;
      } else {
        break;
      }
    }
    return titles[currentTitleLevel]!;
  }
}
// --- [END] MODIFIED CODE ---

Timestamp _parseTimestamp(dynamic value) {
  if (value is Timestamp) return value;
  if (value is String && value.isNotEmpty) {
    try {
      final parts = value.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final adjustedYear = year > 2500 ? year - 543 : year;
        return Timestamp.fromDate(DateTime(adjustedYear, month, day));
      }
    } catch (e) {
      return Timestamp.now();
    }
  }
  return Timestamp.now();
}

Map<String, dynamic> _parseMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return {};
}

class Employee {
  // Core Information
  final String employeeId;
  final String title;
  final String firstName;
  final String lastName;
  final String nickname;
  final String? profileImageUrl;
  final List<String>? faceDataUrls;

  // Personal Details
  final String gender;
  final Timestamp? birthDate;
  final String nationalId;
  final String maritalStatus;
  final String address;
  final String phoneNumber;
  final Map<String, dynamic> emergencyContact;

  // Additional Contacts & Details
  final Map<String, dynamic> additionalContacts;
  final String details;

  // Work Information
  final String departmentCode;
  final List<Map<String, dynamic>> positions;
  final Timestamp startDate;
  final Map<String, String> dailyWorkShifts;

  // Financial Information
  final num salary;
  final Map<String, dynamic> bankAccount;
  
  final int level;
  final int exp;
  final int nextLevelExp;

  final bool isAdmin;
  final bool isDepartmentHead;
  final bool isOutsource;

  final Timestamp? lastSeen;

  final String? employmentStatus;
  final String? employmentStatusNote;

  Employee({
    required this.employeeId,
    required this.title,
    required this.firstName,
    required this.lastName,
    required this.nickname,
    this.profileImageUrl,
    this.faceDataUrls,
    required this.gender,
    this.birthDate,
    required this.nationalId,
    required this.maritalStatus,
    required this.address,
    required this.phoneNumber,
    required this.emergencyContact,
    required this.additionalContacts,
    required this.details,
    required this.departmentCode,
    required this.positions,
    required this.startDate,
    required this.dailyWorkShifts,
    required this.salary,
    required this.bankAccount,
    this.level = 1,
    this.exp = 0,
    this.nextLevelExp = 100,
    this.lastSeen,
    this.isAdmin = false,
    this.isDepartmentHead = false,
    this.isOutsource = false,
    this.employmentStatus,
    this.employmentStatusNote,
  });

  String get fullName => '$firstName $lastName';
  String get levelTitle => LevelingSystem.getTitleForLevel(level);

  factory Employee.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    List<Map<String, dynamic>> parsedPositions = [];
    if (data['positions'] is List) {
      for (var item in (data['positions'] as List)) {
        if (item is Map) {
          parsedPositions.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return Employee(
      employeeId: (data['employee_code'] ?? doc.id) as String,
      title: data['title'] ?? '',
      firstName: data['employee_name'] ?? '',
      lastName: data['employee_last_name'] ?? '',
      nickname: data['employee_nickname'] ?? '',
      profileImageUrl: data['profile_image_url'],
      faceDataUrls:
          data['faceDataUrls'] != null ? List<String>.from(data['faceDataUrls']) : [],
      gender: data['gender'] ?? 'ไม่ระบุ',
      birthDate: data['birth_date'] is Timestamp ? data['birth_date'] : null,
      nationalId: data['iden_code'] ?? '',
      maritalStatus: data['marital_status'] ?? '',
      address: data['address'] ?? '',
      phoneNumber: data['mobilephone'] ?? '',
      emergencyContact: _parseMap(data['emergency_contact']),
      additionalContacts: _parseMap(data['additionalContacts']),
      details: data['details'] ?? '',
      departmentCode: data['department_code'] ?? '',
      positions: parsedPositions,
      startDate: _parseTimestamp(data['start_date']),
      dailyWorkShifts: Map<String, String>.from(data['dailyWorkShifts'] ?? {}),
      salary: data['salary'] ?? 0,
      bankAccount: _parseMap(data['bank_account']),
      level: data['level'] ?? 1,
      exp: data['exp'] ?? 0,
      nextLevelExp: data['nextLevelExp'] ?? 100,
      lastSeen: data['lastSeen'] as Timestamp?,
      isAdmin: data['isAdmin'] ?? false,
      isDepartmentHead: data['isDepartmentHead'] ?? false,
      isOutsource: data['isOutsource'] ?? false,
      employmentStatus: data['employmentStatus'],
      employmentStatusNote: data['employmentStatusNote'],
    );
  }
}
