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
                attendanceProvider.statuses[employee.employeeId] ??
                    EmployeeAttendanceStatus.unknown;

            return GestureDetector(
              onTap: onTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: ClipPath(
                            clipper: _SemicircleClipper(),
                            child: Container(
                              color: _getStatusColor(attendanceStatus)
                                  .withOpacity(0.15),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: Column(
                            children: [
                              Text(
                                employee.nickname,
                                style: GoogleFonts.anuphan(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                positionText.isEmpty
                                    ? '(${employee.employeeId})'
                                    : positionText,
                                style: GoogleFonts.anuphan(
                                    fontSize: 11, color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: EmployeeStatusAvatar(
                      employeeId: employee.employeeId,
                      imageUrl: employee.profileImageUrl,
                      gender: employee.gender,
                      radius: 30,
                    ),
                  ),
                  if (employee.isOutsource)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade900,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1.5)
                        ),
                        child: Text(
                          'OutSource',
                          style: GoogleFonts.anuphan(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // --- [START] NEW WIDGET: Employment Status Badge ---
                  if (employee.employmentStatus != null && employee.employmentStatus!.isNotEmpty)
                    Positioned(
                      bottom: 45, // Adjust position to be over the avatar
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.shade800.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            employee.employmentStatus!,
                            style: GoogleFonts.anuphan(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  // --- [END] NEW WIDGET: Employment Status Badge ---
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Color _getStatusColor(EmployeeAttendanceStatus status) {
    switch (status) {
      case EmployeeAttendanceStatus.checkedIn:
        return Colors.green.shade500;
      case EmployeeAttendanceStatus.checkedOut:
        return Colors.red.shade500;
      case EmployeeAttendanceStatus.dayOff:
        return Colors.blue.shade500;
      case EmployeeAttendanceStatus.absent:
        return Colors.grey.shade400;
      default:
        return Colors.transparent;
    }
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircleAvatar(radius: 30, backgroundColor: Colors.white24),
        const SizedBox(height: 12),
        Container(
            height: 12,
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
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height),
        radius: size.width / 2,
      ),
      math.pi, 
      math.pi, 
      false,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
