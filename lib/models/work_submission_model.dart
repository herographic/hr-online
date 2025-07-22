// lib/models/work_submission_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class WorkSubmission {
  final String id;
  final String authorId;
  final String authorFullName;
  final String authorNickname;
  final String? authorImageUrl;
  final String? authorPosition;
  final String? authorDepartment;
  final String? authorDepartmentId; // <-- ADDED: To check department for scoring permission

  final String title;
  final String details;
  final String expectedResult;
  final List<String> imageUrls;
  final List<String> imageFileNames;
  final List<Map<String, String>> taggedEmployees;

  final Timestamp timestamp;

  // --- [START] NEW SCORING FIELDS ---
  /// Stores ratings from users. Key is userId, value is the score (1 for a like, 1-10 for a rating).
  final Map<String, int> ratings;
  /// The sum of all scores in the ratings map.
  final int totalScore;
  // --- [END] NEW SCORING FIELDS ---

  WorkSubmission({
    required this.id,
    required this.authorId,
    required this.authorFullName,
    required this.authorNickname,
    this.authorImageUrl,
    this.authorPosition,
    this.authorDepartment,
    this.authorDepartmentId, // <-- ADDED
    required this.title,
    required this.details,
    required this.expectedResult,
    required this.imageUrls,
    required this.imageFileNames,
    required this.taggedEmployees,
    required this.timestamp,
    required this.ratings,
    required this.totalScore,
  });

  factory WorkSubmission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WorkSubmission(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorFullName: data['authorFullName'] ?? '',
      authorNickname: data['authorNickname'] ?? 'N/A',
      authorImageUrl: data['authorImageUrl'],
      authorPosition: data['authorPosition'],
      authorDepartment: data['authorDepartment'],
      authorDepartmentId: data['authorDepartmentId'], // <-- ADDED
      title: data['title'] ?? '',
      details: data['details'] ?? '',
      expectedResult: data['expectedResult'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      imageFileNames: List<String>.from(data['imageFileNames'] ?? []),
      taggedEmployees: List<Map<String, String>>.from(
          (data['taggedEmployees'] ?? []).map((item) => Map<String, String>.from(item))),
      timestamp: data['timestamp'] ?? Timestamp.now(),
      ratings: Map<String, int>.from(data['ratings'] ?? {}),
      totalScore: data['totalScore'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorFullName': authorFullName,
      'authorNickname': authorNickname,
      'authorImageUrl': authorImageUrl,
      'authorPosition': authorPosition,
      'authorDepartment': authorDepartment,
      'authorDepartmentId': authorDepartmentId, // <-- ADDED
      'title': title,
      'details': details,
      'expectedResult': expectedResult,
      'imageUrls': imageUrls,
      'imageFileNames': imageFileNames,
      'taggedEmployees': taggedEmployees,
      'timestamp': timestamp,
      'ratings': ratings,
      'totalScore': totalScore,
    };
  }
}
