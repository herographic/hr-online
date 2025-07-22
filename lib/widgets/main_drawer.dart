// hr_online/lib/widgets/main_drawer.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/providers/attendance_status_provider.dart';
import 'package:hr_online/screens/add_employee_screen.dart';
import 'package:hr_online/screens/admin/compensation_history_screen.dart';
import 'package:hr_online/screens/admin/edit_global_announcement_screen.dart';
import 'package:hr_online/screens/admin/employee_evaluation_list_screen.dart';
import 'package:hr_online/screens/admin/job_posting_management_screen.dart';
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
import 'package:hr_online/screens/placeholder_screen.dart'; // Import PlaceholderScreen
import 'package:hr_online/screens/profile_screen.dart';
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
    final bool isApprover =
        isUserAdmin || (loggedInEmployee?.isDepartmentHead ?? false);

    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8.0),
              children: [
                if (isUserAdmin) ...[
                  _buildSectionTitle('สำหรับผู้ดูแลระบบ'),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.campaign_outlined,
                    title: 'ประกาศ (หน้าแรก)',
                    onTap: () => _navigateTo(
                        context, const EditGlobalAnnouncementScreen()),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.edit_calendar_outlined,
                    title: 'แก้ไขการบันทึกเวลา',
                    onTap: () {
                       if (loggedInEmployee != null) {
                        _navigateTo(
                            context,
                            TimeUpdateApprovalScreen(
                                loggedInEmployee: loggedInEmployee!));
                      }
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.history_toggle_off,
                    title: 'ประวัติทำงานชดเชย',
                    onTap: () =>
                        _navigateTo(context, const CompensationHistoryScreen()),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.people_alt_outlined,
                    title: 'พนักงานทั้งหมด',
                    onTap: () => _navigateTo(
                        context,
                        AllEmployeesScreen(
                            isUserAdmin: isUserAdmin,
                            loggedInEmployee: loggedInEmployee)),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.groups_3_outlined,
                    title: 'จัดสรรกำลังคน',
                    onTap: () => _navigateTo(
                        context,
                        WorkforceAllocationScreen(
                            isUserAdmin: isUserAdmin,
                            loggedInEmployee: loggedInEmployee)),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.settings_applications_outlined,
                    title: 'จัดการข้อมูลหลัก',
                    onTap: () => _navigateTo(
                        context,
                        MasterSettingsScreen(
                            isUserAdmin: isUserAdmin,
                            loggedInEmployee: loggedInEmployee)),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'เพิ่มพนักงานใหม่',
                    onTap: () =>
                        _navigateTo(context, const AddEmployeeScreen()),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.quiz_outlined,
                    title: 'ออกแบบทดสอบ',
                    onTap: () =>
                        _navigateTo(context, const QuizManagementScreen()),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.person_search_outlined,
                    title: 'ประเมินพนักงาน',
                    onTap: () => _navigateTo(
                        context, const EmployeeEvaluationListScreen()),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.upload_file_outlined,
                    title: 'อัปโหลดข้อมูล',
                    onTap: () => _navigateTo(
                        context,
                        UploadEmployeeScreen(
                            isUserAdmin: isUserAdmin,
                            loggedInEmployee: loggedInEmployee)),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.description_outlined,
                    title: 'ดูใบสมัครงาน',
                    onTap: () =>
                        _navigateTo(context, const ViewApplicationsScreen()),
                  ),
                  const Divider(height: 24, thickness: 0.5),
                ],
                if (isApprover) ...[
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.post_add_outlined,
                    title: 'โพสต์รับสมัครงาน',
                    onTap: () => _navigateTo(
                        context,
                        JobPostingManagementScreen(
                            isUserAdmin: isUserAdmin,
                            loggedInEmployee: loggedInEmployee)),
                  ),
                ],
                if (isApprover) ...[
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.notification_important_outlined,
                    title: 'แจ้งเตือนการลางาน',
                    onTap: () {
                      if (loggedInEmployee != null) {
                        _navigateTo(
                            context,
                            LeaveApprovalListScreen(
                                loggedInEmployee: loggedInEmployee!,
                                isUserAdmin: isUserAdmin));
                      }
                    },
                  ),
                ],
                _buildSectionTitle('เมนูทั่วไป'),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.person_outline,
                  title: 'ข้อมูลส่วนตัว',
                  onTap: () {
                    if (loggedInEmployee != null) {
                      _navigateTo(
                          context, ProfileScreen(employee: loggedInEmployee!));
                    }
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.more_time_outlined,
                  title: 'ชดเชยเวลางาน',
                  onTap: () => _navigateTo(context, CompensationCheckInScreen(isUserAdmin: isUserAdmin, loggedInEmployee: loggedInEmployee)),
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.leaderboard_outlined,
                  title: 'อันดับคะแนน (ส่งงาน)',
                  onTap: () => _navigateTo(
                      context,
                      AttendanceAwardScreen(
                          isUserAdmin: isUserAdmin,
                          loggedInEmployee: loggedInEmployee)),
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.military_tech_outlined,
                  title: 'อันดับแบบทดสอบ',
                  onTap: () => _navigateTo(context, const QuizRankingScreen()),
                ),
                _buildDrawerItem(
                    context: context,
                    icon: Icons.checklist_rtl_outlined,
                    title: 'ทำแบบทดสอบ',
                    onTap: () {
                      if (loggedInEmployee != null) {
                        _navigateTo(context,
                            QuizListScreen(loggedInEmployee: loggedInEmployee!));
                      }
                    }),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.emoji_events_outlined,
                  title: 'อันดับของฉัน',
                  onTap: () {
                    if (loggedInEmployee != null) {
                      _navigateTo(
                          context,
                          MyQuizRankingsScreen(
                              loggedInEmployee: loggedInEmployee!));
                    }
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.calendar_today_outlined,
                  title: 'แจ้งลางาน',
                  onTap: () {
                    if (loggedInEmployee != null) {
                      _navigateTo(
                          context,
                          LeaveRequestListScreen(
                              loggedInEmployee: loggedInEmployee!,
                              isUserAdmin: isUserAdmin));
                    }
                  },
                ),
                // --- [START] ADDED PAYSLIP MENU ITEM ---
                _buildDrawerItem(
                  context: context,
                  icon: Icons.receipt_long_outlined, // Icon for payslip
                  title: 'สลิปเงินเดือน',
                  onTap: () {
                    // Placeholder navigation to a new screen for payslip
                    _navigateTo(context, const PlaceholderScreen(title: 'สลิปเงินเดือน'));
                  },
                ),
                // --- [END] ADDED PAYSLIP MENU ITEM ---
              ],
            ),
          ),
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).pop(); // Close drawer first
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => screen));
  }

  Widget _buildDrawerHeader(BuildContext context) {
    if (loggedInEmployee == null && !isUserAdmin) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 16, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmployeeStatusAvatar(
                employeeId: loggedInEmployee?.employeeId ?? 'admin',
                imageUrl: loggedInEmployee?.profileImageUrl,
                gender: loggedInEmployee?.gender,
                radius: 35,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loggedInEmployee?.fullName ?? 'ผู้ดูแลระบบ',
                      style: GoogleFonts.anuphan(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white),
                    ),
                    Text(
                      'ID: ${loggedInEmployee?.employeeId ?? 'admin'}',
                      style: GoogleFonts.anuphan(
                          color: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FutureBuilder<String>(
                  future: _getDeptAndPosition(loggedInEmployee),
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data ?? '...',
                      style:
                          GoogleFonts.anuphan(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
              Consumer<AttendanceStatusProvider>(
                builder: (context, provider, child) {
                  final status =
                      provider.statuses[loggedInEmployee?.employeeId] ??
                          EmployeeAttendanceStatus.unknown;
                  final isOnline = status == EmployeeAttendanceStatus.checkedIn;
                  return Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: isOnline
                                ? Colors.lightGreenAccent
                                : Colors.grey[400],
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 1.5)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: GoogleFonts.anuphan(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String> _getDeptAndPosition(Employee? employee) async {
    if (employee == null) return 'สถานะ: Admin';
    if (employee.departmentCode.isEmpty) return 'ไม่ระบุแผนก/ตำแหน่ง';
    try {
      final deptDoc = await FirebaseFirestore.instance
          .collection('departments')
          .doc(employee.departmentCode)
          .get();
      final deptName =
          deptDoc.exists ? (deptDoc.data()!['name'] ?? 'N/A') : 'N/A';
      final posNames = employee.positions.map((p) => p['name'] ?? '').join(', ');
      return '$deptName / $posNames';
    } catch (e) {
      return 'ไม่สามารถโหลดข้อมูลได้';
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.anuphan(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade800),
      title: Text(title, style: GoogleFonts.anuphan(fontWeight: FontWeight.w500)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      dense: true,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SafeArea(
      child: ListTile(
        leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
        title: Text('ออกจากระบบ',
            style: GoogleFonts.anuphan(
                color: Colors.redAccent, fontWeight: FontWeight.bold)),
        onTap: () async {
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
                  child:
                      const Text('ยืนยัน', style: TextStyle(color: Colors.red)),
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
        },
      ),
    );
  }
}
