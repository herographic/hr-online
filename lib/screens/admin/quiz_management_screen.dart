// lib/screens/admin/quiz_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/quiz_model.dart';
import 'package:hr_online/screens/admin/quiz_editor_screen.dart';
import 'package:intl/intl.dart';
import 'package:hr_online/screens/admin/quiz_host_screen.dart'; 

class QuizManagementScreen extends StatefulWidget {
  const QuizManagementScreen({super.key});

  @override
  State<QuizManagementScreen> createState() => _QuizManagementScreenState();
}

class _QuizManagementScreenState extends State<QuizManagementScreen> {

  // --- [START] NEW METHODS ---

  /// Toggles the active status of a quiz.
  Future<void> _toggleQuizStatus(Quiz quiz) async {
    try {
      await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(quiz.id)
          .update({'isActive': !quiz.isActive});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เปลี่ยนสถานะ "${quiz.title}" เป็น ${!quiz.isActive ? "เปิดใช้งาน" : "ปิดใช้งาน"} แล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Deletes a quiz and all its related data.
  Future<void> _deleteQuiz(Quiz quiz) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบแบบทดสอบ "${quiz.title}" และข้อมูลที่เกี่ยวข้องทั้งหมดใช่หรือไม่? การกระทำนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final quizRef = FirebaseFirestore.instance.collection('quizzes').doc(quiz.id);

      // Delete questions subcollection
      final questionsSnapshot = await quizRef.collection('questions').get();
      for (var doc in questionsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // If it's a game show, delete the session and its subcollections
      if (quiz.quizType == QuizType.gameShow) {
        final sessionRef = FirebaseFirestore.instance.collection('realtime_quiz_sessions').doc(quiz.id);
        final playersSnapshot = await sessionRef.collection('players').get();
        for (var doc in playersSnapshot.docs) {
          batch.delete(doc.reference);
        }
        final answersSnapshot = await sessionRef.collection('answers').get();
        for (var doc in answersSnapshot.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(sessionRef);
      }

      // Delete main quiz document
      batch.delete(quizRef);

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ลบ "${quiz.title}" สำเร็จ'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  // --- [END] NEW METHODS ---


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
              final quiz = Quiz.fromFirestore(doc, []); 

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: quiz.quizType == QuizType.gameShow ? Colors.deepPurple.shade100 : Colors.blue.shade100,
                    child: Icon(
                      quiz.quizType == QuizType.gameShow ? Icons.videogame_asset : Icons.description,
                      color: quiz.quizType == QuizType.gameShow ? Colors.deepPurple : Colors.blue,
                    ),
                  ),
                  title: Text(quiz.title, style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'ประเภท: ${quiz.quizType == QuizType.gameShow ? "เกมโชว์" : "ปกติ"} | สถานะ: ${quiz.isActive ? "เปิด" : "ปิด"}',
                    style: GoogleFonts.anuphan(fontSize: 12, color: quiz.isActive ? Colors.green.shade700 : Colors.red.shade700),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                         if (quiz.quizType == QuizType.gameShow) {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => QuizHostScreen(quiz: quiz),
                          ));
                        } else {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => QuizEditorScreen(quizId: quiz.id),
                          ));
                        }
                      } else if (value == 'toggle') {
                        _toggleQuizStatus(quiz);
                      } else if (value == 'delete') {
                        _deleteQuiz(quiz);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Text(quiz.quizType == QuizType.gameShow ? 'จัดการแข่งขัน' : 'แก้ไข'),
                      ),
                      PopupMenuItem<String>(
                        value: 'toggle',
                        child: Text(quiz.isActive ? 'ปิดการแสดงผล' : 'เปิดการแสดงผล'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('ลบ', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                  onTap: () {
                     if (quiz.quizType == QuizType.gameShow) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => QuizHostScreen(quiz: quiz),
                      ));
                    } else {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => QuizEditorScreen(quizId: quiz.id),
                      ));
                    }
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
