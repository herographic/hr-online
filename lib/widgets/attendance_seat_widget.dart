// lib/widgets/attendance_seat_widget.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';

class AttendanceSeatWidget extends StatelessWidget {
  final Employee employee;
  final VoidCallback onTap;
  final Animation<double> animation;

  const AttendanceSeatWidget({
    super.key,
    required this.employee,
    required this.onTap,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    // ใช้ ScaleTransition เพื่อสร้างอนิเมชั่น "ปรากฏตัว"
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack, // ทำให้มีเอฟเฟกต์เด้งเล็กน้อยตอนปรากฏ
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 90, // กำหนดความกว้างของแต่ละที่นั่ง
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.green.shade100,
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.green,
                  backgroundImage: employee.profileImageUrl != null
                      ? NetworkImage(employee.profileImageUrl!)
                      : null,
                  child: employee.profileImageUrl == null
                      ? Text(
                          employee.firstName.isNotEmpty ? employee.firstName[0] : '?',
                          style: GoogleFonts.anuphan(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                employee.nickname,
                style: GoogleFonts.anuphan(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                employee.employeeId,
                style: GoogleFonts.anuphan(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
