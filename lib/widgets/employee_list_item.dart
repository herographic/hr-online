// lib/widgets/employee_list_item.dart

import 'package:flutter/material.dart';
import 'package:hr_online/models/employee_model.dart';

class EmployeeListItem extends StatelessWidget {
  final Employee employee;
  final bool isCheckedIn;
  final VoidCallback? onCheckInTap; // [MODIFIED] ทำให้เป็น nullable (สามารถรับค่า null ได้)
  final VoidCallback onCardTap;

  const EmployeeListItem({
    super.key,
    required this.employee,
    required this.isCheckedIn,
    this.onCheckInTap, // [MODIFIED] ทำให้เป็น optional parameter
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: Row(
            children: [
              // ปุ่มสำหรับเช็คชื่อ
              IconButton(
                icon: Icon(
                  isCheckedIn ? Icons.check_circle : Icons.circle_outlined,
                  color: isCheckedIn ? Colors.green[600] : Colors.grey.shade400,
                ),
                iconSize: 32,
                // [MODIFIED] ถ้า onCheckInTap เป็น null ปุ่มจะกดไม่ได้เองโดยอัตโนมัติ
                onPressed: onCheckInTap,
              ),
              const SizedBox(width: 8),
              // ข้อมูลพนักงาน
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.employeeId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ชื่อ: ${employee.fullName}', // ใช้ fullName getter
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),
              // ไอคอนสำหรับไปหน้ารายละเอียด
              const Icon(Icons.arrow_forward_ios, color: Colors.grey),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
