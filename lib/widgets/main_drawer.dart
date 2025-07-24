// lib/widgets/main_drawer.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/providers/attendance_status_provider.dart';
import 'package:hr_online/screens/add_employee_screen.dart';
import 'package:hr_online/screens/admin/compensation_history_screen.dart';
import 'package:hr_online/screens/admin/edit_global_announcement_screen.dart';
import 'package:hr_online/screens/admin/employee_evaluation_list_screen.dart';
import 'package:hr_online/screens/admin/employee_income_screen.dart';
import 'package:hr_online/screens/admin/job_posting_management_screen.dart';
import 'package:hr_online/screens/admin/outsource_management_screen.dart';
import 'package:hr_online/screens/admin/quiz_management_screen.dart';
import 'package:hr_online/screens/admin/time_update_approval_screen.dart';
import 'package:hr_online/screens/admin/view_application_detail_screen.dart';
import 'package:hr_online/screens/all_employees_screen.dart';
import 'package:hr_online/screens/attendance_award_screen.dart';
import 'package:hr_online/screens/employee/compensation_check_in_screen.dart';
import 'package:hr_online/screens/employee/my_quiz_rankings_screen.dart';
import 'package:hr_online/screens/employee/quiz_list_screen.dart';
import 'package:hr_online/screens/employee/quiz_ranking_screen.dart';
import 'package:hr_online/screens/leave/leave_approval_list_screen.dart';
import 'package:hr_online/screens/leave/leave_request_list_screen.dart';
import 'package:hr_online/screens/login_screen.dart';
import 'package:hr_online/screens/master_settings_screen.dart';
import 'package:hr_online/screens/my_qr_code_screen.dart';
import 'package:hr_online/screens/payslip_screen.dart';
import 'package:hr_online/screens/profile_screen.dart';
import 'package:hr_online/screens/ranking_screen.dart';
import 'package:hr_online/screens/upload_employee_screen.dart';
import 'package:hr_online/screens/workforce_allocation_screen.dart';
import 'package:hr_online/widgets/employee_status_avatar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainDrawer extends StatelessWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const MainDrawer({
    super.key,
    required this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (isUserAdmin) ...[
                  ..._buildAdminOnlyMenuItems(context),
                  ..._buildDepartmentHeadMenuItems(context),
                  const Divider(),
                  ..._buildEmployeeAndOutsourceMenuItems(context, loggedInEmployee),
                ] else if (loggedInEmployee != null) ...[
                  ..._buildEmployeeAndOutsourceMenuItems(context, loggedInEmployee!),
                  if (loggedInEmployee!.isDepartmentHead) ...[
                    ..._buildDepartmentHeadMenuItems(context),
                  ]
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    final statusProvider = Provider.of<AttendanceStatusProvider>(context, listen: false);
    final status = isUserAdmin
        ? EmployeeAttendanceStatus.unknown
        : statusProvider.statuses[loggedInEmployee?.employeeId] ?? EmployeeAttendanceStatus.unknown;
    
    final statusInfo = _getStatusTextAndColor(status);
    
    final positionNames = loggedInEmployee?.positions.isNotEmpty ?? false
        ? loggedInEmployee!.positions.map((p) => p['name'] ?? '').join(', ')
        : 'ยังไม่มีตำแหน่ง';

    return DrawerHeader(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00c6ff), Color(0xFF0072ff)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EmployeeStatusAvatar(
                employeeId: loggedInEmployee?.employeeId ?? '',
                imageUrl: loggedInEmployee?.profileImageUrl,
                gender: loggedInEmployee?.gender,
                radius: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      loggedInEmployee?.fullName ?? 'ผู้ดูแลระบบ',
                      style: GoogleFonts.anuphan(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isUserAdmin ? 'Admin' : '$positionNames (${loggedInEmployee?.employeeId ?? ''})',
                      style: GoogleFonts.anuphan(color: Colors.white.withOpacity(0.9)),
                       overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Row(
              children: [
                Icon(Icons.circle, color: statusInfo['color'] as Color, size: 12),
                const SizedBox(width: 8),
                Text(
                  statusInfo['text'] as String,
                  style: GoogleFonts.anuphan(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white, size: 22),
                  onPressed: () => _handleLogout(context),
                  tooltip: 'ออกจากระบบ',
                  splashRadius: 20,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  List<Widget> _buildEmployeeAndOutsourceMenuItems(BuildContext context, Employee? employee) {
    final bool isEmployeeView = employee != null;

    return [
      _buildSectionHeader('เมนูทั่วไป'),
      _buildDrawerItem(context, 'ข้อมูลส่วนตัว', Icons.person,
          isEmployeeView ? () => _navigateTo(context, ProfileScreen(employee: employee)) : null),
      if (isEmployeeView && employee.isDepartmentHead)
        _buildDrawerItem(context, 'QR Code ของฉัน', Icons.qr_code_2,
            () => _navigateTo(context, MyQRCodeScreen(loggedInEmployee: employee))),
      _buildDrawerItem(context, 'สลิปเงินเดือน', Icons.receipt_long,
          isEmployeeView ? () => _navigateTo(context, PayslipScreen(loggedInEmployee: employee)) : null),
      _buildDrawerItem(context, 'รายการลางาน', Icons.event_note,
          isEmployeeView ? () => _navigateTo(context, LeaveRequestListScreen(loggedInEmployee: employee, isUserAdmin: isUserAdmin)) : null),
      _buildDrawerItem(context, 'แบบทดสอบ', Icons.quiz_outlined,
          isEmployeeView ? () => _navigateTo(context, QuizListScreen(loggedInEmployee: employee)) : null),
      _buildDrawerItem(context, 'อันดับคะแนน', Icons.leaderboard,
          () => _navigateTo(context, RankingScreen(isUserAdmin: isUserAdmin, loggedInEmployee: loggedInEmployee))),
      _buildDrawerItem(context, 'อันดับ (แบบทดสอบ)', Icons.emoji_events,
          () => _navigateTo(context, const QuizRankingScreen())),
      _buildDrawerItem(context, 'อันดับของฉัน', Icons.military_tech,
          isEmployeeView ? () => _navigateTo(context, MyQuizRankingsScreen(loggedInEmployee: employee)) : null),
      _buildDrawerItem(context, 'ทำงานชดเชย', Icons.more_time_outlined,
          isEmployeeView ? () => _navigateTo(context, CompensationCheckInScreen(isUserAdmin: isUserAdmin, loggedInEmployee: loggedInEmployee)) : null),
    ];
  }
  
  List<Widget> _buildDepartmentHeadMenuItems(BuildContext context) {
    return [
       const Divider(),
      _buildSectionHeader('สำหรับหัวหน้าแผนก'),
       _buildDrawerItem(context, 'อนุมัติการลา', Icons.event_available,
          () => _navigateTo(context, LeaveApprovalListScreen(loggedInEmployee: loggedInEmployee!, isUserAdmin: isUserAdmin))),
    ];
  }

  List<Widget> _buildAdminOnlyMenuItems(BuildContext context) {
    return [
      _buildSectionHeader('สำหรับผู้ดูแลระบบ'),
      _buildDrawerItem(context, 'จัดการข้อมูลหลัก', Icons.settings_applications,
          () => _navigateTo(context, MasterSettingsScreen(isUserAdmin: isUserAdmin, loggedInEmployee: loggedInEmployee))),
      _buildDrawerItem(context, 'กำหนดรายได้พนักงาน', Icons.paid_outlined,
          () => _navigateTo(context, const EmployeeIncomeScreen())),
      _buildDrawerItem(context, 'จัดสรรกำลังคน', Icons.groups,
          () => _navigateTo(context, WorkforceAllocationScreen(isUserAdmin: isUserAdmin, loggedInEmployee: loggedInEmployee))),
      _buildDrawerItem(context, 'OutSource', Icons.engineering,
          () => _navigateTo(context, OutsourceManagementScreen(loggedInEmployee: loggedInEmployee!))),
      _buildDrawerItem(context, 'พนักงานทั้งหมด', Icons.people,
          () => _navigateTo(context, AllEmployeesScreen(isUserAdmin: isUserAdmin, loggedInEmployee: loggedInEmployee))),
      _buildDrawerItem(context, 'เพิ่มพนักงาน', Icons.person_add,
          () => _navigateTo(context, const AddEmployeeScreen())),
      _buildDrawerItem(context, 'อัปโหลดข้อมูล', Icons.upload_file,
          () => _navigateTo(context, UploadEmployeeScreen(isUserAdmin: isUserAdmin, loggedInEmployee: loggedInEmployee))),
      _buildDrawerItem(context, 'อนุมัติแก้ไขเวลา', Icons.history_toggle_off,
          () => _navigateTo(context, TimeUpdateApprovalScreen(loggedInEmployee: loggedInEmployee!))),
      const Divider(),
      _buildSectionHeader('การสรรหาและประเมิน'),
      _buildDrawerItem(context, 'ข้อมูลผู้สมัครงาน', Icons.description,
          () => _navigateTo(context, const ViewApplicationsScreen())),
      _buildDrawerItem(context, 'ประกาศรับสมัครงาน', Icons.article,
          () => _navigateTo(context, JobPostingManagementScreen(isUserAdmin: isUserAdmin, loggedInEmployee: loggedInEmployee))),
      _buildDrawerItem(context, 'ออกแบบทดสอบ', Icons.quiz,
          () => _navigateTo(context, const QuizManagementScreen())),
      _buildDrawerItem(context, 'ประเมินพนักงาน', Icons.star_rate,
          () => _navigateTo(context, const EmployeeEvaluationListScreen())),
      const Divider(),
      _buildSectionHeader('อื่น ๆ'),
      _buildDrawerItem(context, 'จัดการประกาศ', Icons.campaign,
          () => _navigateTo(context, const EditGlobalAnnouncementScreen())),
      _buildDrawerItem(context, 'ประวัติทำงานชดเชย', Icons.more_time,
          () => _navigateTo(context, const CompensationHistoryScreen())),
    ];
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.anuphan(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
            fontSize: 14),
      ),
    );
  }

  Widget _buildDrawerItem(
      BuildContext context, String title, IconData icon, VoidCallback? onTap) {
    return ListTile(
      leading: Icon(icon, color: onTap != null ? Colors.grey.shade700 : Colors.grey.shade400),
      title: Text(title, style: GoogleFonts.anuphan(color: onTap != null ? Colors.black87 : Colors.grey.shade500)),
      onTap: onTap == null ? null : () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('loggedInUserId');
      await FirebaseAuth.instance.signOut();
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        debugPrint("Error signing in anonymously after logout: $e");
      }
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Map<String, dynamic> _getStatusTextAndColor(EmployeeAttendanceStatus status) {
    switch (status) {
      case EmployeeAttendanceStatus.checkedIn:
        return {'text': 'Online', 'color': Colors.greenAccent};
      case EmployeeAttendanceStatus.onBreak:
        return {'text': 'กำลังพัก', 'color': Colors.orangeAccent};
      case EmployeeAttendanceStatus.checkedOut:
        return {'text': 'Offline', 'color': Colors.redAccent};
      case EmployeeAttendanceStatus.dayOff:
        return {'text': 'วันหยุด', 'color': Colors.lightBlueAccent};
      case EmployeeAttendanceStatus.absent:
      case EmployeeAttendanceStatus.unknown:
      default:
        return {'text': 'Offline', 'color': Colors.grey.shade400};
    }
  }
}
