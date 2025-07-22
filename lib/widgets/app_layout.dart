// lib/widgets/app_layout.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/screens/announcement_screen.dart';
import 'package:hr_online/screens/attendance/attendance_options_screen.dart';
import 'package:hr_online/screens/attendance_award_screen.dart';
import 'package:hr_online/screens/attendance_history_screen.dart';
import 'package:hr_online/screens/home_screen.dart';
import 'package:hr_online/screens/note_taking_screen.dart';
import 'package:hr_online/widgets/employee_avatar.dart';
import 'package:hr_online/widgets/main_drawer.dart';
import 'package:intl/intl.dart';
import 'package:hr_online/screens/notification_screen.dart'; // Import the new screen

class DigitalClockFab extends StatefulWidget {
  final VoidCallback onPressed;

  const DigitalClockFab({super.key, required this.onPressed});

  @override
  State<DigitalClockFab> createState() => _DigitalClockFabState();
}

class _DigitalClockFabState extends State<DigitalClockFab> {
  late Timer _timer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _currentTime = DateFormat('HH:mm').format(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  void _updateTime() {
    if (mounted) {
      final newTime = DateFormat('HH:mm').format(DateTime.now());
      if (newTime != _currentTime) {
        setState(() {
          _currentTime = newTime;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 15.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'fab_attendance_options',
            onPressed: widget.onPressed,
            backgroundColor: const Color(0xFFf5af19), // เปลี่ยนสีพื้นหลังเป็นสีน้ำเงินเข้ม
            foregroundColor: Colors.white, // เปลี่ยนสีตัวอักษรเป็นสีขาว
            elevation: 4.0,
            shape: const CircleBorder(),
            child: Text(
              _currentTime,
              style: GoogleFonts.orbitron(
                fontWeight: FontWeight.bold,
                fontSize: 14, // ปรับขนาดฟอนต์ให้เล็กลง
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: widget.onPressed,
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'ลงเวลา',
                style: GoogleFonts.anuphan(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  shadows: [const Shadow(blurRadius: 1.0, color: Colors.black26, offset: Offset(1, 1))]
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}


class AppLayout extends StatelessWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;
  final List<Widget> bodySlivers;
  final String? overrideTitle;
  final bool showBackButton;
  final Gradient? bodyGradient;
  final Widget? floatingActionButton;

  const AppLayout({
    super.key,
    required this.isUserAdmin,
    required this.loggedInEmployee,
    required this.bodySlivers,
    this.overrideTitle,
    this.showBackButton = false,
    this.bodyGradient,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    const defaultGradient = LinearGradient(
      colors: [Color(0xFF00c6ff), Color(0xFF0072ff)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    final defaultFab = DigitalClockFab(
      onPressed: () => _navigateTo(context, AttendanceOptionsScreen(isUserAdmin: isUserAdmin, loggedInEmployee: loggedInEmployee)),
    );

    return Scaffold(
      key: scaffoldKey,
      drawer: MainDrawer(
        isUserAdmin: isUserAdmin,
        loggedInEmployee: loggedInEmployee,
      ),
      extendBody: true,
      backgroundColor: (bodyGradient as LinearGradient?)?.colors.last ?? defaultGradient.colors.last,
      body: Container(
        decoration: BoxDecoration(gradient: bodyGradient ?? defaultGradient),
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              delegate: _CurvedHeaderDelegate(
                isUserAdmin: isUserAdmin,
                loggedInEmployee: loggedInEmployee,
                overrideTitle: overrideTitle,
                showBackButton: showBackButton,
                onMenuPressed: () {
                  scaffoldKey.currentState?.openDrawer();
                },
                context: context,
              ),
              pinned: true,
            ),
            ...bodySlivers,
          ],
        ),
      ),
      floatingActionButton: isKeyboardVisible ? null : (floatingActionButton ?? defaultFab),
      floatingActionButtonLocation: floatingActionButton != null 
          ? FloatingActionButtonLocation.endFloat 
          : FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: isKeyboardVisible ? null : _buildBottomAppBar(context),
    );
  }

  Widget _buildBottomAppBar(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF00c6ff), Color(0xFF0072ff)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildBottomAppBarItem(context, icon: Icons.home_outlined, label: 'หน้าแรก',
              onTap: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => HomeScreen(isUserAdmin: isUserAdmin, loggedInEmployee: loggedInEmployee)), 
                (Route<dynamic> route) => false
              ),
            ),
            _buildBottomAppBarItem(context, icon: Icons.campaign_outlined, label: 'ประกาศ',
              onTap: () => _navigateTo(context, AnnouncementScreen(isUserAdmin: isUserAdmin, loggedInEmployee: loggedInEmployee)),
            ),
            const SizedBox(width: 48), // The space for the default FAB
            _buildBottomAppBarItem(context, icon: Icons.history_edu_outlined, label: 'ประวัติ',
              onTap: () => _navigateTo(context, AttendanceHistoryScreen(isUserAdmin: isUserAdmin, loggedInEmployee: loggedInEmployee)),
            ),
            if (isUserAdmin)
              _buildBottomAppBarItem(context, icon: Icons.note_alt_outlined, label: 'โน้ต',
                onTap: () => _navigateTo(context, NoteTakingScreen(isUserAdmin: isUserAdmin, loggedInEmployee: loggedInEmployee)),
              )
            else
              const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAppBarItem(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.anuphan(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }
}

class _CurvedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;
  final String? overrideTitle;
  final bool showBackButton;
  final VoidCallback onMenuPressed;
  final BuildContext context;

  _CurvedHeaderDelegate({
    required this.isUserAdmin,
    this.loggedInEmployee,
    this.overrideTitle,
    required this.showBackButton,
    required this.onMenuPressed,
    required this.context,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final positionNames = loggedInEmployee?.positions.isNotEmpty ?? false
        ? loggedInEmployee!.positions.map((p) => p['name'] ?? '').join(', ')
        : 'ยังไม่มีตำแหน่ง';

    return ClipPath(
      clipper: _HeaderClipper(),
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00c6ff), Color(0xFF0072ff)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showBackButton)
                _buildHeaderAction(context, icon: Icons.arrow_back_ios_new, tooltip: 'ย้อนกลับ',
                  onTap: () => Navigator.of(context).pop(),
                )
              else
                _buildHeaderAction(context, icon: Icons.menu, tooltip: 'เมนู',
                  onTap: onMenuPressed,
                ),

              EmployeeAvatar(imageUrl: loggedInEmployee?.profileImageUrl, gender: loggedInEmployee?.gender, radius: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overrideTitle ?? loggedInEmployee?.nickname ?? 'ผู้ดูแลระบบ',
                      style: GoogleFonts.anuphan(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!showBackButton)
                      Text(
                        isUserAdmin ? 'สถานะ: Admin' : '$positionNames (${loggedInEmployee?.employeeId ?? ''})',
                        style: GoogleFonts.anuphan(fontSize: 13, color: Colors.white.withOpacity(0.9)),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (!showBackButton) ...[
                // --- [START] ADDED NOTIFICATION BUTTON ---
                if (loggedInEmployee != null) // Show only if logged in
                  _buildHeaderAction(
                    context,
                    icon: Icons.notifications_outlined,
                    tooltip: 'การแจ้งเตือน',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationScreen(loggedInEmployee: loggedInEmployee!))),
                  ),
                // --- [END] ADDED NOTIFICATION BUTTON ---
                _buildHeaderAction(
                  context,
                  icon: Icons.emoji_events_outlined,
                  tooltip: 'รางวัล',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceAwardScreen(isUserAdmin: isUserAdmin, loggedInEmployee: loggedInEmployee))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAction(BuildContext context, {required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 26),
      tooltip: tooltip,
      splashRadius: 24,
    );
  }

  @override
  double get maxExtent => 150;
  @override
  double get minExtent => 120;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 25);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 25);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
