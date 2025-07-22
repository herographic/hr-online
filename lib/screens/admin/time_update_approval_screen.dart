// lib/screens/admin/time_update_approval_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/time_update_request_model.dart';
import 'package:intl/intl.dart';

class TimeUpdateApprovalScreen extends StatefulWidget {
  final Employee loggedInEmployee;

  const TimeUpdateApprovalScreen({super.key, required this.loggedInEmployee});

  @override
  State<TimeUpdateApprovalScreen> createState() =>
      _TimeUpdateApprovalScreenState();
}

class _TimeUpdateApprovalScreenState extends State<TimeUpdateApprovalScreen> {
  Future<void> _handleRequest(TimeUpdateRequest request, String newStatus) async {
    final requestRef = FirebaseFirestore.instance
        .collection('time_update_requests')
        .doc(request.id);

    try {
      // If approved, update the attendance log first
      if (newStatus == 'approved') {
        final attendanceDocId =
            '${request.employeeId}_${DateFormat('yyyy-MM-dd').format(request.requestedDate.toDate())}';
        final attendanceRef = FirebaseFirestore.instance
            .collection('attendance_log')
            .doc(attendanceDocId);

        final timeParts = request.requestedTime.split(':');
        final requestedDateTime = DateTime(
          request.requestedDate.toDate().year,
          request.requestedDate.toDate().month,
          request.requestedDate.toDate().day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );

        await attendanceRef.set({
          request.attendanceType: Timestamp.fromDate(requestedDateTime),
          // Add basic info in case the log doesn't exist yet
          'employeeId': request.employeeId,
          'employeeName': request.employeeName,
          'employeeNickname': request.employeeNickname,
          'date': Timestamp.fromDate(DateTime(request.requestedDate.toDate().year, request.requestedDate.toDate().month, request.requestedDate.toDate().day)),
          'status': 'present',
          'markedBy': widget.loggedInEmployee.employeeId,
          '${request.attendanceType}LocationName': 'แก้ไขโดย Admin',
        }, SetOptions(merge: true));
      }

      // Then, update the request status
      await requestRef.update({
        'status': newStatus,
        'approverId': widget.loggedInEmployee.employeeId,
        'approverName': widget.loggedInEmployee.fullName,
        'actionAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('ดำเนินการคำร้องขอสำเร็จ ($newStatus)'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('แก้ไขการบันทึกเวลา'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'รออนุมัติ'),
              Tab(text: 'ประวัติ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRequestList('pending'),
            _buildRequestList('history'),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestList(String status) {
    Query query = FirebaseFirestore.instance
        .collection('time_update_requests')
        .orderBy('requestedAt', descending: true);

    if (status == 'pending') {
      query = query.where('status', isEqualTo: 'pending');
    } else {
      query = query.where('status', whereIn: ['approved', 'rejected']);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('ไม่มีรายการคำร้องขอ'));
        }

        final requests = snapshot.data!.docs
            .map((doc) => TimeUpdateRequest.fromFirestore(doc))
            .toList();

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            return _buildRequestCard(requests[index]);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(TimeUpdateRequest request) {
    final dateFormat = DateFormat('d MMM yyyy', 'th_TH');
    final Map<String, String> typeTextMap = {
      'checkIn': 'เข้างาน',
      'checkOut': 'ออกงาน',
      'breakOut': 'ออกพัก',
      'breakIn': 'เข้าพัก',
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${request.employeeNickname} (${request.employeeId})',
              style: GoogleFonts.anuphan(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(request.employeePosition, style: GoogleFonts.anuphan(color: Colors.grey.shade600)),
            const Divider(),
            Text.rich(
              TextSpan(
                style: GoogleFonts.anuphan(fontSize: 14),
                children: [
                  const TextSpan(text: 'คำร้องขอ: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: 'แก้ไขเวลา "${typeTextMap[request.attendanceType]}"\n'),
                  const TextSpan(text: 'ในวันที่: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: '${dateFormat.format(request.requestedDate.toDate())}\n'),
                  const TextSpan(text: 'เป็นเวลา: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: '${request.requestedTime} น.'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('เหตุผล: ${request.reason}', style: GoogleFonts.anuphan(fontSize: 14)),
            if (request.status != 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'ดำเนินการโดย: ${request.approverName ?? '-'} (${request.status})',
                  style: GoogleFonts.anuphan(
                      color: request.status == 'approved' ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold),
                ),
              ),
            if (request.status == 'pending') ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _handleRequest(request, 'rejected'),
                    child: const Text('ไม่อนุมัติ', style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _handleRequest(request, 'approved'),
                    child: const Text('อนุมัติ'),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}
