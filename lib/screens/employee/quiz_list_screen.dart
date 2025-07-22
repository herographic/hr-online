// lib/screens/employee/quiz_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/quiz_model.dart';
import 'package:hr_online/screens/employee/quiz_taking_screen.dart';

class QuizListScreen extends StatefulWidget {
  final Employee loggedInEmployee;

  const QuizListScreen({super.key, required this.loggedInEmployee});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  // ฟังก์ชันสำหรับดึงข้อมูลแบบทดสอบที่ได้รับมอบหมาย
  Future<List<Map<String, dynamic>>> _fetchAssignedQuizzes() async {
    // --- [START] MODIFIED CODE: Removed .orderBy() to avoid needing an index ---
    final assignmentSnapshot = await FirebaseFirestore.instance
        .collection('quiz_assignments')
        .where('employeeId', isEqualTo: widget.loggedInEmployee.employeeId)
        // .orderBy('assignedAt', descending: true) // This line is commented out
        .get();
    // --- [END] MODIFIED CODE ---

    if (assignmentSnapshot.docs.isEmpty) {
      return [];
    }

    List<Future<Map<String, dynamic>>> quizFutures = assignmentSnapshot.docs.map((doc) async {
      final assignment = QuizAssignment.fromFirestore(doc);
      final quizDoc = await FirebaseFirestore.instance.collection('quizzes').doc(assignment.quizId).get();
      if (quizDoc.exists) {
        return {
          'assignment': assignment,
          'quiz': Quiz.fromFirestore(quizDoc, []), // Pass empty questions list for now
        };
      }
      return <String, dynamic>{}; // Return a correctly typed empty map
    }).toList();

    final results = await Future.wait(quizFutures);
    // Sort manually in the app since we removed orderBy from the query
    results.sort((a, b) {
      final aTime = (a['assignment'] as QuizAssignment).assignedAt ?? Timestamp(0, 0);
      final bTime = (b['assignment'] as QuizAssignment).assignedAt ?? Timestamp(0, 0);
      return bTime.compareTo(aTime); // Sort descending
    });
    return results.where((res) => res.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แบบทดสอบของฉัน'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAssignedQuizzes(),
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
                  Icon(Icons.checklist_rtl, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('ยังไม่มีแบบทดสอบที่ได้รับมอบหมาย'),
                ],
              ),
            );
          }

          final assignedQuizzes = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {}); // Refresh the FutureBuilder
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: assignedQuizzes.length,
              itemBuilder: (context, index) {
                final Quiz quiz = assignedQuizzes[index]['quiz'];
                final QuizAssignment assignment = assignedQuizzes[index]['assignment'];
                final bool isCompleted = assignment.status == 'completed';

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCompleted ? Colors.green : Theme.of(context).primaryColor,
                      child: Icon(
                        isCompleted ? Icons.check_circle : Icons.pending_actions,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(quiz.title, style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      isCompleted 
                        ? 'ทำแล้ว | ได้ ${assignment.score ?? 0} คะแนน' 
                        : 'ยังไม่ได้ทำ',
                      style: GoogleFonts.anuphan(
                        color: isCompleted ? Colors.green : Colors.orange.shade800,
                      ),
                    ),
                    trailing: isCompleted ? null : const Icon(Icons.arrow_forward_ios),
                    onTap: isCompleted ? null : () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => QuizTakingScreen(
                          quizId: quiz.id,
                          assignmentId: assignment.id,
                        ),
                      )).then((_) => setState(() {})); // Refresh list after taking quiz
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
