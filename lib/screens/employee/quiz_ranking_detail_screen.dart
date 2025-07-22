// lib/screens/employee/quiz_ranking_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/quiz_model.dart';

// Helper class to hold combined data for ranking
class QuizResult {
  final Employee employee;
  final QuizAssignment assignment;
  QuizResult({required this.employee, required this.assignment});
}

// Detail screen for a specific quiz ranking
class QuizRankingDetailScreen extends StatelessWidget {
  final Quiz quiz;
  final String? highlightEmployeeId;

  const QuizRankingDetailScreen({
    super.key,
    required this.quiz,
    this.highlightEmployeeId,
  });

  Future<List<QuizResult>> _getRanking() async {
    final assignmentSnapshot = await FirebaseFirestore.instance
        .collection('quiz_assignments')
        .where('quizId', isEqualTo: quiz.id)
        .where('status', isEqualTo: 'completed')
        .get();

    if (assignmentSnapshot.docs.isEmpty) return [];

    final employeeIds = assignmentSnapshot.docs.map((doc) => doc['employeeId'] as String).toList();
    if (employeeIds.isEmpty) return [];

    final employeeSnapshot = await FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: employeeIds).get();
    final employeeMap = {for (var doc in employeeSnapshot.docs) doc.id: Employee.fromFirestore(doc)};

    List<QuizResult> results = [];
    for (var doc in assignmentSnapshot.docs) {
      final assignment = QuizAssignment.fromFirestore(doc);
      if (employeeMap.containsKey(assignment.employeeId)) {
        results.add(QuizResult(employee: employeeMap[assignment.employeeId]!, assignment: assignment));
      }
    }

    // Sort by score (desc), then by time (asc)
    results.sort((a, b) {
      final scoreComparison = (b.assignment.score ?? 0).compareTo(a.assignment.score ?? 0);
      if (scoreComparison != 0) return scoreComparison;
      return (a.assignment.durationInSeconds ?? 99999).compareTo(b.assignment.durationInSeconds ?? 99999);
    });

    return results;
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '-';
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('อันดับ: ${quiz.title}')),
      body: FutureBuilder<List<QuizResult>>(
        future: _getRanking(),
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
                  Icon(Icons.person_off_outlined, size: 100, color: Colors.grey.shade300),
                  const SizedBox(height: 24),
                  Text(
                    'ยังไม่มีผู้ทำแบบทดสอบ',
                    style: GoogleFonts.anuphan(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }
          final rankedResults = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            itemCount: rankedResults.length,
            itemBuilder: (context, index) {
              final result = rankedResults[index];
              return _RankingListItem(
                rank: index + 1,
                result: result,
                formattedDuration: _formatDuration(result.assignment.durationInSeconds),
                isHighlighted: result.employee.employeeId == highlightEmployeeId,
              );
            },
          );
        },
      ),
    );
  }
}

class _RankingListItem extends StatelessWidget {
  final int rank;
  final QuizResult result;
  final String formattedDuration;
  final bool isHighlighted;

  const _RankingListItem({
    required this.rank,
    required this.result,
    required this.formattedDuration,
    this.isHighlighted = false,
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
      color: isHighlighted ? Colors.blue.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHighlighted
            ? BorderSide(color: Theme.of(context).primaryColor, width: 1.5)
            : BorderSide.none,
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
        title: Text(result.employee.fullName, style: GoogleFonts.anuphan()),
        subtitle: Text('ID: ${result.employee.employeeId}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${result.assignment.score} คะแนน', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 15)),
            Text(formattedDuration, style: GoogleFonts.orbitron(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
