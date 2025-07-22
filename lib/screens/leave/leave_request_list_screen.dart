import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/leave_request_model.dart';
import 'package:hr_online/screens/leave/leave_request_detail_screen.dart';
import 'package:hr_online/screens/leave/leave_request_form_screen.dart';
import 'package:hr_online/widgets/app_layout.dart';
import 'package:intl/intl.dart';

class LeaveRequestListScreen extends StatefulWidget {
  final Employee loggedInEmployee;
  final bool isUserAdmin;

  const LeaveRequestListScreen({
    super.key,
    required this.loggedInEmployee,
    required this.isUserAdmin,
  });

  @override
  State<LeaveRequestListScreen> createState() => _LeaveRequestListScreenState();
}

class _LeaveRequestListScreenState extends State<LeaveRequestListScreen> {
  @override
  Widget build(BuildContext context) {
    return AppLayout(
      isUserAdmin: widget.isUserAdmin,
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'รายการลางานของฉัน',
      showBackButton: true,
      bodySlivers: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('leave_requests')
              .where('employeeId', isEqualTo: widget.loggedInEmployee.employeeId)
              .orderBy('requestedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'คุณยังไม่มีประวัติการลางาน',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              );
            }

            final requests = snapshot.data!.docs
                .map((doc) => LeaveRequest.fromFirestore(doc))
                .toList();

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildLeaveRequestCard(context, requests[index]);
                },
                childCount: requests.length,
              ),
            );
          },
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => LeaveRequestFormScreen(
              loggedInEmployee: widget.loggedInEmployee,
            ),
          ));
        },
        icon: const Icon(Icons.add),
        label: const Text('สร้างใบลาใหม่'),
      ),
    );
  }

  Widget _buildLeaveRequestCard(BuildContext context, LeaveRequest request) {
    final DateFormat dateFormat = DateFormat('d MMM yyyy', 'th_TH');
    final String dateRange =
        '${dateFormat.format(request.startDate.toDate())} - ${dateFormat.format(request.endDate.toDate())}';

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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor, size: 36),
        title: Text(request.leaveType, style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
        subtitle: Text('วันที่: $dateRange\nสถานะ: $statusText', style: GoogleFonts.anuphan()),
        trailing: const Icon(Icons.arrow_forward_ios),
        isThreeLine: true,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => LeaveRequestDetailScreen(
              requestId: request.id,
              loggedInEmployee: widget.loggedInEmployee,
              isUserAdmin: widget.isUserAdmin,
            ),
          ));
        },
      ),
    );
  }
}
