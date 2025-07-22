// lib/screens/report_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class ReportScreen extends StatefulWidget {
  final List<Department> allDepartments;
  final List<Employee> allEmployees;
  final DateTime selectedDay;

  const ReportScreen({
    super.key,
    required this.allDepartments,
    required this.allEmployees,
    required this.selectedDay,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _reportText = 'กำลังสร้างรายงาน...';

  @override
  void initState() {
    super.initState();
    _generateReportText();
  }

  void _generateReportText() {
    final DateFormat dateFormat = DateFormat('d MMMM yyyy', 'th_TH');
    final String todayDate = dateFormat.format(widget.selectedDay);

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('รายชื่อพนักงานทำงานวันนี้');
    buffer.writeln('วันที่ $todayDate');
    buffer.writeln('--------------------');

    for (var department in widget.allDepartments) {
      // --- [START] CODE EDITED ---
      // เปลี่ยนเงื่อนไขการกรองพนักงานให้ใช้ departmentCode เทียบกับ department.id
      final employeesInDept = widget.allEmployees
          .where((emp) => emp.departmentCode == department.id)
          .toList();
      // --- [END] CODE EDITED ---

      if (employeesInDept.isNotEmpty) {
        employeesInDept.sort((a, b) => a.employeeId.compareTo(b.employeeId));

        buffer.writeln('\n📋 แผนก: ${department.name}');
        int count = 1;
        for (var emp in employeesInDept) {
          buffer.writeln('$count. ${emp.employeeId} | ${emp.nickname}');
          count++;
        }
      }
    }

    setState(() {
      _reportText = buffer.toString();
    });
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _reportText)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คัดลอกรายงานไปยังคลิปบอร์ดแล้ว')),
      );
    });
  }

  void _shareReport() {
    // ignore: deprecated_member_use
    Share.share(_reportText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00c6ff), Color(0xFF0072ff)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                _reportText,
                                style: GoogleFonts.sarabun(fontSize: 16, height: 1.6),
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _copyToClipboard,
                                icon: const Icon(Icons.copy_all_outlined),
                                label: const Text('คัดลอก'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade200,
                                  foregroundColor: Colors.black87,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _shareReport,
                                icon: const Icon(Icons.share_outlined),
                                label: const Text('แชร์'),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'ย้อนกลับ',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'รายงานสรุป',
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 56), // Spacer to keep title centered
        ],
      ),
    );
  }
}
