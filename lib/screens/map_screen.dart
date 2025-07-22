// lib/screens/map_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/widgets/app_layout.dart'; // Import layout ใหม่

class MapScreen extends StatelessWidget {
  final Employee? loggedInEmployee;
  final bool isUserAdmin;

  const MapScreen({
    super.key,
    this.loggedInEmployee,
    required this.isUserAdmin,
  });

  @override
  Widget build(BuildContext context) {
    // --- [START] CODE EDITED ---
    // เปลี่ยนไปใช้ AppLayout
    return AppLayout(
      isUserAdmin: isUserAdmin,
      loggedInEmployee: loggedInEmployee,
      overrideTitle: 'แผนที่',
      bodySlivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 100,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(height: 20),
                Text(
                  'หน้านี้อยู่ระหว่างการพัฒนา',
                  style: GoogleFonts.anuphan(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    // --- [END] CODE EDITED ---
  }
}
