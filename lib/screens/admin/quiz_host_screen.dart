// lib/screens/admin/quiz_host_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/quiz_model.dart';
import 'package:hr_online/models/realtime_quiz_models.dart';
import 'package:hr_online/widgets/employee_avatar.dart';

/// Helper class to combine all necessary data for the result leaderboard.
class FullPlayerAnswerInfo {
  final RealtimeQuizPlayer player;
  final bool answeredCorrectly;
  final int timeTakenMs;
  final int scoreThisRound;

  FullPlayerAnswerInfo({
    required this.player,
    required this.answeredCorrectly,
    required this.timeTakenMs,
    required this.scoreThisRound,
  });
}

class QuizHostScreen extends StatefulWidget {
  final Quiz quiz;
  const QuizHostScreen({super.key, required this.quiz});

  @override
  State<QuizHostScreen> createState() => _QuizHostScreenState();
}

class _QuizHostScreenState extends State<QuizHostScreen> {
  Stream<DocumentSnapshot> _sessionStream = const Stream.empty();
  Stream<QuerySnapshot> _playersStream = const Stream.empty();
  late DocumentReference _sessionRef;

  List<Question> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    setState(() => _isLoading = true);
    _sessionRef = FirebaseFirestore.instance
        .collection('realtime_quiz_sessions')
        .doc(widget.quiz.id);
    
    final questionsSnapshot = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quiz.id)
        .collection('questions')
        .get();
    
    if (mounted) {
      _questions = questionsSnapshot.docs.map((doc) => Question.fromFirestore(doc)).toList();
      
      await _sessionRef.set({
        'hostId': 'admin', 
        'quizTitle': widget.quiz.title,
        'status': 'waiting',
        'currentQuestionIndex': -1,
      }, SetOptions(merge: true));

      setState(() {
        _sessionStream = _sessionRef.snapshots();
        _playersStream = _sessionRef.collection('players').orderBy('totalScore', descending: true).snapshots();
        _isLoading = false;
      });
    }
  }

  Future<void> _startGame() async {
    if (_questions.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเริ่มได้: แบบทดสอบนี้ไม่มีคำถาม'), backgroundColor: Colors.red),
      );
      return;
    }
    await _resetSessionScores();
    _showNextQuestion(0);
  }
  
  Future<void> _resetSessionScores() async {
    final playersSnapshot = await _sessionRef.collection('players').get();
    final answersSnapshot = await _sessionRef.collection('answers').get();
    final batch = FirebaseFirestore.instance.batch();

    // Reset scores for all current players
    for (final playerDoc in playersSnapshot.docs) {
      batch.update(playerDoc.reference, {'totalScore': 0});
    }
    // Delete all previous answers
    for (final answerDoc in answersSnapshot.docs) {
      batch.delete(answerDoc.reference);
    }
    await batch.commit();
  }


  Future<void> _showNextQuestion(int questionIndex) async {
    final countdownEndTime = Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 10)));
    await _sessionRef.update({
      'status': 'countdown',
      'currentQuestionIndex': questionIndex,
      'countdownEndTime': countdownEndTime,
    });

    Timer(const Duration(seconds: 10), () {
      if (mounted) {
        _sessionRef.update({
          'status': 'question_active',
          'questionStartTime': FieldValue.serverTimestamp(),
        });
      }
    });
  }
  
  Future<void> _revealAnswer(int questionIndex) async {
    final playersRef = _sessionRef.collection('players');
    final answersRef = _sessionRef.collection('answers');
    
    final answersSnapshot = await answersRef
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: 'q_${questionIndex}_')
        .where(FieldPath.documentId, isLessThan: 'q_${questionIndex}_z')
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in answersSnapshot.docs) {
      final data = doc.data();
      if (data['isCorrect'] == true) {
        final playerId = data['employeeId'];
        final score = data['score'] ?? 0;
        
        batch.update(playersRef.doc(playerId), {
          'totalScore': FieldValue.increment(score),
        });
      }
    }
    
    await batch.commit();
    await _sessionRef.update({'status': 'question_result'});
  }

  Future<void> _endGame() async {
    // --- [START] NEW LOGIC: Accumulate scores to main user profile ---
    final playersSnapshot = await _sessionRef.collection('players').get();
    final batch = FirebaseFirestore.instance.batch();

    for (final playerDoc in playersSnapshot.docs) {
      final playerData = playerDoc.data();
      final score = playerData['totalScore'] ?? 0;
      if (score > 0) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(playerDoc.id);
        batch.update(userRef, {'totalScore': FieldValue.increment(score)});
      }
    }
    await batch.commit();
    // --- [END] NEW LOGIC ---

    await _sessionRef.update({'status': 'finished'});
  }


  Future<void> _kickPlayer(String employeeId, String nickname) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ยืนยันการนำออก'),
        content: Text('คุณต้องการนำ "$nickname" ออกจากการแข่งขันใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('ยืนยัน', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _sessionRef.collection('players').doc(employeeId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Host: ${widget.quiz.title}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: _sessionStream,
              builder: (context, sessionSnapshot) {
                if (!sessionSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final session = RealtimeQuizSession.fromFirestore(sessionSnapshot.data!);
                return _buildControlPanel(session);
              },
            ),
    );
  }

  Widget _buildControlPanel(RealtimeQuizSession session) {
    switch (session.status) {
      case 'waiting':
        return _buildLobbyView();
      case 'countdown':
        return _buildCountdownView(session);
      case 'question_active':
        return _buildQuestionView(session);
      case 'question_result':
        return _buildQuestionResultView(session);
      case 'finished':
        return _buildFinishedView();
      default:
        return const Center(child: Text('สถานะไม่รู้จัก'));
    }
  }

  Widget _buildLobbyView() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('ห้องกำลังรอผู้เล่น', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('เริ่มเกม'),
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
                ),
              ],
            ),
          ),
        ),
        _buildPlayersPanel(isInteractive: true),
      ],
    );
  }

  Widget _buildCountdownView(RealtimeQuizSession session) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('คำถามข้อที่ ${session.currentQuestionIndex + 1} กำลังจะมา...', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          _CountdownTimer(
            endTime: session.countdownEndTime?.toDate() ?? DateTime.now(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionView(RealtimeQuizSession session) {
    if (session.currentQuestionIndex < 0 || session.currentQuestionIndex >= _questions.length) {
      return const Center(child: Text('คำถามไม่ถูกต้อง'));
    }
    final question = _questions[session.currentQuestionIndex];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('คำถามที่ ${session.currentQuestionIndex + 1}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text(question.text, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 40),
          ...question.options.asMap().entries.map((entry) {
            return Card(
              color: Colors.grey.shade100,
              child: ListTile(
                leading: Text('${String.fromCharCode(65 + entry.key)}.'),
                title: Text(entry.value),
              ),
            );
          }),
          const Spacer(),
          ElevatedButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text('แสดงเฉลยและผลคะแนน'),
            onPressed: () => _revealAnswer(session.currentQuestionIndex),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuestionResultView(RealtimeQuizSession session) {
    final bool isLastQuestion = session.currentQuestionIndex == _questions.length - 1;
    final question = _questions[session.currentQuestionIndex];
    final correctOptions = question.correctAnswers.map((ansIndex) {
      final index = int.parse(ansIndex);
      return '${String.fromCharCode(65 + index)}. ${question.options[index]}';
    }).join(', ');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton.icon(
                icon: Icon(isLastQuestion ? Icons.flag : Icons.arrow_forward_ios),
                label: Text(isLastQuestion ? 'จบการแข่งขัน' : 'คำถามถัดไป'),
                onPressed: isLastQuestion ? _endGame : () => _showNextQuestion(session.currentQuestionIndex + 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastQuestion ? Colors.red : Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'สรุปผลคำถามที่ ${session.currentQuestionIndex + 1}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.green.shade50,
                child: ListTile(
                  title: const Text('คำตอบที่ถูกต้องคือ'),
                  subtitle: Text(correctOptions, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          flex: 4,
          child: _QuestionResultLeaderboard(
            sessionRef: _sessionRef,
            questionIndex: session.currentQuestionIndex,
          ),
        ),
        _buildPlayersPanel(),
      ],
    );
  }

  Widget _buildFinishedView() {
     return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('สิ้นสุดการแข่งขัน!', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          const Text('คะแนนได้ถูกรวมเข้ากับตารางคะแนนรวมแล้ว'),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('กลับไปหน้าจัดการ'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersPanel({bool isInteractive = false}) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text('ผู้เข้าร่วมปัจจุบัน', style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _playersStream,
              builder: (context, playersSnapshot) {
                if (!playersSnapshot.hasData) {
                  return const Center(child: Text('กำลังรอผู้เล่น...'));
                }
                final players = playersSnapshot.data!.docs
                    .map((doc) => RealtimeQuizPlayer.fromFirestore(doc))
                    .toList();

                if (players.isEmpty) {
                  return const Center(child: Text('ยังไม่มีผู้เข้าร่วม'));
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    return InkWell(
                      onLongPress: isInteractive ? () => _kickPlayer(player.employeeId, player.nickname) : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            EmployeeAvatar(imageUrl: player.profileImageUrl, gender: null, radius: 24),
                            const SizedBox(height: 4),
                            Text(player.nickname, style: const TextStyle(fontSize: 12)),
                            Text('(${player.employeeId})', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionResultLeaderboard extends StatelessWidget {
  final DocumentReference sessionRef;
  final int questionIndex;

  const _QuestionResultLeaderboard({required this.sessionRef, required this.questionIndex});

  Future<List<FullPlayerAnswerInfo>> _getLeaderboardData() async {
    final playersSnapshot = await sessionRef.collection('players').get();
    final answersSnapshot = await sessionRef
        .collection('answers')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: 'q_${questionIndex}_')
        .where(FieldPath.documentId, isLessThan: 'q_${questionIndex}_z')
        .get();

    final answersMap = {for (var doc in answersSnapshot.docs) doc.id.split('_').last: doc.data()};

    List<FullPlayerAnswerInfo> results = [];
    for (var doc in playersSnapshot.docs) {
      final player = RealtimeQuizPlayer.fromFirestore(doc);
      final answerData = answersMap[player.employeeId];
      
      results.add(FullPlayerAnswerInfo(
        player: player,
        answeredCorrectly: answerData?['isCorrect'] ?? false,
        timeTakenMs: answerData?['timeTakenMs'] ?? 0,
        scoreThisRound: answerData?['score'] ?? 0,
      ));
    }

    results.sort((a, b) => b.player.totalScore.compareTo(a.player.totalScore));
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FullPlayerAnswerInfo>>(
      future: _getLeaderboardData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final leaderboard = snapshot.data!;

        return SingleChildScrollView(
          child: DataTable(
            headingRowColor: MaterialStateColor.resolveWith((states) => Colors.blue.shade50),
            columnSpacing: 16.0,
            columns: const [
              DataColumn(label: Text('อันดับ')),
              DataColumn(label: Text('ชื่อ (รหัส)')),
              DataColumn(label: Text('คะแนนรวม')),
              DataColumn(label: Text('ผลข้อนี้')),
              DataColumn(label: Text('เวลา')),
            ],
            rows: List.generate(leaderboard.length, (index) {
              final data = leaderboard[index];
              final rank = index + 1;
              Color? rowColor;
              if (rank <= 10) rowColor = Colors.green.withOpacity(0.05);
              
              return DataRow(
                color: MaterialStateProperty.all(rowColor),
                cells: [
                  DataCell(_buildRankCell(rank)),
                  DataCell(Text('${data.player.nickname} (${data.player.employeeId})')),
                  DataCell(Text('${data.player.totalScore}')),
                  DataCell(
                    Text(
                      '${data.answeredCorrectly ? "✅" : "❌"} (+${data.scoreThisRound})',
                      style: TextStyle(color: data.answeredCorrectly ? Colors.green : Colors.red),
                    )
                  ),
                   DataCell(
                    data.timeTakenMs > 0
                        ? Text('${(data.timeTakenMs / 1000).toStringAsFixed(2)}s')
                        : const Text('-'),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildRankCell(int rank) {
    Icon? trophyIcon;
    if (rank == 1) trophyIcon = Icon(Icons.emoji_events, color: Colors.amber.shade600);
    if (rank == 2) trophyIcon = Icon(Icons.emoji_events, color: Colors.grey.shade500);
    if (rank == 3) trophyIcon = Icon(Icons.emoji_events, color: Colors.brown.shade400);

    return Row(
      children: [
        if (trophyIcon != null) ...[trophyIcon, const SizedBox(width: 8)],
        Text('$rank'),
      ],
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  final DateTime endTime;
  const _CountdownTimer({required this.endTime});

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
      if (_secondsLeft == 0) {
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
      style: GoogleFonts.orbitron(fontSize: 100, fontWeight: FontWeight.bold),
    );
  }
}
