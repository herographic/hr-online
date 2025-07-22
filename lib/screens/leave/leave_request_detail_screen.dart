// --- Detail Screen ---
// lib/screens/leave/leave_request_detail_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/leave_request_model.dart';
import 'package:hr_online/widgets/signature_pad.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';

class LeaveRequestDetailScreen extends StatefulWidget {
  final String requestId;
  final Employee loggedInEmployee;
  final bool isUserAdmin;

  const LeaveRequestDetailScreen({
    super.key,
    required this.requestId,
    required this.loggedInEmployee,
    required this.isUserAdmin,
  });

  @override
  _LeaveRequestDetailScreenState createState() =>
      _LeaveRequestDetailScreenState();
}

class _LeaveRequestDetailScreenState extends State<LeaveRequestDetailScreen> {
  final _commentController = TextEditingController();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _isProcessing = false;

  Future<Map<String, dynamic>> _fetchApprovalData(String employeeId, String departmentCode) async {
    final firestore = FirebaseFirestore.instance;
    final Map<String, dynamic> summary = {};

    // 1. Get employee data for start date
    final employeeDoc = await firestore.collection('users').doc(employeeId).get();
    if (employeeDoc.exists) {
      summary['startDate'] = (employeeDoc.data()!['start_date'] as Timestamp?)?.toDate();
    }

    // 2. Get leave history (count and last leave date)
    final leaveHistorySnapshot = await firestore
        .collection('leave_requests')
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: 'approved')
        .orderBy('endDate', descending: true)
        .get();
    
    summary['leaveCount'] = leaveHistorySnapshot.docs.length;
    if (leaveHistorySnapshot.docs.isNotEmpty) {
      summary['lastLeaveDate'] = (leaveHistorySnapshot.docs.first.data()['endDate'] as Timestamp).toDate();
    }

    // 3. Find department head
    if (departmentCode.isNotEmpty) {
      final headSnapshot = await firestore
          .collection('users')
          .where('departmentCode', isEqualTo: departmentCode)
          .where('isDepartmentHead', isEqualTo: true)
          .limit(1)
          .get();
      
      if (headSnapshot.docs.isNotEmpty) {
        final headData = headSnapshot.docs.first.data();
        summary['headName'] = '${headData['employee_name']} ${headData['employee_last_name']}';
        summary['headPhone'] = headData['mobilephone'];
      }
    }
    
    return summary;
  }

  Future<void> _handleApproval(String newStatus) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      String? signatureUrl;
      if (newStatus == 'approved' && _signatureController.isNotEmpty) {
        final Uint8List? data = await _signatureController.toPngBytes();
        if (data != null) {
          final ref = FirebaseStorage.instance.ref().child(
              'leave_signatures/${widget.requestId}_${DateTime.now().millisecondsSinceEpoch}.png');
          await ref.putData(data);
          signatureUrl = await ref.getDownloadURL();
        }
      }

      await FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(widget.requestId)
          .update({
        'status': newStatus,
        'approverId': widget.loggedInEmployee.employeeId,
        'approverName': widget.loggedInEmployee.fullName,
        'approverComment': _commentController.text,
        'signatureUrl': signatureUrl,
        'actionAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ดำเนินการสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดใบลา')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leave_requests')
            .doc(widget.requestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('ไม่พบข้อมูลคำขอ'));
          }

          final request = LeaveRequest.fromFirestore(snapshot.data!);
          
          final bool canApprove = (widget.isUserAdmin ||
              (widget.loggedInEmployee.isDepartmentHead &&
                  widget.loggedInEmployee.departmentCode == request.departmentId));
          
          final bool isPending = request.status == 'pending';

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSectionCard(
                icon: Icons.person,
                title: 'ข้อมูลผู้ยื่นคำขอ',
                children: [
                  _buildInfoRow('ชื่อ:', '${request.employeeName} (${request.employeeNickname})'),
                  _buildInfoRow('รหัสพนักงาน:', request.employeeId),
                ],
              ),
              _buildSectionCard(
                icon: Icons.description,
                title: 'รายละเอียดการลา',
                children: [
                  _buildInfoRow('ประเภท:', request.leaveType),
                  _buildInfoRow('วันที่ลา:',
                      '${DateFormat('d MMM yyyy', 'th_TH').format(request.startDate.toDate())} ถึง ${DateFormat('d MMM yyyy', 'th_TH').format(request.endDate.toDate())}'),
                  _buildInfoRow('เหตุผล:', request.reason),
                  if (request.attachmentUrl != null)
                    ListTile(
                      leading: const Icon(Icons.attach_file, color: Colors.blue),
                      title: const Text('ดูไฟล์แนบ', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                      onTap: () async {
                        final url = Uri.parse(request.attachmentUrl!);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                ],
              ),
              _buildSectionCard(
                icon: Icons.fact_check,
                title: 'สถานะการอนุมัติ',
                children: [
                  _buildStatusRow(request),
                  if (request.status != 'pending') ...[
                    const Divider(height: 20),
                    _buildInfoRow('ผู้ดำเนินการ:', request.approverName ?? '-'),
                    _buildInfoRow('ความเห็น:', request.approverComment ?? '-'),
                     if (request.signatureUrl != null) ...[
                        const SizedBox(height: 8),
                        const Text('ลายเซ็นผู้อนุมัติ:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Image.network(request.signatureUrl!, height: 80),
                      ]
                  ]
                ],
              ),

              if (canApprove && isPending)
                FutureBuilder<Map<String, dynamic>>(
                  future: _fetchApprovalData(request.employeeId, request.departmentId),
                  builder: (context, summarySnapshot) {
                    if (summarySnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ));
                    }
                    // --- [START] ADDED ERROR HANDLING ---
                    if (summarySnapshot.hasError) {
                      return Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'ไม่สามารถโหลดข้อมูลสรุปได้:\n${summarySnapshot.error}\n\nกรุณาตรวจสอบการสร้าง Index ใน Firestore',
                            style: TextStyle(color: Colors.red.shade900),
                          ),
                        ),
                      );
                    }
                    // --- [END] ADDED ERROR HANDLING ---
                    if (!summarySnapshot.hasData) {
                      return const SizedBox.shrink();
                    }
                    final summary = summarySnapshot.data!;
                    return _buildApproverSummaryCard(summary);
                  },
                ),

              if (canApprove && isPending) _buildApprovalActionSection(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildApproverSummaryCard(Map<String, dynamic> summary) {
    final dateFormat = DateFormat('d MMMM yyyy', 'th_TH');
    final now = DateTime.now();
    
    String workDuration = 'N/A';
    if (summary['startDate'] != null) {
      final difference = now.difference(summary['startDate']);
      final years = difference.inDays ~/ 365;
      final months = (difference.inDays % 365) ~/ 30;
      final days = difference.inDays % 30;
      workDuration = '${years > 0 ? '$years ปี ' : ''}${months > 0 ? '$months เดือน ' : ''}$days วัน';
    }

    return _buildSectionCard(
      icon: Icons.assessment,
      title: 'ข้อมูลประกอบการตัดสินใจ',
      children: [
        _buildInfoRow('ลาไปแล้วทั้งหมด:', '${summary['leaveCount'] ?? 0} ครั้ง'),
        _buildInfoRow('ลาล่าสุด:', summary['lastLeaveDate'] != null ? dateFormat.format(summary['lastLeaveDate']) : 'ยังไม่เคยลา'),
        _buildInfoRow('เริ่มงานวันที่:', summary['startDate'] != null ? dateFormat.format(summary['startDate']) : 'N/A'),
        _buildInfoRow('อายุงาน:', workDuration),
        _buildInfoRow('หัวหน้าแผนก:', '${summary['headName'] ?? 'ไม่พบ'} (${summary['headPhone'] ?? 'N/A'})'),
      ],
    );
  }

  Widget _buildSectionCard({required IconData icon, required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(title, style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatusRow(LeaveRequest request) {
    final IconData statusIcon;
    final Color statusColor;
    final String statusText;

    switch (request.status) {
      case 'approved':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        statusText = 'อนุมัติ';
        break;
      case 'rejected':
        statusIcon = Icons.cancel;
        statusColor = Colors.red;
        statusText = 'ไม่อนุมัติ';
        break;
      default:
        statusIcon = Icons.hourglass_top;
        statusColor = Colors.orange;
        statusText = 'รอการอนุมัติ';
    }
    return Row(
      children: [
        Icon(statusIcon, color: statusColor),
        const SizedBox(width: 8),
        Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildApprovalActionSection() {
    return _buildSectionCard(
      icon: Icons.edit,
      title: 'สำหรับผู้อนุมัติ',
      children: [
        TextFormField(
          controller: _commentController,
          decoration: const InputDecoration(
            labelText: 'ความเห็นเพิ่มเติม (ถ้ามี)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        const Text('ลายเซ็น (สำหรับการอนุมัติ)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SignaturePad(controller: _signatureController),
        const SizedBox(height: 24),
        if (_isProcessing)
          const Center(child: CircularProgressIndicator())
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _handleApproval('rejected'),
                icon: const Icon(Icons.close),
                label: const Text('ไม่อนุมัติ'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
              ElevatedButton.icon(
                onPressed: () => _handleApproval('approved'),
                icon: const Icon(Icons.check),
                label: const Text('อนุมัติ'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          )
      ],
    );
  }
}
