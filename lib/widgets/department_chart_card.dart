// lib/widgets/department_chart_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/screens/employee_detail_screen.dart';
import 'package:hr_online/widgets/employee_node_widget.dart';

class DepartmentChartCard extends StatelessWidget {
  final Department department;
  final List<Employee> checkedInEmployees;
  final bool isUserAdmin;

  const DepartmentChartCard({
    super.key,
    required this.department,
    required this.checkedInEmployees,
    required this.isUserAdmin,
  });

  @override
  Widget build(BuildContext context) {
    // กรองพนักงานที่อยู่ในแผนกนี้เท่านั้น
    final employeesInDept = checkedInEmployees
        .where((emp) => emp.departmentCode == department.id)
        .toList();

    if (employeesInDept.isEmpty) {
      return const SizedBox.shrink(); // ไม่ต้องแสดง Card ถ้าไม่มีพนักงานในแผนกนี้
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          department.name,
          style: GoogleFonts.anuphan(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
        ),
        subtitle: Text('${employeesInDept.length} คนเข้างานแล้ว', style: GoogleFonts.anuphan()),
        initiallyExpanded: true,
        childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Wrap(
              spacing: 24,
              runSpacing: 16,
              children: employeesInDept.map((emp) {
                return EmployeeNode(
                  employee: emp,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EmployeeDetailScreen(
                          // --- [START] MODIFIED CODE ---
                          // แก้ไขให้ส่ง employeeId ไปแทนอ็อบเจกต์ employee ทั้งหมด
                          employeeId: emp.employeeId,
                          // --- [END] MODIFIED CODE ---
                          isUserAdmin: isUserAdmin,
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}
