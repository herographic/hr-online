// lib/screens/leave/leave_request_form_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/leave_request_model.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

class LeaveRequestFormScreen extends StatefulWidget {
  final Employee loggedInEmployee;

  const LeaveRequestFormScreen({super.key, required this.loggedInEmployee});

  @override
  State<LeaveRequestFormScreen> createState() => _LeaveRequestFormScreenState();
}

class _LeaveRequestFormScreenState extends State<LeaveRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();
  File? _attachment;
  bool _isLoading = false;

  final List<String> _leaveTypes = [
    'ลากิจฉุกเฉิน',
    'ลากิจล่วงหน้า',
    'ลาป่วย',
    'ลาออก'
  ];

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      locale: const Locale('th', 'TH'),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );
    if (result != null) {
      setState(() {
        _attachment = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      String? attachmentUrl;
      String? attachmentFileName;

      if (_attachment != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_attachment!.path.split('/').last}';
        final ref = FirebaseStorage.instance
            .ref()
            .child('leave_attachments')
            .child(fileName);
        await ref.putFile(_attachment!);
        attachmentUrl = await ref.getDownloadURL();
        attachmentFileName = fileName;
      }

      final newRequest = LeaveRequest(
        id: '', // Firestore will generate
        employeeId: widget.loggedInEmployee.employeeId,
        employeeName: widget.loggedInEmployee.fullName,
        employeeNickname: widget.loggedInEmployee.nickname,
        departmentId: widget.loggedInEmployee.departmentCode,
        leaveType: _selectedLeaveType!,
        startDate: Timestamp.fromDate(_startDate!),
        endDate: Timestamp.fromDate(_endDate!),
        reason: _reasonController.text,
        attachmentUrl: attachmentUrl,
        attachmentFileName: attachmentFileName,
        status: 'pending',
        requestedAt: Timestamp.now(),
      );

      await FirebaseFirestore.instance
          .collection('leave_requests')
          .add(newRequest.toFirestore());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ส่งคำขอลางานสำเร็จ'),
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
    final DateFormat dateFormat = DateFormat('d MMM yyyy', 'th_TH');
    final String dateRangeText = _startDate != null && _endDate != null
        ? '${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)}'
        : 'กรุณาเลือกช่วงวันที่';

    return Scaffold(
      appBar: AppBar(title: const Text('สร้างใบลา')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            DropdownButtonFormField<String>(
              value: _selectedLeaveType,
              hint: const Text('เลือกประเภทการลา'),
              items: _leaveTypes
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedLeaveType = value),
              validator: (value) =>
                  value == null ? 'กรุณาเลือกประเภทการลา' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'วันที่ลา',
                suffixIcon: const Icon(Icons.calendar_today),
                hintText: dateRangeText,
              ),
              onTap: () => _selectDateRange(context),
              validator: (_) =>
                  _startDate == null || _endDate == null ? 'กรุณาเลือกวันที่' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: 'เหตุผลการลา'),
              maxLines: 5,
              validator: (value) => value!.isEmpty ? 'กรุณากรอกเหตุผล' : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(_attachment?.path.split('/').last ?? 'แนบไฟล์ (ถ้ามี)'),
              onTap: _pickFile,
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _submitRequest,
                    icon: const Icon(Icons.send),
                    label: const Text('ส่งคำขอ'),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50)),
                  )
          ],
        ),
      ),
    );
  }
}