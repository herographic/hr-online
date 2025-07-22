// lib/screens/employee/quiz_taking_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/quiz_model.dart';
import 'package:collection/collection.dart';

class QuizTakingScreen extends StatefulWidget {
  final String quizId;
  final String assignmentId;

  const QuizTakingScreen({
    super.key,
    required this.quizId,
    required this.assignmentId,
  });

  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen> {
  bool _isLoading = true;
  Quiz? _quiz;
  List<Question> _questions = [];
  Map<String, List<String>> _userAnswers = {};

  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // --- [START] NEW STATE: For timing ---
  late DateTime _startTime;
  // --- [END] NEW STATE ---

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now(); // Record start time
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    try {
      final quizDoc = await FirebaseFirestore.instance.collection('quizzes').doc(widget.quizId).get();
      if (quizDoc.exists) {
        final questionsSnapshot = await quizDoc.reference.collection('questions').orderBy('text').get();
        _questions = questionsSnapshot.docs.map((doc) => Question.fromFirestore(doc)).toList();
        _quiz = Quiz.fromFirestore(quizDoc, _questions);
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onAnswerSelected(String questionId, String answer, QuestionType type) {
    setState(() {
      if (type == QuestionType.singleChoice || type == QuestionType.textInput) {
        _userAnswers[questionId] = [answer];
      } else {
        if (_userAnswers.containsKey(questionId)) {
          if (_userAnswers[questionId]!.contains(answer)) {
            _userAnswers[questionId]!.remove(answer);
          } else {
            _userAnswers[questionId]!.add(answer);
          }
        } else {
          _userAnswers[questionId] = [answer];
        }
      }
    });
  }

  Future<void> _submitQuiz() async {
    if (_userAnswers.length != _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาตอบคำถามให้ครบทุกข้อ')));
      return;
    }

    setState(() => _isLoading = true);

    // --- [START] MODIFIED LOGIC: Calculate score, max score, and duration ---
    int totalScore = 0;
    int maxPossibleScore = 0;
    final durationInSeconds = DateTime.now().difference(_startTime).inSeconds;

    for (final question in _questions) {
      maxPossibleScore += question.points;
      final userAnswersForQuestion = _userAnswers[question.id] ?? [];
      final correctAnswers = question.correctAnswers;
      bool isCorrect = false;
      if (question.type == QuestionType.textInput) {
        isCorrect = userAnswersForQuestion.isNotEmpty && userAnswersForQuestion.first.trim().toLowerCase() == correctAnswers.first.trim().toLowerCase();
      } else {
        isCorrect = const SetEquality().equals(
          userAnswersForQuestion.toSet(),
          correctAnswers.toSet(),
        );
      }
      if (isCorrect) {
        totalScore += question.points;
      }
    }
    // --- [END] MODIFIED LOGIC ---

    try {
      // --- [START] MODIFIED LOGIC: Save duration to Firestore ---
      await FirebaseFirestore.instance
          .collection('quiz_assignments')
          .doc(widget.assignmentId)
          .update({
            'status': 'completed',
            'score': totalScore,
            'completedAt': FieldValue.serverTimestamp(),
            'durationInSeconds': durationInSeconds,
          });
      // --- [END] MODIFIED LOGIC ---
      
      if (mounted) {
        // --- [START] MODIFIED LOGIC: Pass max score to dialog ---
        _showResultDialog(totalScore, maxPossibleScore);
        // --- [END] MODIFIED LOGIC ---
      }

    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
        setState(() => _isLoading = false);
      }
    }
  }
  
  // --- [START] MODIFIED DIALOG: Accept and display max score ---
  void _showResultDialog(int score, int maxScore) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('ส่งคำตอบเรียบร้อย'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('คะแนนที่คุณทำได้คือ:'),
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$score',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                  ),
                  TextSpan(
                    text: ' / $maxScore',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
             const Text('คะแนน'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to quiz list
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }
  // --- [END] MODIFIED DIALOG ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_quiz?.title ?? 'กำลังโหลด...'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _quiz == null
              ? const Center(child: Text('ไม่พบแบบทดสอบ'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LinearProgressIndicator(
                        value: (_currentPage + 1) / _questions.length,
                        minHeight: 10,
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _questions.length,
                        onPageChanged: (page) => setState(() => _currentPage = page),
                        itemBuilder: (context, index) {
                          return _buildQuestionCard(_questions[index]);
                        },
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _buildNavigationButtons(),
    );
  }

  Widget _buildQuestionCard(Question question) {
    final userAnswers = _userAnswers[question.id] ?? [];
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text('คำถามที่ ${_currentPage + 1}/${_questions.length}', style: GoogleFonts.anuphan(color: Colors.grey)),
        const SizedBox(height: 8),
        Text(question.text, style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        if (question.type == QuestionType.singleChoice)
          ...question.options.asMap().entries.map((entry) {
            return RadioListTile<String>(
              title: Text(entry.value),
              value: entry.key.toString(),
              groupValue: userAnswers.firstOrNull,
              onChanged: (value) => _onAnswerSelected(question.id, value!, question.type),
            );
          }),
        if (question.type == QuestionType.multipleChoice)
          ...question.options.asMap().entries.map((entry) {
            return CheckboxListTile(
              title: Text(entry.value),
              value: userAnswers.contains(entry.key.toString()),
              onChanged: (value) => _onAnswerSelected(question.id, entry.key.toString(), question.type),
            );
          }),
        if (question.type == QuestionType.textInput)
          TextFormField(
            initialValue: userAnswers.firstOrNull,
            decoration: const InputDecoration(labelText: 'พิมพ์คำตอบของคุณ'),
            onChanged: (value) => _onAnswerSelected(question.id, value, question.type),
          ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    bool isLastPage = _currentPage == _questions.length - 1;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            ElevatedButton(
              onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn),
              child: const Text('ย้อนกลับ'),
            ),
          const Spacer(),
          if (!isLastPage)
            ElevatedButton(
              onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn),
              child: const Text('ถัดไป'),
            ),
          if (isLastPage)
            ElevatedButton(
              onPressed: _submitQuiz,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('ส่งคำตอบ'),
            ),
        ],
      ),
    );
  }
}
