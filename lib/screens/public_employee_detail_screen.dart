// lib/screens/public_employee_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/work_shift_model.dart';
import 'package:hr_online/widgets/employee_avatar.dart';
import 'package:hr_online/widgets/experience_bar.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class PublicEmployeeDetailScreen extends StatelessWidget {
  final Employee employee;

  const PublicEmployeeDetailScreen({super.key, required this.employee});

  Future<Map<String, dynamic>> _fetchRelatedData() async {
    final departmentsFuture = FirebaseFirestore.instance.collection('departments').get();
    final workShiftsFuture = FirebaseFirestore.instance.collection('work_shifts').get();

    final results = await Future.wait([departmentsFuture, workShiftsFuture]);

    final departments = (results[0] as QuerySnapshot).docs.map((doc) => Department.fromFirestore(doc)).toList();
    final workShifts = (results[1] as QuerySnapshot).docs.map((doc) => WorkShift.fromFirestore(doc)).toList();

    final department = departments.firstWhereOrNull((d) => d.id == employee.departmentCode);

    return {
      'departmentName': department?.name ?? 'ยังไม่ได้กำหนด',
      'allWorkShifts': workShifts,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ข้อมูล: ${employee.nickname}'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchRelatedData(),
        builder: (context, relatedDataSnapshot) {
          if (relatedDataSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final departmentName = relatedDataSnapshot.data?['departmentName'] ?? 'N/A';
          final allWorkShifts = relatedDataSnapshot.data?['allWorkShifts'] ?? <WorkShift>[];

          return _buildUI(context, departmentName, allWorkShifts);
        },
      ),
    );
  }

  Widget _buildUI(BuildContext context, String departmentName, List<WorkShift> allWorkShifts) {
    final thaiDateFormat = DateFormat('d MMMM yyyy', 'th_TH');
    final positionNames = employee.positions.isNotEmpty
        ? employee.positions.map((p) => p['name'] ?? '').join(', ')
        : 'ยังไม่ได้กำหนด';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildExperienceCard(),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            title: 'ข้อมูลการทำงาน',
            icon: Icons.work_outline,
            children: [
              _buildInfoRow('รหัสพนักงาน:', employee.employeeId),
              _buildInfoRow('แผนก:', departmentName),
              _buildInfoRow('ตำแหน่ง:', positionNames),
              _buildInfoRow('วันเริ่มงาน:', thaiDateFormat.format(employee.startDate.toDate())),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text("ตารางทำงานประจำสัปดาห์", style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
              ),
              _buildWeeklyScheduleTable(allWorkShifts),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF00c6ff), Color(0xFF0072ff)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ExperienceBar(employee: employee),
      ),
    );
  }
  
  String _formatShiftTime(String time) {
    if (time.endsWith(':00')) {
      return time.substring(0, time.length - 3);
    }
    return time;
  }

  Widget _buildWeeklyScheduleTable(List<WorkShift> allShifts) {
    const Map<String, String> weekdays = {
      'Monday': 'จ', 'Tuesday': 'อ', 'Wednesday': 'พ',
      'Thursday': 'พฤ', 'Friday': 'ศ', 'Saturday': 'ส', 'Sunday': 'อา'
    };

    return Table(
      children: [
        TableRow(
          children: weekdays.values.map((dayName) => Center(child: Text(dayName, style: GoogleFonts.anuphan(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
        ),
        TableRow(
          children: weekdays.keys.map((dayKey) {
            final shiftId = employee.dailyWorkShifts[dayKey];
            String shiftDisplay = "หยุด";
            Color textColor = Colors.red.shade700;
            if (shiftId != null && shiftId.isNotEmpty) {
              final shift = allShifts.firstWhereOrNull((s) => s.id == shiftId);
              shiftDisplay = shift != null ? '${_formatShiftTime(shift.startTime)}-${_formatShiftTime(shift.endTime)}' : 'N/A';
              textColor = Colors.black87;
            }
            return Center(child: Text(shiftDisplay, style: GoogleFonts.anuphan(fontSize: 11, color: textColor, fontWeight: FontWeight.w600)));
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Center(
      child: Column(
        children: [
          EmployeeAvatar(imageUrl: employee.profileImageUrl, gender: employee.gender, radius: 60),
          const SizedBox(height: 12),
          Text(employee.fullName, style: GoogleFonts.anuphan(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('ID: ${employee.employeeId}', style: GoogleFonts.anuphan(fontSize: 16, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: GoogleFonts.anuphan(color: Colors.grey.shade700, fontSize: 16))),
          Expanded(child: Text(value.isEmpty ? '-' : value, style: GoogleFonts.anuphan(fontSize: 16, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
