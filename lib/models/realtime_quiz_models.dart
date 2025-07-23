// lib/models/realtime_quiz_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the overall state of a live Game Show session.
class RealtimeQuizSession {
  final String id;
  final String hostId;
  final String quizTitle;
  final String status; // 'waiting', 'countdown', 'question_active', 'question_result', 'finished'
  final int currentQuestionIndex;
  final Timestamp? questionStartTime;
  final Timestamp? countdownEndTime;

  RealtimeQuizSession({
    required this.id,
    required this.hostId,
    required this.quizTitle,
    this.status = 'waiting',
    this.currentQuestionIndex = -1,
    this.questionStartTime,
    this.countdownEndTime,
  });

  factory RealtimeQuizSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RealtimeQuizSession(
      id: doc.id,
      hostId: data['hostId'] ?? '',
      quizTitle: data['quizTitle'] ?? '',
      status: data['status'] ?? 'waiting',
      currentQuestionIndex: data['currentQuestionIndex'] ?? -1,
      questionStartTime: data['questionStartTime'] as Timestamp?,
      countdownEndTime: data['countdownEndTime'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hostId': hostId,
      'quizTitle': quizTitle,
      'status': status,
      'currentQuestionIndex': currentQuestionIndex,
      'questionStartTime': questionStartTime,
      'countdownEndTime': countdownEndTime,
    };
  }
}

/// Represents a player in a live Game Show session.
class RealtimeQuizPlayer {
  final String employeeId;
  final String nickname;
  final String? profileImageUrl;
  final int totalScore;

  RealtimeQuizPlayer({
    required this.employeeId,
    required this.nickname,
    this.profileImageUrl,
    this.totalScore = 0,
  });

  factory RealtimeQuizPlayer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RealtimeQuizPlayer(
      employeeId: doc.id,
      nickname: data['nickname'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      totalScore: data['totalScore'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'totalScore': totalScore,
    };
  }
}

/// A helper class to hold processed answer data for the leaderboard.
class QuestionAnswerResult {
  final String nickname;
  final String employeeId; // Added employeeId
  final int timeTakenMs;

  QuestionAnswerResult({
    required this.nickname,
    required this.employeeId, // Added employeeId
    required this.timeTakenMs
  });
}
