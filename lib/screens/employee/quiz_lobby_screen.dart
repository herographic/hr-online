// lib/screens/employee/quiz_lobby_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/realtime_quiz_models.dart';
import 'package:hr_online/screens/employee/quiz_gameplay_screen.dart';
import 'package:hr_online/widgets/employee_avatar.dart';

class QuizLobbyScreen extends StatefulWidget {
  final String quizId;
  final Employee loggedInEmployee;

  const QuizLobbyScreen({
    super.key,
    required this.quizId,
    required this.loggedInEmployee,
  });

  @override
  State<QuizLobbyScreen> createState() => _QuizLobbyScreenState();
}

class _QuizLobbyScreenState extends State<QuizLobbyScreen> {
  late DocumentReference<RealtimeQuizPlayer> _playerRef;
  late DocumentReference<RealtimeQuizSession> _sessionRef;

  @override
  void initState() {
    super.initState();
    _sessionRef = FirebaseFirestore.instance
        .collection('realtime_quiz_sessions')
        .doc(widget.quizId)
        .withConverter<RealtimeQuizSession>(
          fromFirestore: (snapshot, _) => RealtimeQuizSession.fromFirestore(snapshot),
          toFirestore: (session, _) => session.toFirestore(),
        );

    _playerRef = _sessionRef
        .collection('players')
        .doc(widget.loggedInEmployee.employeeId)
        .withConverter<RealtimeQuizPlayer>(
          fromFirestore: (snapshot, _) => RealtimeQuizPlayer.fromFirestore(snapshot),
          toFirestore: (player, _) => player.toFirestore(),
        );
    
    _joinLobby();
  }

  Future<void> _joinLobby() async {
    final player = RealtimeQuizPlayer(
      employeeId: widget.loggedInEmployee.employeeId,
      nickname: widget.loggedInEmployee.nickname,
      profileImageUrl: widget.loggedInEmployee.profileImageUrl,
    );
    await _playerRef.set(player);
  }

  @override
  void dispose() {
    // Optional: Remove player from lobby if they leave before game starts
    // _playerRef.delete(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ห้องรอการแข่งขัน'),
        automaticallyImplyLeading: false, // Prevent back button
      ),
      body: StreamBuilder<DocumentSnapshot<RealtimeQuizSession>>(
        stream: _sessionRef.snapshots(),
        builder: (context, sessionSnapshot) {
          if (sessionSnapshot.hasData && sessionSnapshot.data!.exists) {
            final session = sessionSnapshot.data!.data()!;
            // When admin starts the game, navigate to the gameplay screen
            if (session.status != 'waiting') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (context) => QuizGameplayScreen(
                    quizId: widget.quizId,
                    loggedInEmployee: widget.loggedInEmployee,
                  ),
                ));
              });
            }
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      sessionSnapshot.data?.data()?.quizTitle ?? 'กำลังโหลด...',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text('กำลังรอผู้ดูแลระบบเริ่มการแข่งขัน...'),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('ผู้เข้าร่วมตอนนี้'),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _sessionRef.collection('players').snapshots(),
                  builder: (context, playersSnapshot) {
                    if (!playersSnapshot.hasData) {
                      return const Center(child: Text('กำลังโหลดรายชื่อ...'));
                    }
                    final players = playersSnapshot.data!.docs
                        .map((doc) => RealtimeQuizPlayer.fromFirestore(doc))
                        .toList();
                    
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final player = players[index];
                        return Column(
                          children: [
                            EmployeeAvatar(
                              imageUrl: player.profileImageUrl,
                              gender: null, // Gender is not in RealtimeQuizPlayer model
                              radius: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(player.nickname, overflow: TextOverflow.ellipsis),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
