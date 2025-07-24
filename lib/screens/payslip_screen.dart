// lib/screens/payslip_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/position_model.dart';
import 'package:hr_online/utils/payslip_pdf_generator.dart';
import 'package:intl/intl.dart';

class PayslipScreen extends StatefulWidget {
  final Employee loggedInEmployee;

  const PayslipScreen({super.key, required this.loggedInEmployee});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  String? _selectedPayslipType;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _showDownloadSection = false;
  bool _isGeneratingPdf = false;

  final List<String> _payslipTypes = ['สลิปเงินเดือนงวดเต็ม', 'สลิปเงินเดือนงวดครึ่ง'];
  late final List<DateTime> _monthOptions;

  @override
  void initState() {
    super.initState();
    _monthOptions = _generateMonthList();
    _selectedPayslipType = _payslipTypes.first;
    // Set default values to the current month
    _selectedStartDate = _monthOptions.first;
    _selectedEndDate = _monthOptions.first;
  }

  /// Generates a list of DateTime objects for the dropdowns.
  List<DateTime> _generateMonthList() {
    final List<DateTime> months = [];
    final now = DateTime.now();
    for (int i = 0; i < 24; i++) { // Generate for the last 24 months
      months.add(DateTime(now.year, now.month - i, 1));
    }
    return months;
  }
  
  /// Formats a DateTime object into a short Thai month and Buddhist era year string (e.g., "มิ.ย. 2567").
  String _formatDateToThaiMonthYear(DateTime date) {
    final thaiYear = date.year + 543;
    final thaiMonth = DateFormat('MMM', 'th_TH').format(date);
    return '$thaiMonth $thaiYear';
  }


  void _searchPayslip() {
    setState(() {
      _showDownloadSection = true;
    });
  }
  
  Future<void> _downloadPayslip() async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);

    try {
      // Fetch related data for the employee
      final departmentDoc = widget.loggedInEmployee.departmentCode.isNotEmpty
        ? await FirebaseFirestore.instance.collection('departments').doc(widget.loggedInEmployee.departmentCode).get()
        : null;
      
      final Department? department = departmentDoc?.exists ?? false ? Department.fromFirestore(departmentDoc!) : null;

      // In this simplified version, we assume the first position is the main one.
      final Position? position = widget.loggedInEmployee.positions.isNotEmpty
        ? Position(id: '', name: widget.loggedInEmployee.positions.first['name'], departmentId: '')
        : null;

      final generator = PayslipPdfGenerator(
        employee: widget.loggedInEmployee,
        department: department,
        position: position,
        payslipMonth: DateFormat.yMMMM('th_TH').format(_selectedEndDate ?? DateTime.now()),
      );
      
      await generator.generateAndShowPayslip();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการสร้าง PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สลิปเงินเดือน'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSelectionCard(),
          const SizedBox(height: 24),
          if (_showDownloadSection)
            _buildDownloadCard(),
        ],
      ),
    );
  }

  Widget _buildSelectionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('รูปแบบสลิป', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isDense: true,
              value: _selectedPayslipType,
              items: _payslipTypes.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedPayslipType = newValue;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ตั้งแต่', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<DateTime>(
                        isDense: true,
                        value: _selectedStartDate,
                        items: _monthOptions.map((DateTime date) {
                          return DropdownMenuItem<DateTime>(
                            value: date,
                            child: Text(_formatDateToThaiMonthYear(date)),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedStartDate = newValue;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ถึง', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<DateTime>(
                        isDense: true,
                        value: _selectedEndDate,
                        items: _monthOptions.map((DateTime date) {
                          return DropdownMenuItem<DateTime>(
                            value: date,
                            child: Text(_formatDateToThaiMonthYear(date)),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedEndDate = newValue;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _searchPayslip,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('ค้นหา', style: GoogleFonts.anuphan(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          children: [
            Text(
              'ดาวน์โหลดสลิปเงินเดือนย้อนหลัง',
              style: GoogleFonts.anuphan(fontSize: 16, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            const Icon(Icons.picture_as_pdf, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isGeneratingPdf ? null : _downloadPayslip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isGeneratingPdf
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : Text('สลิปเงินเดือน', style: GoogleFonts.anuphan(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
