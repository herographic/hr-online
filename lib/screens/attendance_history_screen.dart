// lib/screens/attendance_history_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/attendance_log_model.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/work_shift_model.dart';
import 'package:hr_online/widgets/app_layout.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:collection/collection.dart';

class AttendanceRowData {
  final String date;
  final String locationIn;
  final String locationOut;
  final String status;
  final Color statusColor;
  final String checkIn;
  final String breakOut;
  final String breakIn;
  final String checkOut;
  final Duration workDuration;
  final Duration otDuration;

  AttendanceRowData({
    required this.date,
    required this.locationIn,
    required this.locationOut,
    required this.status,
    required this.statusColor,
    required this.checkIn,
    required this.breakOut,
    required this.breakIn,
    required this.checkOut,
    required this.workDuration,
    required this.otDuration,
  });
}

class AttendanceSummary {
  final int workDays;
  final Duration totalDuration;
  final int absentDays;
  final int lateDays;

  AttendanceSummary({
    required this.workDays,
    required this.totalDuration,
    required this.absentDays,
    required this.lateDays,
  });
}

class AttendanceHistoryScreen extends StatefulWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const AttendanceHistoryScreen({
    super.key,
    required this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  DateTime _focusedMonth = DateTime.now();
  List<AttendanceRowData> _calculatedLogs = [];
  AttendanceSummary? _summary;
  bool _isLoading = true;
  bool _isExporting = false;

  List<Employee> _allEmployees = [];
  List<WorkShift> _allWorkShifts = [];
  List<Department> _allDepartments = [];
  Employee? _selectedEmployee;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final employeesFuture =
          FirebaseFirestore.instance.collection('users').get();
      final shiftsFuture =
          FirebaseFirestore.instance.collection('work_shifts').get();
      final deptsFuture =
          FirebaseFirestore.instance.collection('departments').get();

      final results =
          await Future.wait([employeesFuture, shiftsFuture, deptsFuture]);

      final employeeSnapshot = results[0];
      final shiftSnapshot = results[1];
      final deptSnapshot = results[2];

      if (mounted) {
        _allEmployees = employeeSnapshot.docs
            .map((doc) => Employee.fromFirestore(doc))
            .toList();
        _allWorkShifts = shiftSnapshot.docs
            .map((doc) => WorkShift.fromFirestore(doc))
            .toList();
        _allDepartments = deptSnapshot.docs
            .map((doc) => Department.fromFirestore(doc))
            .toList();

        if (widget.isUserAdmin) {
          setState(() => _isLoading = false);
        } else {
          _selectedEmployee = _allEmployees.firstWhereOrNull(
              (e) => e.employeeId == widget.loggedInEmployee?.employeeId);
          _fetchAndCalculateDataForEmployee(_focusedMonth, _selectedEmployee);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลเริ่มต้น: $e')));
      }
    }
  }

  void _changeMonth(int monthIncrement) {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + monthIncrement, 1);
      _summary = null;
    });
    if (_selectedEmployee != null) {
      _fetchAndCalculateDataForEmployee(_focusedMonth, _selectedEmployee);
    }
  }

  Future<List<AttendanceRowData>> _fetchAndCalculateDataForEmployee(
      DateTime month, Employee? employee) async {
    if (employee == null) {
      if (mounted) {
        setState(() {
          _calculatedLogs = [];
          _summary = null;
          _isLoading = false;
        });
      }
      return [];
    }

    if (mounted) setState(() => _isLoading = true);

    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    try {
      final logSnapshot = await FirebaseFirestore.instance
          .collection('attendance_log')
          .where('employeeId', isEqualTo: employee.employeeId)
          .where('date', isGreaterThanOrEqualTo: firstDayOfMonth)
          .where('date', isLessThanOrEqualTo: lastDayOfMonth)
          .orderBy('date', descending: true)
          .get();

      final logs =
          logSnapshot.docs.map((doc) => AttendanceLog.fromFirestore(doc)).toList();

      List<AttendanceRowData> calculatedData = [];
      for (var log in logs) {
        calculatedData.add(_calculateRowData(log, employee, _allWorkShifts));
      }

      if (mounted) {
        _calculateSummary(calculatedData);
        setState(() {
          _calculatedLogs = calculatedData;
          _isLoading = false;
        });
      }
      return calculatedData;
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'เกิดข้อผิดพลาด: $e. อาจจะต้องสร้าง Index ใน Firestore')));
      }
      return [];
    }
  }

  void _calculateSummary(List<AttendanceRowData> logs) {
    int workDays = 0;
    Duration totalDuration = Duration.zero;
    int absentDays = 0;
    int lateDays = 0;

    for (final log in logs) {
      if (log.status == 'ปกติ' || log.status == 'มาสาย') {
        workDays++;
        totalDuration += log.workDuration + log.otDuration;
      }
      if (log.status == 'ขาดงาน') {
        absentDays++;
      }
      if (log.status == 'มาสาย') {
        lateDays++;
      }
    }

    setState(() {
      _summary = AttendanceSummary(
        workDays: workDays,
        totalDuration: totalDuration,
        absentDays: absentDays,
        lateDays: lateDays,
      );
    });
  }

  AttendanceRowData _calculateRowData(
      AttendanceLog log, Employee employee, List<WorkShift> allShifts) {
    final logDate = log.date.toDate();
    final dayOfWeek = DateFormat('EEEE').format(logDate);

    final shiftId = employee.dailyWorkShifts[dayOfWeek];
    final workShift = allShifts.firstWhereOrNull((s) => s.id == shiftId);

    DateTime? scheduledCheckIn;
    DateTime? scheduledCheckOut;
    Duration fullShiftDuration = Duration.zero;

    if (workShift != null) {
      try {
        final startParts = workShift.startTime.split(':');
        final endParts = workShift.endTime.split(':');
        scheduledCheckIn = DateTime(logDate.year, logDate.month, logDate.day,
            int.parse(startParts[0]), int.parse(startParts[1]));
        scheduledCheckOut = DateTime(logDate.year, logDate.month, logDate.day,
            int.parse(endParts[0]), int.parse(endParts[1]));
        if (scheduledCheckOut.isBefore(scheduledCheckIn)) {
          scheduledCheckOut = scheduledCheckOut.add(const Duration(days: 1));
        }
        fullShiftDuration = scheduledCheckOut.difference(scheduledCheckIn);
      } catch (e) {
        /* Ignore parsing errors */
      }
    }

    final actualCheckIn = log.checkIn?.toDate();
    final actualCheckOut = log.checkOut?.toDate();
    final timeFormat = DateFormat('HH:mm');

    String status = 'วันหยุด';
    Color statusColor = Colors.grey.shade600;
    Duration workDuration = Duration.zero;
    Duration otDuration = Duration.zero;

    if (scheduledCheckIn != null) {
      if (actualCheckIn != null) {
        if (actualCheckIn.isAfter(scheduledCheckIn.add(const Duration(minutes: 1)))) {
          status = 'มาสาย';
          statusColor = Colors.orange.shade800;
        } else {
          status = 'ปกติ';
          statusColor = Colors.green.shade700;
        }

        if (actualCheckOut != null) {
          Duration totalDuration = actualCheckOut.difference(actualCheckIn);
          if (totalDuration.isNegative) totalDuration = Duration.zero;

          final overlapStart = actualCheckIn.isAfter(scheduledCheckIn)
              ? actualCheckIn
              : scheduledCheckIn;
          final overlapEnd = actualCheckOut.isBefore(scheduledCheckOut!)
              ? actualCheckOut
              : scheduledCheckOut;

          if (overlapEnd.isAfter(overlapStart)) {
            workDuration = overlapEnd.difference(overlapStart);
          }

          otDuration = totalDuration - workDuration;
          if (otDuration.isNegative) otDuration = Duration.zero;
        } else {
          workDuration = Duration(minutes: (fullShiftDuration.inMinutes ~/ 2));
          otDuration = Duration.zero;
        }
      } else {
        status = 'ขาดงาน';
        statusColor = Colors.red.shade700;
      }
    }

    return AttendanceRowData(
      date: DateFormat('d MMM yy', 'th_TH').format(logDate),
      locationIn: log.checkInLocationName ?? '-',
      locationOut: log.checkOutLocationName ?? '-',
      status: status,
      statusColor: statusColor,
      checkIn: actualCheckIn != null ? timeFormat.format(actualCheckIn) : '-',
      breakOut: log.breakOut != null ? timeFormat.format(log.breakOut!.toDate()) : '-',
      breakIn: log.breakIn != null ? timeFormat.format(log.breakIn!.toDate()) : '-',
      checkOut:
          actualCheckOut != null ? timeFormat.format(actualCheckOut) : '-',
      workDuration: workDuration,
      otDuration: otDuration,
    );
  }

  // --- [START] REVERTED CODE ---
  // Reverted to the old format that displays "ชม." (hours) and "น." (minutes).
  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) return '-';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return "${hours}ชม.${minutes}น.";
  }
  // --- [END] REVERTED CODE ---

  Future<void> _handleExport() async {
    if (_selectedEmployee != null) {
      await _exportSingleEmployeeToExcel();
    } else {
      await _exportAllEmployeesToExcel();
    }
  }

  Future<void> _exportSingleEmployeeToExcel() async {
    if (_selectedEmployee == null || _calculatedLogs.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ไม่มีข้อมูลสำหรับ Export')));
      return;
    }

    setState(() => _isExporting = true);

    try {
      var excelFile = Excel.createExcel();
      Sheet sheetObject = excelFile['ประวัติการลงเวลา'];

      _populateSheetWithData(sheetObject, _selectedEmployee!, _calculatedLogs);

      final fileBytes = excelFile.save();
      if (fileBytes != null) {
        final directory = await getTemporaryDirectory();
        final fileName =
            'Attendance_${_selectedEmployee!.employeeId}_${DateFormat('yyyy-MM').format(_focusedMonth)}.xlsx';
        final filePath = '${directory.path}/$fileName';

        final file = File(filePath);
        await file.writeAsBytes(fileBytes, flush: true);

        await Share.shareXFiles([XFile(filePath)],
            text:
                'รายงานการลงเวลาของ ${_selectedEmployee!.fullName} ประจำเดือน ${DateFormat.yMMMM('th_TH').format(_focusedMonth)}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการสร้างไฟล์ Excel: $e')));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportAllEmployeesToExcel() async {
    setState(() => _isExporting = true);

    try {
      var excelFile = Excel.createExcel();
      excelFile.delete('Sheet1'); // Remove default sheet

      for (final employee in _allEmployees) {
        final employeeLogs =
            await _fetchAndCalculateDataForEmployee(_focusedMonth, employee);

        if (employeeLogs.isNotEmpty) {
          Sheet sheetObject = excelFile['${employee.employeeId}_${employee.nickname}'];
          _populateSheetWithData(sheetObject, employee, employeeLogs);
        }
      }

      final fileBytes = excelFile.save();
      if (fileBytes != null) {
        final directory = await getTemporaryDirectory();
        final fileName =
            'All_Attendance_${DateFormat('yyyy-MM').format(_focusedMonth)}.xlsx';
        final filePath = '${directory.path}/$fileName';

        final file = File(filePath);
        await file.writeAsBytes(fileBytes, flush: true);

        await Share.shareXFiles([XFile(filePath)],
            text:
                'รายงานการลงเวลาทั้งหมด ประจำเดือน ${DateFormat.yMMMM('th_TH').format(_focusedMonth)}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการสร้างไฟล์รวม: $e')));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // --- [START] REVERTED CODE ---
  // Reverted to the simpler Excel population method without extra styling.
  void _populateSheetWithData(Sheet sheetObject, Employee employee,
      List<AttendanceRowData> logs) {
    final positionNames = employee.positions.isNotEmpty
        ? employee.positions.map((p) => p['name'] ?? '').join(', ')
        : 'N/A';
    sheetObject.appendRow([TextCellValue('รายงานการลงเวลา')]);
    sheetObject.appendRow(
        [TextCellValue('ชื่อ-สกุล:'), TextCellValue(employee.fullName)]);
    sheetObject.appendRow([
      TextCellValue('รหัสพนักงาน:'),
      TextCellValue(employee.employeeId)
    ]);
    sheetObject
        .appendRow([TextCellValue('ตำแหน่ง:'), TextCellValue(positionNames)]);
    sheetObject.appendRow([
      TextCellValue('ประจำเดือน:'),
      TextCellValue(DateFormat.yMMMM('th_TH').format(_focusedMonth))
    ]);
    sheetObject.appendRow([]);

    List<String> headers = [
      'วันที่', 'สถานที่เข้า', 'สถานที่ออก', 'สถานะ', 'เวลาเข้า', 'ออกพัก', 'เข้าพัก', 'เวลาออก', 'ชั่วโมงทำงาน', 'ล่วงเวลา', 'รวม'
    ];
    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    for (var data in logs) {
      List<String> row = [
        data.date,
        data.locationIn,
        data.locationOut,
        data.status,
        data.checkIn,
        data.breakOut,
        data.breakIn,
        data.checkOut,
        _formatDuration(data.workDuration),
        _formatDuration(data.otDuration),
        _formatDuration(data.workDuration + data.otDuration),
      ];
      sheetObject.appendRow(row.map((e) => TextCellValue(e)).toList());
    }
  }
  // --- [END] REVERTED CODE ---

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      isUserAdmin: widget.isUserAdmin,
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'ประวัติการลงเวลา',
      showBackButton: false,
      bodySlivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (widget.isUserAdmin) _buildAdminEmployeeSelector(),
                _buildMonthNavigator(),
                if (_selectedEmployee != null) ...[
                  const SizedBox(height: 12),
                  _buildWeeklyScheduleTable(_selectedEmployee!, _allWorkShifts),
                ],
                if (widget.isUserAdmin) ...[
                  const SizedBox(height: 12),
                  _buildExportButton(),
                ],
              ],
            ),
          ),
        ),
        _buildHistoryList(),
        if (_summary != null)
          SliverToBoxAdapter(child: _buildSummaryCard(_summary!)),
      ],
    );
  }

  Widget _buildSummaryCard(AttendanceSummary summary) {
    final totalHours = summary.totalDuration.inHours;
    final totalMinutes = summary.totalDuration.inMinutes.remainder(60);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'สรุปประจำเดือน',
                style: GoogleFonts.anuphan(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const Divider(color: Colors.white54, height: 24),
              _buildSummaryRow('เดือนนี้ทำงานมาแล้ว:', '${summary.workDays} วัน'),
              _buildSummaryRow('รวมเวลาทำงาน:', '$totalHours ชม. $totalMinutes นาที'),
              _buildSummaryRow('ขาดงาน:', '${summary.absentDays} วัน',
                  isHighlight: summary.absentDays > 0),
              _buildSummaryRow('มาสาย:', '${summary.lateDays} วัน',
                  isHighlight: summary.lateDays > 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.anuphan(
                  fontSize: 16, color: Colors.white.withOpacity(0.9))),
          Text(
            value,
            style: GoogleFonts.anuphan(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isHighlight ? Colors.amber.shade300 : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminEmployeeSelector() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.person_search_outlined),
        title: Text(
          _selectedEmployee?.fullName ?? 'พนักงานทั้งหมด',
          style: GoogleFonts.anuphan(),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_drop_down),
        onTap: _showEmployeeSelectionDialog,
      ),
    );
  }

  Future<void> _showEmployeeSelectionDialog() async {
    final departmentMap = {for (var dept in _allDepartments) dept.id: dept.name};

    final Employee? result = await showDialog<Employee>(
      context: context,
      builder: (BuildContext context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredEmployees = _allEmployees.where((emp) {
              final deptName =
                  departmentMap[emp.departmentCode]?.toLowerCase() ?? '';
              final query = searchQuery.toLowerCase();
              if (query.isEmpty) return true;
              return emp.fullName.toLowerCase().contains(query) ||
                  emp.nickname.toLowerCase().contains(query) ||
                  emp.employeeId.contains(query) ||
                  deptName.contains(query);
            }).toList();

            return AlertDialog(
              title: const Text('เลือกพนักงาน'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) =>
                          setDialogState(() => searchQuery = value),
                      decoration: const InputDecoration(
                        labelText: 'ค้นหา (ชื่อ, รหัส, แผนก)...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.group),
                      title: const Text('พนักงานทั้งหมด'),
                      onTap: () => Navigator.of(context).pop(null),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredEmployees.length,
                        itemBuilder: (context, index) {
                          final employee = filteredEmployees[index];
                          return ListTile(
                            title: Text(employee.fullName),
                            subtitle: Text(
                                'ID: ${employee.employeeId} | แผนก: ${departmentMap[employee.departmentCode] ?? 'N/A'}'),
                            onTap: () => Navigator.of(context).pop(employee),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('ยกเลิก')),
              ],
            );
          },
        );
      },
    );

    if (result != _selectedEmployee) {
      setState(() {
        _selectedEmployee = result;
        _summary = null;
        _calculatedLogs = [];
      });
      if (result != null) {
        _fetchAndCalculateDataForEmployee(_focusedMonth, result);
      }
    }
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isExporting ? null : _handleExport,
        icon: _isExporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.download_for_offline_outlined),
        label: Text(_isExporting
            ? 'กำลังสร้างไฟล์...'
            : (_selectedEmployee == null
                ? 'Export ข้อมูลทั้งหมด'
                : 'Export ข้อมูล ${_selectedEmployee!.nickname}')),
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white),
      ),
    );
  }

  Widget _buildMonthNavigator() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1)),
            Text(DateFormat.yMMMM('th_TH').format(_focusedMonth),
                style: GoogleFonts.anuphan(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1)),
          ],
        ),
      ),
    );
  }

  String _formatShiftTime(String time) {
    if (time.endsWith(':00')) {
      return time.substring(0, time.length - 3);
    }
    return time;
  }

  Widget _buildWeeklyScheduleTable(
      Employee employee, List<WorkShift> allShifts) {
    const Map<String, String> weekdays = {
      'Monday': 'จันทร์',
      'Tuesday': 'อังคาร',
      'Wednesday': 'พุธ',
      'Thursday': 'พฤหัสฯ',
      'Friday': 'ศุกร์',
      'Saturday': 'เสาร์',
      'Sunday': 'อาทิตย์'
    };

    List<Widget> buildRow() {
      return weekdays.keys.map((dayKey) {
        final shiftId = employee.dailyWorkShifts[dayKey];
        String shiftDisplay = "หยุด";
        Color textColor = Colors.red.shade700;

        if (shiftId != null && shiftId.isNotEmpty) {
          final shift = allShifts.firstWhereOrNull((s) => s.id == shiftId);
          shiftDisplay = shift != null
              ? '${_formatShiftTime(shift.startTime)}-${_formatShiftTime(shift.endTime)}'
              : 'N/A';
          textColor = Colors.black87;
        }

        return Expanded(
          child: Text(
            shiftDisplay,
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
                fontSize: 11, color: textColor, fontWeight: FontWeight.w600),
          ),
        );
      }).toList();
    }

    return Card(
      color: Colors.white.withOpacity(0.9),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: weekdays.values
                  .map((dayName) => Expanded(
                        child: Text(
                          dayName,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.anuphan(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ))
                  .toList(),
            ),
            const Divider(height: 8),
            Row(
              children: buildRow(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_isLoading) {
      return const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()));
    }
    if (widget.isUserAdmin && _selectedEmployee == null) {
      return const SliverFillRemaining(
          child: Center(
              child: Text(
                  'เลือกพนักงานเพื่อดูประวัติ หรือกด Export ข้อมูลทั้งหมด',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16))));
    }
    if (_calculatedLogs.isEmpty && _selectedEmployee != null) {
      return const SliverFillRemaining(
          child: Center(
              child: Text('ไม่มีข้อมูลการลงเวลาในเดือนที่เลือก',
                  style: TextStyle(color: Colors.white))));
    }
    if (_calculatedLogs.isEmpty && _selectedEmployee == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Card(
            elevation: 4,
            clipBehavior: Clip.antiAlias,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: DataTable(
              columnSpacing: 20,
              headingRowColor: MaterialStateProperty.all(Colors.blueGrey.shade50),
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              columns: [
                'วันที่', 'สถานที่เข้า', 'สถานที่ออก', 'สถานะ', 'เข้า', 'ออกพัก', 'เข้าพัก', 'ออก', 'ชม.', 'โอที', 'รวม'
              ]
                  .map((h) => DataColumn(
                      label: Center(
                          child: Text(h,
                              style: GoogleFonts.anuphan(
                                  fontWeight: FontWeight.bold)))))
                  .toList(),
              rows: _calculatedLogs.map((data) {
                return DataRow(cells: [
                  DataCell(Center(
                      child: Text(data.date, style: GoogleFonts.anuphan()))),
                  DataCell(Center(
                      child: Text(data.locationIn,
                          style: GoogleFonts.anuphan()))),
                  DataCell(Center(
                      child: Text(data.locationOut,
                          style: GoogleFonts.anuphan()))),
                  DataCell(Center(
                      child: Text(data.status,
                          style: GoogleFonts.anuphan(
                              color: data.statusColor,
                              fontWeight: FontWeight.bold)))),
                  DataCell(Center(
                      child: Text(data.checkIn, style: GoogleFonts.anuphan()))),
                  DataCell(Center(
                      child: Text(data.breakOut, style: GoogleFonts.anuphan()))),
                  DataCell(Center(
                      child: Text(data.breakIn, style: GoogleFonts.anuphan()))),
                  DataCell(Center(
                      child: Text(data.checkOut, style: GoogleFonts.anuphan()))),
                  DataCell(Center(
                      child: Text(_formatDuration(data.workDuration),
                          style: GoogleFonts.anuphan()))),
                  DataCell(Center(
                      child: Text(_formatDuration(data.otDuration),
                          style: GoogleFonts.anuphan()))),
                  DataCell(Center(
                      child: Text(
                          _formatDuration(data.workDuration + data.otDuration),
                          style: GoogleFonts.anuphan(
                              fontWeight: FontWeight.bold)))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
