// lib/screens/leave/leave_approval_list_screen.dart
// หน้าสำหรับ Admin/Head ดูและอนุมัติใบลา (เวอร์ชันมีแท็บ)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/leave_request_model.dart';
import 'package:hr_online/screens/leave/leave_request_detail_screen.dart';
import 'package:hr_online/widgets/app_layout.dart';
import 'package:intl/intl.dart';

class LeaveApprovalListScreen extends StatefulWidget {
  final Employee loggedInEmployee;
  final bool isUserAdmin;

  const LeaveApprovalListScreen({
    super.key,
    required this.loggedInEmployee,
    required this.isUserAdmin,
  });

  @override
  State<LeaveApprovalListScreen> createState() => _LeaveApprovalListScreenState();
}

class _LeaveApprovalListScreenState extends State<LeaveApprovalListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Helper to build the query based on role and status tab.
  Query _buildQuery(String tab) {
    Query query;

    if (tab == 'pending') {
      query = FirebaseFirestore.instance
          .collection('leave_requests')
          .where('status', isEqualTo: 'pending');
    } else { // History tab
      query = FirebaseFirestore.instance
          .collection('leave_requests')
          .where('status', whereIn: ['approved', 'rejected']);
    }

    // Filter by department if user is a head but not an admin
    if (!widget.isUserAdmin && widget.loggedInEmployee.isDepartmentHead) {
      query = query.where('departmentId', isEqualTo: widget.loggedInEmployee.departmentCode);
    }

    // Order by the appropriate date field
    if (tab == 'pending') {
      return query.orderBy('requestedAt', descending: true);
    } else { // History tab
      return query.orderBy('actionAt', descending: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canApprove = widget.isUserAdmin || widget.loggedInEmployee.isDepartmentHead;

    return AppLayout(
      isUserAdmin: widget.isUserAdmin,
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'แจ้งเตือนการลางาน',
      showBackButton: true,
      bodySlivers: !canApprove
        ? [
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'คุณไม่มีสิทธิ์ในการดูหน้านี้',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            )
          ]
        : [
            SliverPersistentHeader(
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.7),
                  indicatorColor: Colors.yellowAccent,
                  indicatorWeight: 3.0,
                  tabs: [
                    _buildPendingTab(),
                    const Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history),
                          SizedBox(width: 8),
                          Text('ประวัติ'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pinned: true,
            ),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRequestList(tab: 'pending'),
                  _buildRequestList(tab: 'history'),
                ],
              ),
            ),
          ],
    );
  }

  /// Builds the "Pending" tab with a real-time notification badge.
  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery('pending').snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mail_outline),
              const SizedBox(width: 8),
              const Text('รอการอนุมัติ'),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Badge(
                  label: Text('$count'),
                  backgroundColor: Colors.red,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Reusable widget to build the list view for each tab.
  Widget _buildRequestList({required String tab}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery(tab).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'เกิดข้อผิดพลาด:\n${snapshot.error}\n\nกรุณาตรวจสอบการสร้าง Index ใน Firestore',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              tab == 'pending' ? 'ไม่มีคำขอที่รอการอนุมัติ' : 'ไม่มีประวัติการอนุมัติ',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          );
        }

        final requests = snapshot.data!.docs.map((doc) => LeaveRequest.fromFirestore(doc)).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            return _buildLeaveRequestCard(context, requests[index]);
          },
        );
      },
    );
  }

  Widget _buildLeaveRequestCard(BuildContext context, LeaveRequest request) {
    final DateFormat dateFormat = DateFormat('d MMM yyyy', 'th_TH');
    final String dateRange = '${dateFormat.format(request.startDate.toDate())} - ${dateFormat.format(request.endDate.toDate())}';
    
    final IconData statusIcon;
    final Color statusColor;

    switch (request.status) {
      case 'approved':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusIcon = Icons.cancel;
        statusColor = Colors.red;
        break;
      default: // pending
        statusIcon = Icons.hourglass_top_rounded;
        statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor, size: 36),
        title: Text('${request.employeeName} (${request.employeeNickname})', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
        subtitle: Text('ประเภท: ${request.leaveType}\nวันที่: $dateRange', style: GoogleFonts.anuphan()),
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

/// Helper delegate for the Sliver TabBar to make it sticky.
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this.tabBar);
  final TabBar tabBar;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).primaryColor,
      child: tabBar,
    );
  }
  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
