// lib/screens/employee/compensation_check_in_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/screens/qr_scanner_screen.dart';
import 'package:hr_online/widgets/app_layout.dart';

class CompensationCheckInScreen extends StatelessWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const CompensationCheckInScreen({
    super.key,
    required this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      isUserAdmin: isUserAdmin,
      loggedInEmployee: loggedInEmployee,
      overrideTitle: 'ชดเชยเวลางาน',
      showBackButton: true,
      bodySlivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.more_time,
                    size: 80, color: Colors.white.withOpacity(0.8)),
                const SizedBox(height: 16),
                Text(
                  'บันทึกเวลาทำงานชดเชย',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.anuphan(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'ใช้สำหรับสแกนเข้า-ออกงานในวันหยุด หรือวันที่ต้องการทำงานชดเชย',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.anuphan(
                      fontSize: 16, color: Colors.white.withOpacity(0.9)),
                ),
                const SizedBox(height: 32),
                _buildOptionButton(
                  context,
                  icon: Icons.qr_code_scanner,
                  label: 'สแกน QR Code เพื่อลงเวลา',
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => QRScannerScreen(
                        isUserAdmin: isUserAdmin,
                        loggedInEmployee: loggedInEmployee,
                        // Pass the flag to indicate this is for compensation
                        isForCompensation: true,
                      ),
                    ));
                  },
                ),
              ],
            ),
          ),
        )
      ],
      floatingActionButton: const SizedBox.shrink(),
    );
  }

  Widget _buildOptionButton(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
      ),
      onPressed: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 50),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.anuphan(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
