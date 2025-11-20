// lib/screens/upload_employee_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/widgets/app_layout.dart';

class UploadEmployeeScreen extends StatefulWidget {
  final bool? isUserAdmin;
  final Employee? loggedInEmployee;

  const UploadEmployeeScreen({
    super.key,
    this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  State<UploadEmployeeScreen> createState() => _UploadEmployeeScreenState();
}

class _UploadEmployeeScreenState extends State<UploadEmployeeScreen> {
  // ฟีเจอร์นี้ถูกปิดใช้งานชั่วคราว — โค้ดอัปโหลดถูกถอดออกเพื่อป้องกันการใช้งานโดยไม่ได้ตั้งใจ

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      isUserAdmin: widget.isUserAdmin ?? true,
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'รอพัฒนา',
      bodySlivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.construction, size: 64, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'รอพัฒนา',
                  style: GoogleFonts.anuphan(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ฟีเจอร์อัปโหลดข้อมูลพนักงานถูกปิดใช้งานชั่วคราว',
                  style: GoogleFonts.anuphan(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
