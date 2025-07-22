// lib/widgets/employee_grid_node.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';

class EmployeeGridNode extends StatelessWidget {
  final Employee employee;
  final VoidCallback onTap;
  final bool isScheduled;
  final bool isDayOff;

  const EmployeeGridNode({
    super.key,
    required this.employee,
    required this.onTap,
    this.isScheduled = false,
    this.isDayOff = false,
  });

  @override
  Widget build(BuildContext context) {
    final double opacity = isDayOff ? 1.0 : (isScheduled ? 1.0 : 0.4);

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // [MODIFIED] Stack now only wraps the avatar and the overlay
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: (isScheduled || isDayOff)
                      ? Colors.green.withOpacity(0.8)
                      : Colors.grey.withOpacity(0.8),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    backgroundImage: employee.profileImageUrl != null
                        ? NetworkImage(employee.profileImageUrl!)
                        : _getGenderAvatar(),
                  ),
                ),
                // "Day Off" Indicator Overlay
                if (isDayOff)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      // [MODIFIED] Changed color to a lighter, semi-transparent red
                      color: Colors.red.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'หยุด',
                        style: GoogleFonts.anuphan(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              employee.nickname,
              style: GoogleFonts.anuphan(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '(${employee.employeeId})',
              style: GoogleFonts.anuphan(
                fontSize: 10,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _getGenderAvatar() {
    if (employee.gender == 'ชาย') {
      return const AssetImage('assets/images/boy.png');
    } else if (employee.gender == 'หญิง') {
      return const AssetImage('assets/images/girl.png');
    }
    return null;
  }
}
