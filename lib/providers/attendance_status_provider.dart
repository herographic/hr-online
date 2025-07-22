// lib/providers/attendance_status_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hr_online/models/attendance_log_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

// Enum for specifying employee attendance status
enum EmployeeAttendanceStatus {
  checkedIn,  // Checked in (Green border)
  onBreak,    // On break (Orange border)
  checkedOut, // Checked out (Red border)
  dayOff,     // Scheduled day off (Blue border)
  absent,     // Working day but not checked in (Gray border)
  unknown     // Status not yet known (Default)
}

class AttendanceStatusProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _attendanceSubscription;
  
  // Map to store the status of all employees, with employeeId as the key
  Map<String, EmployeeAttendanceStatus> _statuses = {};
  Map<String, Employee> _allEmployees = {};

  bool _isInitialized = false;

  Map<String, EmployeeAttendanceStatus> get statuses => _statuses;

  AttendanceStatusProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    // 1. Load all employee data to check their holiday schedule
    final employeeSnapshot = await _firestore.collection('users').get();
    _allEmployees = {
      for (var doc in employeeSnapshot.docs)
        doc.id: Employee.fromFirestore(doc)
    };
    
    // 2. Start tracking today's attendance data
    listenToAttendanceForDate(DateTime.now());
    _isInitialized = true;
  }

  // Function to start tracking attendance data for a specific date
  void listenToAttendanceForDate(DateTime date) {
    // Stop previous tracking first
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

    // Get the latest log for each person
    final attendanceLogs = docs.map((doc) => AttendanceLog.fromFirestore(doc)).toList();
    final latestLogsByEmployee = groupBy(attendanceLogs, (log) => log.employeeId);

    // Loop through all employees to set their initial status
    _allEmployees.forEach((employeeId, employee) {
      final workShiftId = employee.dailyWorkShifts[dayOfWeek];
      final isWorkDay = workShiftId != null && workShiftId.isNotEmpty;

      if (!isWorkDay) {
        newStatuses[employeeId] = EmployeeAttendanceStatus.dayOff; // Holiday
      } else {
        newStatuses[employeeId] = EmployeeAttendanceStatus.absent; // Working day, but not yet arrived
      }
    });

    // Update status from existing logs
    latestLogsByEmployee.forEach((employeeId, logs) {
      // Assuming logs are ordered by timestamp, the first one is the latest
      final latestLog = logs.first; 
      
      // --- [START] MODIFIED STATUS LOGIC ---
      if (latestLog.checkOut != null) {
        newStatuses[employeeId] = EmployeeAttendanceStatus.checkedOut; // Checked out
      } else if (latestLog.breakIn != null) {
        newStatuses[employeeId] = EmployeeAttendanceStatus.checkedIn; // Returned from break, so back to checked-in
      } else if (latestLog.breakOut != null) {
        newStatuses[employeeId] = EmployeeAttendanceStatus.onBreak; // On break
      } else if (latestLog.checkIn != null) {
        newStatuses[employeeId] = EmployeeAttendanceStatus.checkedIn; // Checked in
      }
      // --- [END] MODIFIED STATUS LOGIC ---
    });

    _statuses = newStatuses;
    notifyListeners(); // Notify widgets using this Provider to rebuild
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    super.dispose();
  }
}
