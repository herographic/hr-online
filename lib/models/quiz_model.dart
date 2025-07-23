// lib/models/quiz_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// --- [START] NEW CODE ---
/// Enum to define the type of quiz.
enum QuizType {
  standard, // Traditional quiz taken individually.
  gameShow, // Real-time competitive quiz.
}

/// Helper to convert string from Firestore to QuizType enum.
QuizType quizTypeFromString(String? typeString) {
  if (typeString == 'gameShow') {
    return QuizType.gameShow;
  }
  return QuizType.standard;
}
// --- [END] NEW CODE ---


enum QuestionType {
  singleChoice,
  multipleChoice,
  textInput;

  static QuestionType fromString(String type) {
    switch (type) {
      case 'multipleChoice':
        return QuestionType.multipleChoice;
      case 'textInput':
        return QuestionType.textInput;
      default:
        return QuestionType.singleChoice;
    }
  }
}

class Question {
  final String id;
  final String text;
  final QuestionType type;
  final List<String> options;
  final List<String> correctAnswers;
  final int points;

  Question({
    required this.id,
    required this.text,
    required this.type,
    this.options = const [],
    required this.correctAnswers,
    required this.points,
  });

  factory Question.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Question(
      id: doc.id,
      text: data['text'] ?? '',
      type: QuestionType.fromString(data['type'] ?? 'singleChoice'),
      options: List<String>.from(data['options'] ?? []),
      correctAnswers: List<String>.from(data['correctAnswers'] ?? []),
      points: data['points'] ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'type': type.name,
      'options': options,
      'correctAnswers': correctAnswers,
      'points': points,
    };
  }
}

class Quiz {
  final String id;
  final String title;
  final String description;
  final String? departmentId;
  final String? positionId;
  final String authorId;
  final Timestamp createdAt;
  final bool isActive;
  final List<Question> questions;
  // --- [START] MODIFIED CODE ---
  final QuizType quizType; // Added quiz type
  // --- [END] MODIFIED CODE ---


  Quiz({
    required this.id,
    required this.title,
    required this.description,
    this.departmentId,
    this.positionId,
    required this.authorId,
    required this.createdAt,
    this.isActive = true,
    this.questions = const [],
    this.quizType = QuizType.standard, // Default to standard
  });

  factory Quiz.fromFirestore(DocumentSnapshot doc, List<Question> questions) {
    final data = doc.data() as Map<String, dynamic>;
    return Quiz(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      departmentId: data['departmentId'],
      positionId: data['positionId'],
      authorId: data['authorId'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      isActive: data['isActive'] ?? true,
      questions: questions,
      // --- [START] MODIFIED CODE ---
      quizType: quizTypeFromString(data['quizType']), // Map from string
      // --- [END] MODIFIED CODE ---
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'departmentId': departmentId,
      'positionId': positionId,
      'authorId': authorId,
      'createdAt': createdAt,
      'isActive': isActive,
      // --- [START] MODIFIED CODE ---
      'quizType': quizType.name, // Save enum name as string
      // --- [END] MODIFIED CODE ---
    };
  }
}

class QuizAssignment {
  final String id;
  final String quizId;
  final String employeeId;
  final String status;
  final int? score;
  final Timestamp? assignedAt;
  final Timestamp? completedAt;
  final int? durationInSeconds; 

  QuizAssignment({
    required this.id,
    required this.quizId,
    required this.employeeId,
    required this.status,
    this.score,
    this.assignedAt,
    this.completedAt,
    this.durationInSeconds,
  });

   factory QuizAssignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuizAssignment(
      id: doc.id,
      quizId: data['quizId'] ?? '',
      employeeId: data['employeeId'] ?? '',
      status: data['status'] ?? 'pending',
      score: data['score'],
      assignedAt: data['assignedAt'],
      completedAt: data['completedAt'],
      durationInSeconds: data['durationInSeconds'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'quizId': quizId,
      'employeeId': employeeId,
      'status': status,
      'score': score,
      'assignedAt': assignedAt ?? FieldValue.serverTimestamp(),
      'completedAt': completedAt,
      'durationInSeconds': durationInSeconds,
    };
  }
}
