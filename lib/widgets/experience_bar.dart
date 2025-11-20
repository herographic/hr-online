// lib/widgets/experience_bar.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';

class ExperienceBar extends StatelessWidget {
  final Employee employee;

  const ExperienceBar({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    final double progress = employee.exp / employee.nextLevelExp;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Lv. ${employee.level} ',
                      style: GoogleFonts.anuphan(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white),
                    ),
                    TextSpan(
                      text: employee.levelTitle,
                      style: GoogleFonts.anuphan(
                          fontSize: 16,
                          color: Colors.amber.shade200,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Text(
                '${employee.exp} / ${employee.nextLevelExp} EXP',
                style: GoogleFonts.anuphan(
                    fontSize: 14, color: Colors.white.withOpacity(0.9)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.black.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
        ],
      ),
    );
  }
}
