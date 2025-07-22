// lib/screens/employee/my_quiz_rankings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/quiz_model.dart';
import 'package:hr_online/screens/employee/quiz_ranking_detail_screen.dart';

class MyQuizRankingsScreen extends StatefulWidget {
  final Employee loggedInEmployee;
  const MyQuizRankingsScreen({super.key, required this.loggedInEmployee});

  @override
  State<MyQuizRankingsScreen> createState() => _MyQuizRankingsScreenState();
}

class _MyQuizRankingsScreenState extends State<MyQuizRankingsScreen> {
  // Fetches all quizzes completed by the logged-in employee.
  Future<List<Map<String, dynamic>>> _fetchCompletedQuizzes() async {
    final assignmentSnapshot = await FirebaseFirestore.instance
        .collection('quiz_assignments')
        .where('employeeId', isEqualTo: widget.loggedInEmployee.employeeId)
        .where('status', isEqualTo: 'completed')
        .get();

    if (assignmentSnapshot.docs.isEmpty) return [];

    List<Future<Map<String, dynamic>>> futures = assignmentSnapshot.docs.map((doc) async {
      final assignment = QuizAssignment.fromFirestore(doc);
      final quizDoc = await FirebaseFirestore.instance.collection('quizzes').doc(assignment.quizId).get();
      if (quizDoc.exists) {
        return {
          'assignment': assignment,
          'quiz': Quiz.fromFirestore(quizDoc, []),
        };
      }
      return <String, dynamic>{};
    }).toList();

    final results = await Future.wait(futures);
    return results.where((res) => res.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('อันดับของฉัน'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchCompletedQuizzes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('คุณยังไม่มีผลการทดสอบ'),
                ],
              ),
            );
          }
          final completedQuizzes = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: completedQuizzes.length,
            itemBuilder: (context, index) {
              final Quiz quiz = completedQuizzes[index]['quiz'];
              final QuizAssignment assignment = completedQuizzes[index]['assignment'];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.leaderboard, color: Colors.blueAccent),
                  title: Text(quiz.title, style: GoogleFonts.anuphan()),
                  subtitle: Text('คะแนนที่ได้: ${assignment.score}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => QuizRankingDetailScreen(
                        quiz: quiz,
                        highlightEmployeeId: widget.loggedInEmployee.employeeId,
                      ),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
