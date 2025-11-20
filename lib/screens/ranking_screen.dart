// lib/screens/ranking_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/widgets/app_layout.dart';

class RankingScreen extends StatefulWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const RankingScreen({
    super.key,
    required this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  @override
  Widget build(BuildContext context) {
    return AppLayout(
      isUserAdmin: widget.isUserAdmin,
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'อันดับคะแนน',
      showBackButton: false,
      bodySlivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'ตารางจัดอันดับพนักงาน',
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [const Shadow(blurRadius: 2, color: Colors.black26)],
              ),
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              // --- [START] MODIFIED CODE: Update query for new leveling system ---
              .orderBy('level', descending: true)
              .orderBy('exp', descending: true)
              // --- [END] MODIFIED CODE ---
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.white)));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SliverFillRemaining(child: Center(child: Text('ไม่มีข้อมูลคะแนน', style: TextStyle(color: Colors.white))));
            }

            final employees = snapshot.data!.docs.map((doc) => Employee.fromFirestore(doc)).toList();

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final employee = employees[index];
                    return _RankingListItem(
                      employee: employee,
                      rank: index + 1,
                    );
                  },
                  childCount: employees.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RankingListItem extends StatelessWidget {
  final Employee employee;
  final int rank;

  const _RankingListItem({required this.employee, required this.rank});

  @override
  Widget build(BuildContext context) {
    final Color rankColor;
    final IconData rankIcon;

    switch (rank) {
      case 1:
        rankColor = Colors.amber;
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = Colors.grey.shade400;
        rankIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = const Color(0xFFCD7F32); // Bronze
        rankIcon = Icons.emoji_events;
        break;
      default:
        rankColor = Colors.transparent;
        rankIcon = Icons.circle; // Placeholder
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: SizedBox(
          width: 50,
          child: Row(
            children: [
              Text(
                '$rank',
                style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold, color: rank <= 3 ? rankColor : Colors.black),
              ),
              if (rank <= 3) ...[
                const SizedBox(width: 4),
                Icon(rankIcon, color: rankColor, size: 24),
              ]
            ],
          ),
        ),
        title: Text(employee.fullName, style: GoogleFonts.anuphan(fontWeight: FontWeight.w600)),
        // --- [START] MODIFIED CODE: Show level title in subtitle ---
        subtitle: Text(employee.levelTitle, style: GoogleFonts.anuphan(color: Colors.grey.shade600)),
        // --- [END] MODIFIED CODE ---
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Lv. ${employee.level}',
              style: GoogleFonts.anuphan(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
            ),
            Text(
              '${employee.exp}/${employee.nextLevelExp} EXP',
              style: GoogleFonts.anuphan(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
