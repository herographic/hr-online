// lib/screens/employee/quiz_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/quiz_model.dart';
import 'package:hr_online/screens/employee/quiz_taking_screen.dart';
import 'package:hr_online/models/realtime_quiz_models.dart';
import 'package:hr_online/screens/employee/quiz_lobby_screen.dart';
import 'package:hr_online/screens/employee/quiz_gameplay_screen.dart';


class QuizListScreen extends StatefulWidget {
  final Employee loggedInEmployee;

  const QuizListScreen({super.key, required this.loggedInEmployee});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  Future<List<Map<String, dynamic>>> _fetchAssignedQuizzes() async {
    final assignmentSnapshot = await FirebaseFirestore.instance
        .collection('quiz_assignments')
        .where('employeeId', isEqualTo: widget.loggedInEmployee.employeeId)
        .get();

    if (assignmentSnapshot.docs.isEmpty) {
      return [];
    }

    List<Future<Map<String, dynamic>>> quizFutures = assignmentSnapshot.docs.map((doc) async {
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

    final results = await Future.wait(quizFutures);
    results.sort((a, b) {
      final aTime = (a['assignment'] as QuizAssignment).assignedAt ?? Timestamp(0, 0);
      final bTime = (b['assignment'] as QuizAssignment).assignedAt ?? Timestamp(0, 0);
      return bTime.compareTo(aTime);
    });
    return results.where((res) => res.isNotEmpty).toList();
  }

  Stream<QuerySnapshot> _getActiveGameShowsStream() {
    return FirebaseFirestore.instance
        .collection('realtime_quiz_sessions')
        .where('status', whereIn: ['waiting', 'countdown', 'question_active', 'question_result'])
        .snapshots();
  }
  
  /// Handles joining a game show, routing to lobby or gameplay based on status.
  Future<void> _joinGameShow(RealtimeQuizSession session) async {
    final sessionDoc = await FirebaseFirestore.instance
        .collection('realtime_quiz_sessions')
        .doc(session.id)
        .get();
    
    final currentStatus = sessionDoc.data()?['status'] ?? 'waiting';

    if (!mounted) return;

    Widget targetScreen;
    if (currentStatus == 'waiting') {
      targetScreen = QuizLobbyScreen(
        quizId: session.id,
        loggedInEmployee: widget.loggedInEmployee,
      );
    } else {
      // If game has started, go directly to the gameplay screen
      targetScreen = QuizGameplayScreen(
        quizId: session.id,
        loggedInEmployee: widget.loggedInEmployee,
      );
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => targetScreen));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แบบทดสอบของฉัน'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'เกมโชว์ (แข่งขันสด)', Icons.videogame_asset),
          _buildGameShowList(),
          _buildSectionHeader(context, 'แบบทดสอบทั่วไป', Icons.description),
          Expanded(child: _buildStandardQuizList()),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildGameShowList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getActiveGameShowsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Center(child: Text('ยังไม่มีการแข่งขันสดในขณะนี้', style: TextStyle(color: Colors.grey))),
          );
        }

        final gameSessions = snapshot.data!.docs.map((doc) => RealtimeQuizSession.fromFirestore(doc)).toList();

        return SizedBox(
          height: 120,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            scrollDirection: Axis.horizontal,
            itemCount: gameSessions.length,
            itemBuilder: (context, index) {
              final session = gameSessions[index];
              return Card(
                elevation: 2,
                child: Container(
                  width: 250,
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(session.quizTitle, style: GoogleFonts.anuphan(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis,),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.login),
                          label: const Text('เข้าร่วม'),
                          onPressed: () => _joinGameShow(session),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStandardQuizList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAssignedQuizzes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('ยังไม่มีแบบทดสอบที่ได้รับมอบหมาย', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        final assignedQuizzes = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
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
                    )).then((_) => setState(() {}));
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
