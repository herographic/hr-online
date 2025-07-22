import 'package:flutter/material.dart';
import 'package:hr_online/providers/attendance_status_provider.dart';
import 'package:hr_online/widgets/employee_avatar.dart';
import 'package:provider/provider.dart';

class EmployeeStatusAvatar extends StatelessWidget {
  final String employeeId;
  final String? imageUrl;
  final String? gender;
  final double radius;

  const EmployeeStatusAvatar({
    super.key,
    required this.employeeId,
    this.imageUrl,
    this.gender,
    this.radius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    // ใช้ Consumer เพื่อดึงข้อมูลสถานะล่าสุดจาก Provider
    return Consumer<AttendanceStatusProvider>(
      builder: (context, provider, child) {
        // ดึงสถานะของพนักงานคนนี้
        final status = provider.statuses[employeeId] ?? EmployeeAttendanceStatus.unknown;
        
        // กำหนดสีของกรอบตามสถานะ
        final Color borderColor;
        switch (status) {
          case EmployeeAttendanceStatus.checkedIn:
            borderColor = Colors.green.shade500;
            break;
          case EmployeeAttendanceStatus.checkedOut:
            borderColor = Colors.red.shade500;
            break;
          case EmployeeAttendanceStatus.dayOff:
            borderColor = Colors.blue.shade500;
            break;
          case EmployeeAttendanceStatus.absent:
            borderColor = Colors.grey.shade400;
            break;
          default:
            borderColor = Colors.transparent;
        }

        // สร้าง Widget ที่มีกรอบล้อมรอบ EmployeeAvatar เดิม
        return Container(
          padding: const EdgeInsets.all(2.0), // ความหนาของกรอบ
          decoration: BoxDecoration(
            color: borderColor,
            shape: BoxShape.circle,
            boxShadow: [
              if (status != EmployeeAttendanceStatus.unknown && status != EmployeeAttendanceStatus.absent)
                BoxShadow(
                  color: borderColor.withOpacity(0.5),
                  blurRadius: 4.0,
                  spreadRadius: 1.0,
                ),
            ],
          ),
          child: EmployeeAvatar(
            imageUrl: imageUrl,
            gender: gender,
            radius: radius,
          ),
        );
      },
    );
  }
}
