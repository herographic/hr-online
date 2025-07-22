import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hr_online/models/attendance_log_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

// Enum สำหรับระบุสถานะของพนักงาน
enum EmployeeAttendanceStatus {
  checkedIn,  // เข้างานแล้ว (กรอบเขียว)
  checkedOut, // ออกงานแล้ว (กรอบแดง)
  dayOff,     // เป็นวันหยุดตามตาราง (กรอบน้ำเงิน)
  absent,     // เป็นวันทำงานแต่ยังไม่เข้างาน (กรอบเทา)
  unknown     // ยังไม่ทราบสถานะ (Default)
}

class AttendanceStatusProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _attendanceSubscription;
  
  // Map สำหรับเก็บสถานะของพนักงานทุกคน Key คือ employeeId
  Map<String, EmployeeAttendanceStatus> _statuses = {};
  Map<String, Employee> _allEmployees = {};

  bool _isInitialized = false;

  Map<String, EmployeeAttendanceStatus> get statuses => _statuses;

  AttendanceStatusProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    // 1. โหลดข้อมูลพนักงานทั้งหมดเพื่อเช็คตารางวันหยุด
    final employeeSnapshot = await _firestore.collection('users').get();
    _allEmployees = {
      for (var doc in employeeSnapshot.docs)
        doc.id: Employee.fromFirestore(doc)
    };
    
    // 2. เริ่มติดตามข้อมูลการลงเวลาของวันนี้
    listenToAttendanceForDate(DateTime.now());
    _isInitialized = true;
  }

  // ฟังก์ชันสำหรับเริ่มติดตามข้อมูลการลงเวลา ณ วันที่ที่กำหนด
  void listenToAttendanceForDate(DateTime date) {
    // หยุดการติดตามของเก่าก่อน
    _attendanceSubscription?.cancel();

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final attendanceQuery = _firestore
        .collection('attendance_log')
        .where('date', isGreaterThanOrEqualTo: startOfDay)
        .where('date', isLessThanOrEqualTo: endOfDay);

    _attendanceSubscription = attendanceQuery.snapshots().listen((snapshot) {
      _updateStatuses(snapshot.docs, date);
    });
  }

  void _updateStatuses(List<QueryDocumentSnapshot> docs, DateTime date) {
    final newStatuses = <String, EmployeeAttendanceStatus>{};
    final dayOfWeek = DateFormat('EEEE').format(date); // e.g., "Monday"

    // ดึงข้อมูล log ล่าสุดของแต่ละคน
    final attendanceLogs = docs.map((doc) => AttendanceLog.fromFirestore(doc)).toList();
    final latestLogsByEmployee = groupBy(attendanceLogs, (log) => log.employeeId);

    // วนลูปพนักงานทุกคนเพื่อกำหนดสถานะเริ่มต้น
    _allEmployees.forEach((employeeId, employee) {
      final workShiftId = employee.dailyWorkShifts[dayOfWeek];
      final isWorkDay = workShiftId != null && workShiftId.isNotEmpty;

      if (!isWorkDay) {
        newStatuses[employeeId] = EmployeeAttendanceStatus.dayOff; // วันหยุด
      } else {
        newStatuses[employeeId] = EmployeeAttendanceStatus.absent; // วันทำงาน แต่ยังไม่มา
      }
    });

    // อัปเดตสถานะจาก log ที่มี
    latestLogsByEmployee.forEach((employeeId, logs) {
      final latestLog = logs.first; // Stream is ordered, so first is latest
      if (latestLog.checkOut != null) {
        newStatuses[employeeId] = EmployeeAttendanceStatus.checkedOut;
      } else if (latestLog.checkIn != null) {
        newStatuses[employeeId] = EmployeeAttendanceStatus.checkedIn;
      }
    });

    _statuses = newStatuses;
    notifyListeners(); // แจ้งเตือน Widget ที่ใช้งาน Provider นี้ให้ Rebuild
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    super.dispose();
  }
}
