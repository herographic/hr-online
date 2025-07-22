// lib/screens/leave_request_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/widgets/app_layout.dart';

class LeaveRequestScreen extends StatelessWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const LeaveRequestScreen({
    super.key,
    required this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      isUserAdmin: isUserAdmin,
      loggedInEmployee: loggedInEmployee,
      overrideTitle: 'แจ้งลางาน',
      showBackButton: true,
      bodySlivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy_outlined,
                  size: 150,
                  color: Colors.white.withOpacity(0.8),
                ),
                const SizedBox(height: 20),
                Text(
                  'หน้าสำหรับแจ้งลางาน',
                  style: GoogleFonts.anuphan(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                 const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    'ฟังก์ชันนี้จะถูกพัฒนาในอนาคต',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.anuphan(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
