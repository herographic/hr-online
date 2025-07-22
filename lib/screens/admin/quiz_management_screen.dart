// lib/screens/admin/quiz_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/quiz_model.dart';
import 'package:hr_online/screens/admin/quiz_editor_screen.dart';
import 'package:intl/intl.dart';

class QuizManagementScreen extends StatefulWidget {
  const QuizManagementScreen({super.key});

  @override
  State<QuizManagementScreen> createState() => _QuizManagementScreenState();
}

class _QuizManagementScreenState extends State<QuizManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ออกแบบทดสอบพนักงาน'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('quizzes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quiz_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('ยังไม่มีแบบทดสอบ'),
                  const SizedBox(height: 8),
                  const Text('กดปุ่ม + เพื่อสร้างแบบทดสอบใหม่', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final quizzes = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: quizzes.length,
            itemBuilder: (context, index) {
              final doc = quizzes[index];
              final quiz = Quiz.fromFirestore(doc, []); // Pass empty list for now

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(quiz.isActive ? Icons.check_circle : Icons.pause_circle_filled,
                        color: quiz.isActive ? Colors.green : Colors.grey),
                  ),
                  title: Text(quiz.title, style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'สร้างเมื่อ: ${DateFormat('d MMM yyyy', 'th_TH').format(quiz.createdAt.toDate())}',
                    style: GoogleFonts.anuphan(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => QuizEditorScreen(quizId: quiz.id),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const QuizEditorScreen(quizId: null),
          ));
        },
        tooltip: 'สร้างแบบทดสอบใหม่',
        child: const Icon(Icons.add),
      ),
    );
  }
}
