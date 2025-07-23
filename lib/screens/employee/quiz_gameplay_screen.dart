// lib/screens/employee/quiz_gameplay_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/quiz_model.dart';
import 'package:hr_online/models/realtime_quiz_models.dart';

class QuizGameplayScreen extends StatefulWidget {
  final String quizId;
  final Employee loggedInEmployee;

  const QuizGameplayScreen({
    super.key,
    required this.quizId,
    required this.loggedInEmployee,
  });

  @override
  State<QuizGameplayScreen> createState() => _QuizGameplayScreenState();
}

class _QuizGameplayScreenState extends State<QuizGameplayScreen> {
  Stream<DocumentSnapshot<RealtimeQuizSession>> _sessionStream = const Stream.empty();
  late DocumentReference<RealtimeQuizSession> _sessionRef;

  List<Question> _questions = [];
  bool _isLoading = true;
  String? _selectedAnswer;
  bool _hasAnswered = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _sessionRef = FirebaseFirestore.instance
        .collection('realtime_quiz_sessions')
        .doc(widget.quizId)
        .withConverter<RealtimeQuizSession>(
          fromFirestore: (snapshot, _) => RealtimeQuizSession.fromFirestore(snapshot),
          toFirestore: (session, _) => session.toFirestore(),
        );

    // Ensure player is in the lobby, especially for rejoins
    final playerRef = _sessionRef.collection('players').doc(widget.loggedInEmployee.employeeId);
    await playerRef.set({
      'nickname': widget.loggedInEmployee.nickname,
      'profileImageUrl': widget.loggedInEmployee.profileImageUrl,
      'totalScore': FieldValue.increment(0), // Use increment to avoid overwriting score on rejoin
    }, SetOptions(merge: true));


    final questionsSnapshot = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .collection('questions')
        .get();
        
    if (mounted) {
      setState(() {
        _questions = questionsSnapshot.docs.map((doc) => Question.fromFirestore(doc)).toList();
        _sessionStream = _sessionRef.snapshots();
        _isLoading = false;
      });
    }
  }

  Future<void> _submitAnswer(int questionIndex, String answer, Timestamp questionStartTime) async {
    if (_hasAnswered) return;
    setState(() => _hasAnswered = true);

    final answerTime = Timestamp.now();
    final timeTakenMs = answerTime.millisecondsSinceEpoch - questionStartTime.millisecondsSinceEpoch;
    
    final question = _questions[questionIndex];
    final isCorrect = question.correctAnswers.contains(answer);
    
    final int score = isCorrect ? question.points : 0;

    await _sessionRef
        .collection('answers')
        .doc('q_${questionIndex}_${widget.loggedInEmployee.employeeId}')
        .set({
          'employeeId': widget.loggedInEmployee.employeeId,
          'nickname': widget.loggedInEmployee.nickname,
          'answer': answer,
          'isCorrect': isCorrect,
          'timeTakenMs': timeTakenMs,
          'score': score,
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PopScope(
        canPop: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<DocumentSnapshot<RealtimeQuizSession>>(
                stream: _sessionStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(child: CircularProgressIndicator());
                  }
              
                  final session = snapshot.data!.data()!;
                  
                  if (session.status == 'countdown' && _hasAnswered) {
                     WidgetsBinding.instance.addPostFrameCallback((_) {
                       if(mounted) setState(() {
                         _hasAnswered = false;
                         _selectedAnswer = null;
                       });
                     });
                  }
              
                  switch (session.status) {
                    case 'countdown':
                      return _buildCountdownView(session);
                    case 'question_active':
                      return _buildQuestionView(session);
                    case 'question_result':
                      return _buildResultView(session);
                    case 'finished':
                      return _buildFinishedView(session);
                    default:
                      return const Center(child: Text("กำลังรอ..."));
                  }
                },
              ),
      ),
    );
  }

  Widget _buildCountdownView(RealtimeQuizSession session) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4e54c8), Color(0xFF8f94fb)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('คำถามข้อที่ ${session.currentQuestionIndex + 1}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
            const SizedBox(height: 20),
            _CountdownTimer(
              key: ValueKey(session.countdownEndTime),
              endTime: session.countdownEndTime?.toDate() ?? DateTime.now(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionView(RealtimeQuizSession session) {
    if (session.currentQuestionIndex < 0 || session.currentQuestionIndex >= _questions.length) {
      return const Center(child: Text('กำลังรอคำถาม...'));
    }
    final question = _questions[session.currentQuestionIndex];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4e54c8), Color(0xFF8f94fb)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'คำถามที่ ${session.currentQuestionIndex + 1}',
                style: GoogleFonts.anuphan(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                question.text,
                style: GoogleFonts.anuphan(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (_hasAnswered)
                const Column(
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('คุณตอบแล้ว! กำลังรอเฉลย...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              if (!_hasAnswered)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.0,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: question.options.length,
                  itemBuilder: (context, index) {
                    final option = question.options[index];
                    final answerValue = index.toString();
                    
                    return ElevatedButton(
                      onPressed: () {
                        setState(() => _selectedAnswer = answerValue);
                        _submitAnswer(session.currentQuestionIndex, answerValue, session.questionStartTime!);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.9),
                        foregroundColor: const Color(0xFF4e54c8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: GoogleFonts.anuphan(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      child: Text(option, textAlign: TextAlign.center),
                    );
                  },
                ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the view to show the result of a single question.
  Widget _buildResultView(RealtimeQuizSession session) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4e54c8), Color(0xFF8f94fb)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _sessionRef
              .collection('answers')
              .where(FieldPath.documentId, isGreaterThanOrEqualTo: 'q_${session.currentQuestionIndex}_')
              .where(FieldPath.documentId, isLessThan: 'q_${session.currentQuestionIndex}_z')
              .where('isCorrect', isEqualTo: true)
              .orderBy('timeTakenMs', descending: false)
              .limit(10)
              .snapshots(),
          builder: (context, answerSnapshot) {
            if (!answerSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final correctAnswers = answerSnapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return QuestionAnswerResult(
                nickname: data['nickname'] ?? 'N/A',
                employeeId: data['employeeId'] ?? 'N/A',
                timeTakenMs: data['timeTakenMs'] ?? 99999,
              );
            }).toList();
            
            final winner = correctAnswers.isNotEmpty ? correctAnswers.first : null;

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (winner != null) ...[
                    const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
                    const SizedBox(height: 8),
                    Text(
                      'เร็วที่สุดในข้อนี้!',
                      style: GoogleFonts.anuphan(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      '${winner.nickname} (${winner.employeeId})',
                      style: GoogleFonts.anuphan(fontSize: 20, color: Colors.white),
                    ),
                    Text(
                      'เวลา: ${(winner.timeTakenMs / 1000).toStringAsFixed(2)} วินาที',
                      style: GoogleFonts.anuphan(fontSize: 16, color: Colors.white70),
                    ),
                  ] else ...[
                    const Icon(Icons.sentiment_dissatisfied, size: 80, color: Colors.white70),
                    const SizedBox(height: 16),
                    Text('ไม่มีคนตอบถูกในข้อนี้', style: GoogleFonts.anuphan(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                  const Divider(height: 40, color: Colors.white54),
                  Text('อันดับ (Top 10)', style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      color: Colors.white.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListView.separated(
                        itemCount: correctAnswers.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white30),
                        itemBuilder: (context, index) {
                          final result = correctAnswers[index];
                          final timeDiff = winner != null ? result.timeTakenMs - winner.timeTakenMs : 0;
                          return ListTile(
                            leading: _buildRankIcon(index + 1),
                            title: Text('${result.nickname} (${result.employeeId})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            trailing: Text(
                              index == 0 ? 'เร็วที่สุด' : '+${(timeDiff / 1000).toStringAsFixed(2)} วิ',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('กำลังรอคำถามถัดไป...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFinishedView(RealtimeQuizSession session) {
    return Container(
       decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4e54c8), Color(0xFF8f94fb)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _sessionRef.collection('players').orderBy('totalScore', descending: true).snapshots(),
          builder: (context, snapshot) {
             if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            final finalRanking = snapshot.data!.docs.map((doc) => RealtimeQuizPlayer.fromFirestore(doc)).toList();

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events, size: 100, color: Colors.amber),
                  const SizedBox(height: 20),
                  Text('การแข่งขันสิ้นสุดแล้ว!', style: GoogleFonts.anuphan(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Divider(height: 40, color: Colors.white54),
                  Text('สรุปอันดับคะแนน', style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                       color: Colors.white.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListView.separated(
                        itemCount: finalRanking.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white30),
                        itemBuilder: (context, index) {
                          final result = finalRanking[index];
                          return ListTile(
                            leading: _buildRankIcon(index + 1),
                            title: Text('${result.nickname} (${result.employeeId})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            trailing: Text('${result.totalScore} คะแนน', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ),
                  ),
                   const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('กลับไปหน้ารายการ'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRankIcon(int rank) {
    if (rank == 1) return Icon(Icons.emoji_events, color: Colors.amber.shade300);
    if (rank == 2) return Icon(Icons.emoji_events, color: Colors.grey.shade300);
    if (rank == 3) return Icon(Icons.emoji_events, color: Colors.brown.shade400);
    return CircleAvatar(radius: 12, backgroundColor: Colors.transparent, child: Text('$rank', style: const TextStyle(color: Colors.white)));
  }
}

class _CountdownTimer extends StatefulWidget {
  final DateTime endTime;
  const _CountdownTimer({super.key, required this.endTime});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Timer _timer;
  int _secondsLeft = 10;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    final difference = widget.endTime.difference(now);
    if (mounted) {
      setState(() {
        _secondsLeft = difference.isNegative ? 0 : difference.inSeconds;
      });
      if (_secondsLeft <= 0) {
        _timer.cancel();
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$_secondsLeft',
      style: GoogleFonts.orbitron(fontSize: 120, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }
}
