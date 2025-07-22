// lib/screens/attendance/time_update_request_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/time_update_request_model.dart';
import 'package:intl/intl.dart';

class TimeUpdateRequestScreen extends StatefulWidget {
  final Employee loggedInEmployee;

  const TimeUpdateRequestScreen({super.key, required this.loggedInEmployee});

  @override
  State<TimeUpdateRequestScreen> createState() => _TimeUpdateRequestScreenState();
}

class _TimeUpdateRequestScreenState extends State<TimeUpdateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  // --- [START] MODIFIED CODE ---
  // Use TextEditingController for date and time fields to display selected values
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  // --- [END] MODIFIED CODE ---
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedAttendanceType;
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  final Map<String, String> _attendanceTypes = {
    'checkIn': 'สแกนเข้างาน',
    'breakOut': 'สแกนออกพัก',
    'breakIn': 'สแกนเข้าพัก',
    'checkOut': 'สแกนออกงาน',
  };

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('th', 'TH'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // --- [START] MODIFIED CODE ---
        // Update the text controller with the selected date
        _dateController.text = DateFormat('d MMMM yyyy', 'th_TH').format(_selectedDate!);
        // --- [END] MODIFIED CODE ---
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        // --- [START] MODIFIED CODE ---
        // Update the text controller with the selected time in Thai format
        _timeController.text = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')} น.';
        // --- [END] MODIFIED CODE ---
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final positionNames = widget.loggedInEmployee.positions.isNotEmpty
        ? widget.loggedInEmployee.positions.map((p) => p['name'] ?? '').join(', ')
        : 'ไม่ระบุตำแหน่ง';

      final newRequest = TimeUpdateRequest(
        id: '', // Firestore will generate
        employeeId: widget.loggedInEmployee.employeeId,
        employeeName: widget.loggedInEmployee.fullName,
        employeeNickname: widget.loggedInEmployee.nickname,
        employeePosition: positionNames,
        requestedDate: Timestamp.fromDate(_selectedDate!),
        requestedTime: '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
        attendanceType: _selectedAttendanceType!,
        reason: _reasonController.text.trim(),
        requestedAt: Timestamp.now(),
      );

      await FirebaseFirestore.instance
          .collection('time_update_requests')
          .add(newRequest.toFirestore());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ส่งคำร้องขอสำเร็จ'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ส่งคำร้องขอแก้ไขเวลา')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              // --- [START] MODIFIED CODE ---
              controller: _dateController, // Use controller to display selected date
              // --- [END] MODIFIED CODE ---
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'วันที่ต้องการแก้ไข *',
                hintText: 'กรุณาเลือกวันที่', // Keep hint for initial state
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              onTap: _selectDate,
              validator: (value) => _selectedDate == null ? 'กรุณาเลือกวันที่' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              // --- [START] MODIFIED CODE ---
              controller: _timeController, // Use controller to display selected time
              // --- [END] MODIFIED CODE ---
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'เวลาที่ถูกต้อง *',
                hintText: 'กรุณาเลือกเวลา', // Keep hint for initial state
                suffixIcon: const Icon(Icons.access_time),
              ),
              onTap: _selectTime,
              validator: (value) => _selectedTime == null ? 'กรุณาเลือกเวลา' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedAttendanceType,
              hint: const Text('ประเภทการลงเวลา *'),
              items: _attendanceTypes.entries
                  .map((entry) =>
                      DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedAttendanceType = value),
              validator: (value) =>
                  value == null ? 'กรุณาเลือกประเภท' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'เหตุผลในการขอแก้ไข *',
                hintText: 'เช่น สแกนเวลาผิด, ลืมสแกน, ฯลฯ'
              ),
              maxLines: 4,
              validator: (value) =>
                  value!.trim().isEmpty ? 'กรุณากรอกเหตุผล' : null,
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _submitRequest,
                    icon: const Icon(Icons.send),
                    label: const Text('ส่งคำร้องขอ'),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50)),
                  )
          ],
        ),
      ),
    );
  }
}
