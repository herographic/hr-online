// lib/widgets/employee_presence_node.dart

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/providers/attendance_status_provider.dart';
import 'package:hr_online/widgets/employee_status_avatar.dart';
import 'package:provider/provider.dart';

class EmployeePresenceNode extends StatelessWidget {
  final String employeeId;
  final VoidCallback onTap;

  const EmployeePresenceNode({
    super.key,
    required this.employeeId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(employeeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildPlaceholder();
        }

        final employee = Employee.fromFirestore(snapshot.data!);
        final positionText =
            employee.positions.map((p) => p['name'] ?? '').join(', ');

        return Consumer<AttendanceStatusProvider>(
          builder: (context, attendanceProvider, child) {
            final attendanceStatus =
                attendanceProvider.statuses[employeeId] ??
                    EmployeeAttendanceStatus.unknown;

            final bool isOnline =
                attendanceStatus == EmployeeAttendanceStatus.checkedIn;
            final Color onlineStatusColor =
                isOnline ? Colors.green.shade400 : Colors.red.shade400;
            final String onlineStatusText = isOnline ? 'Online' : 'Offline';

            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      EmployeeStatusAvatar(
                        employeeId: employee.employeeId,
                        imageUrl: employee.profileImageUrl,
                        gender: employee.gender,
                        radius: 32,
                      ),
                      // Overlay for employment status (ลาออก, etc.)
                      if (employee.employmentStatus != null &&
                          employee.employmentStatus!.isNotEmpty)
                        ClipPath(
                          clipper: _SemicircleClipper(),
                          child: Container(
                            width: 68, // Should match avatar diameter + padding
                            height: 34, // Half of the width
                            alignment: Alignment.topCenter,
                            padding: const EdgeInsets.only(top: 2),
                            color: Colors.redAccent.withOpacity(0.50),
                            child: Text(
                              employee.employmentStatus!,
                              style: GoogleFonts.anuphan(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    employee.nickname,
                    style: GoogleFonts.anuphan(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '(${employee.employeeId})',
                    style: GoogleFonts.anuphan(
                        fontSize: 11, color: Colors.white.withOpacity(0.7)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (positionText.isNotEmpty)
                    Text(
                      positionText,
                      style: GoogleFonts.anuphan(
                          fontSize: 11, color: Colors.white.withOpacity(0.7)),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: onlineStatusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        onlineStatusText,
                        style: GoogleFonts.anuphan(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircleAvatar(radius: 34, backgroundColor: Colors.white24),
        const SizedBox(height: 8),
        Container(
            height: 14,
            width: 60,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 4),
        Container(
            height: 12,
            width: 80,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 4),
        Container(
            height: 12,
            width: 50,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4))),
      ],
    );
  }
}

// Custom Clipper for the semi-circle overlay
class _SemicircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.arcTo(
      // Corrected: Use Rect.fromCircle which accepts a radius.
      // This creates a bounding box for a circle centered at the bottom-middle
      // of the container, allowing us to draw the top semi-circular arc.
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height),
        radius: size.width / 2,
      ),
      math.pi, // Start angle (180 degrees, on the left)
      math.pi, // Sweep angle (180 degrees, drawing the top half)
      false,
    );
    path.close(); // Close the path to form the semi-circle shape
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
