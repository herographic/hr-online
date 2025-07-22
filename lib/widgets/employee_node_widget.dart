// lib/widgets/employee_node_widget.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';

class EmployeeNode extends StatelessWidget {
  final Employee employee;
  final VoidCallback onTap;

  const EmployeeNode({
    super.key,
    required this.employee,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // [MODIFIED] สร้าง Logic ในการเลือกรูปภาพที่จะแสดง
    ImageProvider? backgroundImage;
    
    // 1. ถ้ามี URL รูปโปรไฟล์ ให้ใช้รูปนั้นก่อน
    if (employee.profileImageUrl != null && employee.profileImageUrl!.isNotEmpty) {
      backgroundImage = NetworkImage(employee.profileImageUrl!);
    } 
    // 2. ถ้าไม่มีรูปโปรไฟล์ ให้เช็คเพศ
    else if (employee.gender == 'ชาย') {
      backgroundImage = const AssetImage('assets/images/boy.png');
    } else if (employee.gender == 'หญิง') {
      backgroundImage = const AssetImage('assets/images/girl.png');
    }
    // ถ้าไม่เข้าเงื่อนไขใดๆ เลย backgroundImage จะเป็น null

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.green.shade400,
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white,
              // [MODIFIED] ใช้ backgroundImage ที่เราเตรียมไว้
              backgroundImage: backgroundImage,
              // [MODIFIED] จะแสดงตัวอักษรย่อก็ต่อเมื่อไม่มีรูปภาพใดๆ เลย
              child: (backgroundImage == null)
                  ? Text(
                      employee.firstName.isNotEmpty ? employee.firstName[0] : '?',
                      style: GoogleFonts.anuphan(
                        color: Theme.of(context).primaryColor,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            employee.nickname,
            style: GoogleFonts.anuphan(fontWeight: FontWeight.bold, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '(${employee.employeeId})',
            style: GoogleFonts.anuphan(fontSize: 12, color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
