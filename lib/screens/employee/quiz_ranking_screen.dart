// lib/screens/employee/quiz_ranking_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';

// Helper class to hold combined data for the overall ranking
class EmployeeRank {
  final Employee employee;
  final int totalScore;
  final int quizzesCompleted;

  EmployeeRank({
    required this.employee,
    required this.totalScore,
    required this.quizzesCompleted,
  });
}

class QuizRankingScreen extends StatefulWidget {
  const QuizRankingScreen({super.key});

  @override
  State<QuizRankingScreen> createState() => _QuizRankingScreenState();
}

class _QuizRankingScreenState extends State<QuizRankingScreen> {
  Future<List<EmployeeRank>> _getOverallRanking() async {
    // 1. Fetch all employees and all completed assignments in parallel
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('users').get(),
      FirebaseFirestore.instance
          .collection('quiz_assignments')
          .where('status', isEqualTo: 'completed')
          .get(),
    ]);

    final employeeSnapshot = results[0] as QuerySnapshot;
    final assignmentSnapshot = results[1] as QuerySnapshot;

    final allEmployees = employeeSnapshot.docs.map((doc) => Employee.fromFirestore(doc)).toList();
    
    // 2. Calculate total scores and quiz counts for each employee
    final scores = <String, int>{};
    final counts = <String, int>{};

    for (final doc in assignmentSnapshot.docs) {
      final employeeId = doc['employeeId'] as String;
      final score = doc['score'] as int? ?? 0;
      
      scores.update(employeeId, (value) => value + score, ifAbsent: () => score);
      counts.update(employeeId, (value) => value + 1, ifAbsent: () => 1);
    }

    // 3. Create the final list of EmployeeRank objects
    final rankedList = allEmployees.map((employee) {
      return EmployeeRank(
        employee: employee,
        totalScore: scores[employee.employeeId] ?? 0,
        quizzesCompleted: counts[employee.employeeId] ?? 0,
      );
    }).toList();

    // 4. Sort the list by total score in descending order
    rankedList.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return rankedList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตารางคะแนนรวม (แบบทดสอบ)'),
      ),
      body: FutureBuilder<List<EmployeeRank>>(
        future: _getOverallRanking(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("เกิดข้อผิดพลาด: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.leaderboard_outlined, size: 100, color: Colors.grey.shade300),
                  const SizedBox(height: 24),
                  Text(
                    'ยังไม่มีข้อมูลคะแนนสะสม',
                    style: GoogleFonts.anuphan(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }
          
          final rankedList = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {}); // Rerun the future
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: rankedList.length,
              itemBuilder: (context, index) {
                final rankData = rankedList[index];
                return _RankingListItem(
                  rank: index + 1,
                  rankData: rankData,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RankingListItem extends StatelessWidget {
  final int rank;
  final EmployeeRank rankData;

  const _RankingListItem({
    required this.rank,
    required this.rankData,
  });

  @override
  Widget build(BuildContext context) {
    final Color rankColor;
    final IconData rankIcon;
    switch (rank) {
      case 1: rankColor = Colors.amber.shade600; rankIcon = Icons.emoji_events; break;
      case 2: rankColor = Colors.grey.shade500; rankIcon = Icons.emoji_events; break;
      case 3: rankColor = const Color(0xFFCD7F32); rankIcon = Icons.emoji_events; break;
      default: rankColor = Colors.transparent; rankIcon = Icons.circle;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 50,
          child: Row(
            children: [
              Text('$rank', style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold, color: rank <= 3 ? rankColor : Colors.black87)),
              if (rank <= 3) ...[const SizedBox(width: 4), Icon(rankIcon, color: rankColor, size: 24)]
            ],
          ),
        ),
        title: Text(rankData.employee.fullName, style: GoogleFonts.anuphan()),
        subtitle: Text('ทำไป ${rankData.quizzesCompleted} ชุด', style: GoogleFonts.anuphan(fontSize: 12)),
        trailing: Text(
          '${rankData.totalScore} คะแนน',
          style: GoogleFonts.anuphan(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
